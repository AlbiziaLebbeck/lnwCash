import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:nostr_core_dart/nostr.dart' as nostr;
// ignore: depend_on_referenced_packages
import 'package:web/web.dart';
import 'package:lnwcash/utils/subscription.dart';

class RelayPool {
  static final RelayPool shared = RelayPool._internal();
  RelayPool._internal();

  final Map<String, Relay> _relays = {};

  final Map<String, Subscription> _subscriptions = {};

  Completer _initialized = Completer();
  int _numConnectedRelay = 0;

  Future<void> init(List<String> initRelays) async {
    for(var relayURL in initRelays) {
      await RelayPool.shared.add(relayURL);
    }
    _initialized.complete();
  }

  List<String> getRelayURL() {
    return _relays.keys.toList();
  }

  bool getRelayConnection(String relayURL) {
    return _relays[relayURL]!.isConnected;
  }

  Future<bool> add(String url) async {
    if (_relays.containsKey(url)) {
      return true;
    }

    Relay relay = Relay(url);
    relay.onMessage = _onEvent;
    _relays[relay.url] = relay;

    if (await relay.connect()) {
      _numConnectedRelay += 1;
      for (Subscription subscription in _subscriptions.values) {
        relay.send(subscription.request());
      }
      return true;
    }
    return false;
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
      Future.delayed(Duration(seconds: timeout), () {
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
      if (!relay.isConnected) continue;
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
    print(message);
    
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
          if (subscription.events.isNotEmpty) await subscription.onEvent(subscription.events);
          if (!subscription.finish.isCompleted) subscription.finish.complete();
        }
      }
    }
  }
}

class Relay{
  Relay(this.url);
  
  final String url;

  WebSocket? webSocket;
  bool isConnected = false;

  List<dynamic> pendingMessages = [];

  Completer _connecting = Completer();

  Future<bool> connect() async {
    if (webSocket != null ) {
      return true;
    }

    _connecting = Completer();

    webSocket = WebSocket(url);
    webSocket?.onMessage.listen((event) {
      if (onMessage != null) {
        onMessage!(url,event.data.toString());
      }
    });

    webSocket?.onOpen.listen((event) {
      onConnected();
    });

    webSocket?.onError.listen((event) {
      onError(event.toString(), reconnect: true);
      _connecting.complete();
    });

    await _connecting.future;
    return webSocket != null ? true : false;
  }

  disconnect() {
    webSocket?.close();
    webSocket = null;
    isConnected = false;
  }

  bool send(String message){
    if (webSocket != null){
      if (_connecting.isCompleted) {
        try {
          webSocket?.send(message.toJS);
          return true;
        } catch (e) {
          onError(e.toString(), reconnect: true);
          pendingMessages.add(message); 
        }
      }
    }
    return false;
  }
  
  Future onConnected() async {
    _connecting.complete();
    isConnected = true;
    print('Connected from relay: ${url}');
    for (var message in pendingMessages){
      send(message);
    }

    pendingMessages.clear();
  }

  Function(String,String)? onMessage;

  bool _waitingReconnect = false;

  void onError(String errMsg, {bool reconnect = false}) {
    disconnect();
    if (reconnect && !_waitingReconnect) {
      _waitingReconnect = true;
      Future.delayed(const Duration(seconds: 30), () {
        _waitingReconnect = false;
        connect();
      });
    }
  }
}