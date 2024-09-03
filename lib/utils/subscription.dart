import 'package:nostr_core_dart/nostr.dart';

class Subscription {
  Subscription(this.id, this.filters, this.onEvent);

  final String id;
  final List<Filter> filters;
  final Function onEvent;

  final List<String> eventId = [];
  bool getEvent = false;

  String request() {
    Request request = Request(id, filters);
    return request.serialize();
  }
}