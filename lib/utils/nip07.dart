// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_interop';
import 'dart:js_util';


extension type NostrObj._(JSObject _) implements JSObject {
  external JSPromise getPublicKey();
  external JSPromise signEvent(JSObject event);
  external Nip04Obj nip04;
  external Nip44Obj nip44;
}

extension type Nip04Obj._(JSObject _) implements JSObject {
  external JSPromise encrypt(String pubkey, String plaintext);
  external JSPromise decrypt(String pubkey, String cyphertext);
}

extension type Nip44Obj._(JSObject _) implements JSObject {
  external JSPromise encrypt(String pubkey, String plaintext);
  external JSPromise decrypt(String pubkey, String cyphertext);
}

@JS()
external NostrObj get nostr;

@JS('JSON.parse')
external JSObject jsonParse(String jsStr);

@JS('JSON.stringify')
external String jsonStringfy(JSObject jsObj);

bool nip07Support() {
  if(js.context.hasProperty('nostr')) {
    return true;
  }
  return false;
}

Future<JSObject?> nip07Sign(int created_at, int kind, List<List<String>> tags, String content) {
  String eventStr = '{"created_at":$created_at,"kind":$kind,"tags":${jsonEncode(tags)},"content":"$content"}';
  JSPromise promise = nostr.signEvent(jsonParse(eventStr));
  return promiseToFuture(promise);
}

Future<String?> nip07GetPublicKey() async {
  JSPromise promise = nostr.getPublicKey();
  return promiseToFuture(promise);
}

Future<String?> nip07nip04Encrypt(String pubkey, String plaintext) async {
  JSPromise promise = nostr.nip04.encrypt(pubkey, plaintext);
  return promiseToFuture(promise);
}

Future<String?> nip07nip04Decrypt(String pubkey, String cyphertext) async {
  JSPromise promise = nostr.nip04.decrypt(pubkey, cyphertext);
  return promiseToFuture(promise);
}

Future<String?> nip07nip44Encrypt(String pubkey, String plaintext) async {
  JSPromise promise = nostr.nip44.encrypt(pubkey, plaintext);
  return promiseToFuture(promise);
}

Future<String?> nip07nip44Decrypt(String pubkey, String cyphertext) async {
  JSPromise promise = nostr.nip44.decrypt(pubkey, cyphertext);
  return promiseToFuture(promise);
}