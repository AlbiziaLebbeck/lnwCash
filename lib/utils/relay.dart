import 'dart:async';
import 'dart:convert';
import 'package:nostr_core_dart/nostr.dart' as nostr;
import 'package:web_socket_client/web_socket_client.dart';
import 'package:lnwcash/utils/subscription.dart';

class RelayPool {
  static final RelayPool shared = RelayPool._internal();
  RelayPool._internal();

  final Map<String, Relay> _relays = {};

  final Map<String, Subscription> _subscriptions = {};

  Completer _initialized = Completer();
  int _numConnectedRelay = 0;

  init(List<String> initRelays) async {
    for(var relayURL in initRelays) {
      add(relayURL);
    }
  }

  List<String> getRelayURL() {
    return _relays.keys.toList();
  }

  bool getRelayConnection(String relayURL) {
    return _relays[relayURL]!.webSocket!.connection.state is Connected || _relays[relayURL]!.webSocket!.connection.state is Reconnected;
  }

  add(String url) async {
    if (_relays.containsKey(url)) {
      return;
    }

    Relay relay = Relay(url);
    _relays[relay.url] = relay;

    relay.connect(onMessage: _onEvent, onConnect: () {
      if (!_initialized.isCompleted) _initialized.complete();
      _numConnectedRelay += 1;
      for (Subscription subscription in _subscriptions.values) {
        relay.send(subscription.request());
      }
    });
  }

  void remove(String url) {
    _relays[url]?.disconnect();
    _relays.remove(url);
    _numConnectedRelay -= 1;
  }

  void close() {
    for (var relayURL in [..._relays.keys]) {
      remove(relayURL);
    }
    _initialized = Completer();
    _subscriptions.clear();
  }

  Future<void> subscribe(Subscription subscription, {int timeout = 0}) async {
    await _initialized.future;
    _subscriptions[subscription.id] = subscription;
    send(subscription.request());
    if (timeout > 0) {
      Future.delayed(Duration(seconds: timeout), () async {
        if (subscription.events.isNotEmpty) {
          await subscription.onEvent(subscription.events);
          subscription.events.clear();
        }
        if (!subscription.finish.isCompleted) subscription.finish.complete();
      });
    }
  }

  void unsubscribe(String id) {
    final subscription = _subscriptions.remove(id);
    if (subscription != null) {
      send(nostr.Close(subscription.id).serialize());
    }
  }

  bool send(dynamic message){
    bool hadSubmitSend = false;
    int relayCheck = 0;
    
    for (Relay relay in _relays.values) {
      bool result = relay.send(message);
      if (result) {
        hadSubmitSend = true;
        relayCheck += 1;
      }
    }
    _numConnectedRelay = relayCheck;
    
    return hadSubmitSend;
  }

  Future<void> _onEvent(String relay, String eventData) async {
    dynamic message = jsonDecode(eventData);
    
    final messageType = message[0];
    final subId = message[1];
    Subscription? subscription = _subscriptions[subId];
    if (subscription != null) {
      if (messageType == 'EVENT')
      {
        final event = message[2];
        if (!subscription.events.containsKey(event['id'])){
          subscription.events[event['id']] = event;
          if (subscription.finish.isCompleted) {
            subscription.onEvent({event['id']: event});
          }
        }
      } else if (messageType == 'EOSE') {
        subscription.countEOSE += 1;
        if (subscription.countEOSE >= _numConnectedRelay && _numConnectedRelay > 0) {
          if (subscription.events.isNotEmpty) {
            await subscription.onEvent(subscription.events);
            subscription.events.clear();
          }
          if (!subscription.finish.isCompleted) subscription.finish.complete();
        }
      }
    }
  }
}

class Relay{
  Relay(this.url);
  
  final String url;

  static var backoff = BinaryExponentialBackoff(
    initial: const Duration(seconds: 1),
    maximumStep: 5
  );
  WebSocket? webSocket;
  bool hasConnected = false;

  void connect({Function? onConnect, Function(String,String)? onMessage}) {
    if (webSocket != null ) {
      return;
    }

    _onConnect = onConnect;
    webSocket = WebSocket(Uri.parse(url), backoff: backoff);

    webSocket?.connection.listen((state) {
      // print('$url is $state');
      if (state is Connected) {
        hasConnected = true;
        // print('Connected from relay: ${url}');
        if (_onConnect != null) _onConnect!();
      }
    });

    _onMessage = onMessage;
    webSocket?.messages.listen((message) async {
      if (_onMessage != null) {
        // print(message);
        _onMessage!(url, message);
      }
    });
    return;
  }

  disconnect() {
    webSocket?.close();
    webSocket = null;
    hasConnected = false;
  }

  bool send(String message){
    if (webSocket?.connection.state is Connected || webSocket?.connection.state is Reconnected) {
      webSocket?.send(message);
      // print('$url send $message');
      return true;
    } else {
      return false;
    }
  }

  Function? _onConnect;
  Function(String,String)? _onMessage;
}