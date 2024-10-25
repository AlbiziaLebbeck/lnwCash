import 'dart:convert';
import 'dart:math';

import 'package:lnwcash/utils/nip01.dart';
import 'package:lnwcash/utils/relay.dart';
import 'package:lnwcash/utils/subscription.dart';
import 'package:nostr_core_dart/nostr.dart';

class Nip60 {
  static final Nip60 shared = Nip60._internal();
  Nip60._internal();

  List<Map<String,String>> wallets = [];
  Map<String,String> wallet = {};

  createWallet(String name) async {
    String privkey = generate64RandomHexChars();
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    Random rnd = Random();
    String walletId = String.fromCharCodes(Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    List<List<String>> tags = [];
    tags.add(['d', walletId]);
    List<String> relays = RelayPool.shared.getRelayURL(); 
    for (var relay in relays) {
      tags.add(['relay', relay]);  
    }
    String content = jsonEncode([
        ["name", name],
        ["balance", "0", "sat"],
        ["privkey", privkey],
        ['unit','sat'],
    ]);

    String? encryptedContent = await Signer.shared.nip44Encrypt(content);

    Event? event = await createEvent(
      kind: 37375, 
      tags: tags, 
      content: encryptedContent!,
    );     

    bool succeed = RelayPool.shared.send(event!.serialize());
    if (succeed) {
      wallets.add({
        'id': walletId,
        'created_at': event.createdAt.toString(),
        'name': name,
        'balance': '0',
        'mints': '[]',
        'privkey': privkey,
      });
    }
  }

  deleteWallet(int index) async {

    Event? event = await createEvent(
      kind: 37375, 
      tags: [['d', wallets[index]['id']!],['deleted']], 
      content: "",
    );     

    bool succeed = RelayPool.shared.send(event!.serialize());
    if (succeed) {
      // if (wallets[index]['selected'] == 'true'){
      //   wallets[(index+1) % wallets.length]['selected'] = 'true';
      // }
      wallets.remove(wallets[index]);
    }
  }

  Subscription fetchWalletEvent() {
    Subscription subscription = Subscription(
      filters: [Filter(
        kinds: [37375],
        authors: [Signer.shared.pub!],
      )], 
      onEvent: (event) async {
        if (event != null) {
          if (event['tags'].where((e) => e[0] == 'deleted').toList().isNotEmpty) return;
          if (event['tags'].where((e) => e[0] == 'd').toList().isEmpty) return;

          String walletId = event['tags'].where((e) => e[0] == 'd').toList()[0][1];
          var sameId = wallets.where((w) => w['id'] == walletId).toList();
          if (sameId.isNotEmpty) {
            if(int.parse(sameId[0]['created_at']!) > event['created_at']) {
              return;
            }
            else {
              wallets.remove(sameId[0]);
            }
          }

          dynamic decryptMsg = jsonDecode((await Signer.shared.nip44Decrypt(event['content']))!);
          print(decryptMsg);
          String name = event['tags'].where((e) => e[0] == 'name').toList().isNotEmpty ?
            event['tags'].where((e) => e[0] == 'name').toList()[0][1].toString() :
            decryptMsg.where((e) => e[0] == 'name').toList()[0][1].toString();

          String balance = decryptMsg.where((e) => e[0] == 'balance').toList()[0][1];
          String privWal = decryptMsg.where((e) => e[0] == 'privkey').toList().isNotEmpty ?
            decryptMsg.where((e) => e[0] == 'privkey').toList()[0][1].toString() : '';

          wallets.add({
            'id': walletId,
            'created_at': event['created_at'].toString(),
            'name': name, 
            'balance': balance,
            'mints': jsonEncode(event['tags'].where((e) => e[0] == 'mint').map((v) => v[1]).toList()),
            'privkey': privWal,
            'selected': 'false'
          });

          if (wallet.isNotEmpty) {
            if (wallet['id'] == walletId && int.parse(wallet['created_at']!) < event['created_at']){
              wallet = wallets.last;
            }
          }
        }
      }
    );
    RelayPool.shared.subscribe(subscription, timeout: 3);
    return subscription;
  }

  Future<void> updateWallet() async {
    String content = jsonEncode([
        ["name", wallet['name']],
        ["balance", wallet['balance'], "sat"],
        ["privkey", wallet['privkey']],
        ['unit','sat'],
    ]);

    List<List<String>> tags = [];
    tags.add(['d', wallet['id']!]);
    for(var relay in RelayPool.shared.getRelayURL()) {
      tags.add(['relay', relay]);  
    }
    for(var mint in jsonDecode(wallet['mints']!)) {
      tags.add(['mint', mint]);
    }

    String? encryptedContent = await Signer.shared.nip44Encrypt(content);

    Event? event = await createEvent(
      kind: 37375, 
      tags: tags, 
      content: encryptedContent!,
    );      

    RelayPool.shared.send(event!.serialize());
  }

  Future<void> createTokenEvent(Map<String,dynamic> content) async {
    String? encryptedContent = await Signer.shared.nip44Encrypt(jsonEncode(content));

    List<List<String>> tags = [];
    tags.add(['a', '37375:${Signer.shared.pub}:${wallet['id']}']);

    Event? event = await createEvent(
      kind: 7375, 
      tags: tags, 
      content: encryptedContent!,
    );

    RelayPool.shared.send(event!.serialize());
  }
}