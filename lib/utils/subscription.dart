import 'dart:async';

import 'package:nostr_core_dart/nostr.dart';

class Subscription {
  Subscription({
    required this.filters,
    required this.onEvent,
  });

  final String id = generate64RandomHexChars();
  final List<Filter> filters;
  final Function onEvent;

  final List<String> eventId = [];
  final Completer timeout = Completer();
  bool getEvent = false;

  String request() {
    Request request = Request(id, filters);
    return request.serialize();
  }
}