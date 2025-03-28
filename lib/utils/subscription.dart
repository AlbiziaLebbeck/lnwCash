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

  final Map<String,Object> events = {};
  final Completer finish = Completer();
  int countEOSE = 0;

  String request() {
    Request request = Request(id, filters);
    return request.serialize();
  }
}