import 'dart:convert';
import 'dart:js_interop';
import 'package:lnwcash/utils/nip07.dart';
import 'package:nostr_core_dart/nostr.dart';

class Signer {
  static final Signer shared = Signer._internal();
  Signer._internal();

  String? pub;
  String? priv;
  bool isNip07 = false;

  initialize(String priv) async {
    if (priv.isEmpty) {
      isNip07 = true;
      pub = await nip07GetPublicKey();
    } else {
      this.priv = priv;
      pub = Keychain.getPublicKey(priv);
    }
  }

  Future<String?> nip04Encrypt(String content, {String? peerPub}) {
    peerPub ??= pub!;
    return isNip07 ? 
      nip07nip04Encrypt(peerPub, content): 
      Nip4.encryptContent(content, peerPub, pub!, priv!);
  }

  Future<String?> nip04Decrypt(String content, {String? peerPub}) {
    peerPub ??= pub!;
    return isNip07 ? 
      nip07nip04Decrypt(peerPub, content):
      Nip4.decryptContent(content, peerPub, pub!, priv!); 
  }

  Future<String?> nip44Encrypt(String content, {String? peerPub}) {
    peerPub ??= pub!;
    return isNip07 ? 
      nip07nip44Encrypt(peerPub, content): 
      Nip44.encryptContent(content, peerPub, pub!, priv!);
  }

  Future<String?> nip44Decrypt(String content, {String? peerPub}) {
    peerPub ??= pub!;
    return isNip07 ? 
      nip07nip44Decrypt(peerPub, content):
      Nip44.decryptContent(content, peerPub, pub!, priv!); 
  }
}

Future<Event?> createEvent ({
  required int kind,
  required List<List<String>> tags,
  required String content,
  String? priv, 
  String? pub,
}) async {
  Event event;
  if (!Signer.shared.isNip07) {
    event = await Event.from(
      kind: kind, 
      tags: tags, 
      content: content,
      pubkey: pub ?? Signer.shared.pub!,
      privkey: priv ?? Signer.shared.priv!,
    );
  } else {
    if (!nip07Support()) return null;
    
    JSObject? signEvt = await nip07Sign(
      currentUnixTimestampSeconds(), 
      kind, 
      tags, 
      content,
    );
    dynamic signEvent = jsonDecode(jsonStringfy(signEvt!));
    event = Event(
      signEvent['id'],
      signEvent['pubkey'],
      signEvent['created_at'],
      signEvent['kind'],
      tags,
      signEvent['content'],
      signEvent['sig'],
    );
  }

  return event;
}