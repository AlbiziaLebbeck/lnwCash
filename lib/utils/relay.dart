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

  List<String> getRelayURL() {
    return _relays.keys.toList();
  }

  Future<bool> add(String url) async {
    if (_relays.containsKey(url)) {
      return true;
    }

    Relay relay = Relay(url);
    relay.onMessage = _onEvent;
    _relays[relay.url] = relay;

    if (await relay.connect()) {
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
  }

  String subscribe(Subscription subscription, {int timeout = 0}) {
    _subscriptions[subscription.id] = subscription;
    send(subscription.request());
    if (timeout > 0) {
      Future.delayed(Duration(seconds: timeout), () {
        // if (!subscription.getEvent)
        // {
        subscription.timeout.complete();
        // unsubscribe(subscription.id);
        // }
      });
    }
    return subscription.id;
  }

  void unsubscribe(String id) {
    final subscription = _subscriptions.remove(id);
    if (subscription != null) {
      send(nostr.Close(subscription.id).serialize());
    }
  }

  bool send(dynamic message){
    bool hadSubmitSend = false;
    
    for (Relay relay in _relays.values) {
      bool result = relay.send(message);
      if (result) {
        hadSubmitSend = true;
      }
    }
    
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
        if (!subscription.eventId.contains(event['id'])){
          subscription.getEvent = true;
          subscription.eventId.add(event['id']);
          subscription.onEvent(event);
        }
      } else if (messageType == 'EOSE') {

      }
    }
  }
}

class Relay{
  Relay(this.url);
  
  final String url;

  WebSocket? webSocket;

  List<dynamic> pendingMessages = [];

  bool isConnecting = false;

  Future<bool> connect() async {
    if (webSocket != null ) {
      return true;
    }

    try {
      webSocket = WebSocket(url);
      isConnecting = true;

      webSocket?.onMessage.listen((event) {
        if (onMessage != null) {
          onMessage!(url,event.data.toString());
        }
      });

      webSocket?.onOpen.listen((event) {
        onConnected();
      });

      return true;
    } catch (e) {
      onError(e.toString(), reconnect: true);
    }

    return false;
  }

  Future<void> disconnect() async {
    webSocket?.close();
    webSocket = null;
  }

  bool send(String message){
    if (webSocket != null){
      if (!isConnecting) {
        try {
          webSocket?.send(message.toJS);
          return true;
        } catch (e) {
          pendingMessages.add(message); 
          onError(e.toString(), reconnect: true);
        }
      } else {
        pendingMessages.add(message);
      }
    }
    return false;
  }
  
  Future onConnected() async {
    isConnecting = false;
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