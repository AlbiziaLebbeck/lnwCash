import 'dart:convert';
import 'dart:math';

import 'package:cashu_dart/core/nuts/nut_00.dart';
import 'package:cashu_dart/core/nuts/token/proof.dart';
import 'package:cashu_dart/model/mint_model.dart';
import 'package:lnwcash/utils/cashu.dart';
import 'package:lnwcash/utils/nip01.dart';
import 'package:lnwcash/utils/relay.dart';
import 'package:lnwcash/utils/subscription.dart';
import 'package:nostr_core_dart/nostr.dart';

class Nip60 {
  static final Nip60 shared = Nip60._internal();
  Nip60._internal();

  final List<Map<String,String>> wallets = [];
  Map<String,String> wallet = {};

  final Map<String,dynamic> proofEvents = {};
  final Map<String,List<Proof>> eventProofs = {}; 

  final List<Map<String,String>> histories = [];

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
    wallets.clear();
    Subscription subscription = Subscription(
      filters: [Filter(
        kinds: [37375],
        authors: [Signer.shared.pub!],
      )], 
      onEvent: (events) async {
        await Future.forEach(events.entries, (MapEntry entry) async {
          final event = entry.value;
          if (event['tags'].where((e) => e[0] == 'deleted').toList().isNotEmpty) return;
          if (event['tags'].where((e) => e[0] == 'd').toList().isEmpty) return;

          String walletId = event['tags'].where((e) => e[0] == 'd').toList()[0][1];
          var sameId = wallets.where((w) => w['id'] == walletId).toList();
          if (sameId.isNotEmpty) {
            if(int.parse(sameId[0]['created_at']!) >= event['created_at']) {
              return;
            }
            else {
              wallets.remove(sameId[0]);
            }
          }
          dynamic decryptMsg = {};
          try {
            decryptMsg = jsonDecode((await Signer.shared.nip44Decrypt(event['content']))!);
          } catch (_) {
            return;
          }
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
        });
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


  Future<void> createHistoryEvent(List<String> createdEvt, List<String> destroyedEvt, {String type = "", String detail = ""}) async {
    final content = <List<String>>[];
    int amount = 0;
    for (var evt in createdEvt) {
      content.add(["e", evt, RelayPool.shared.getRelayURL().first, "created"]);
      amount += eventProofs[evt]!.totalAmount;
    }
    for (var evt in destroyedEvt) {
      content.add(["e", evt, RelayPool.shared.getRelayURL().first, "destroyed"]);
      amount -= eventProofs[evt]!.totalAmount;
    }
    if (amount > 0) {
      content.add(["direction", "in"]);
      content.add(["amount", "$amount", "sat"]);
    }
    else {
      content.add(["direction", "out"]);
      content.add(["amount", "${-amount}", "sat"]);
    }

    await deleteTokenEvent(destroyedEvt);

    String? encryptedContent = await Signer.shared.nip44Encrypt(jsonEncode(content));

    List<List<String>> tags = [];
    tags.add(['a', '37375:${Signer.shared.pub}:${wallet['id']}']);

    Event? event = await createEvent(
      kind: 7376, 
      tags: tags, 
      content: encryptedContent!,
    );
    
    RelayPool.shared.send(event!.serialize());
    histories.insert(0, {
      "id": event.id,
      "amount": amount.abs().toString(),
      "direction": amount > 0 ? "in" : "out",
      "time": event.createdAt.toString(),
      "deleted": jsonEncode(destroyedEvt),
      "type": type,
      "detail": detail,
    });
  }

  Future<void> deleteHistEvent(List<String> events) async {
    List<List<String>> tags = [["k","7376"]];
    for (var evt in events) {
      tags.add(["e", evt]);
    }
    Event? event = await createEvent(
      kind: 5, 
      tags: tags, 
      content: "Clear hist",
    ); 
    RelayPool.shared.send(event!.serialize());
  }

  Subscription fetchHistoryEvent(Function updateHistories) {
    Subscription subscription = Subscription( 
      filters: [Filter(
        kinds: [7376],
        authors: [Signer.shared.pub!],
      )], 
      onEvent: (events) async {
        final List<Map<String,String>> newHistories = [];
        await Future.forEach(events.entries, (MapEntry entry) async {
          final event = entry.value;
          if (event['tags'].where((e) => e[0] == 'a').toList().isEmpty) return;
          
          final aTag = event['tags'].where((e) => e[0] == 'a').toList()[0][1];
          if(aTag.split(':').length < 3) return;
          if(aTag.split(':')[2] != Nip60.shared.wallet['id']) return;
          if (histories.where((h) => h['id'] == event['id']).isNotEmpty) return;
          
          dynamic decryptMsg;
          try {
            decryptMsg = jsonDecode((await Signer.shared.nip44Decrypt(event['content']))!);
          } catch (_) {
            return;
          }
          final deletedEvent = decryptMsg.where((c) => c[0] == 'e' && c[3] == 'destroyed')
            .map((c) => c[1]).toList();
          newHistories.add({
            "id": event['id'],
            "amount": decryptMsg.where((c) => c[0] == 'amount').first[1].toString(),
            "direction": decryptMsg.where((c) => c[0] == 'direction').first[1].toString(),
            "time": event['created_at'].toString(),
            "deleted": jsonEncode(deletedEvent),
            "type": "",
            "detail": "",
          });
        });

        histories.addAll(newHistories);
        await updateHistories(newHistories);
      }
    );
    
    RelayPool.shared.subscribe(subscription, timeout: 3);
    return subscription;
  }


  Future<String> createTokenEvent(List<Proof> proofs, String mintUrl) async {
    Map<String,dynamic> content = {
      'mint': mintUrl,
      'proofs': <Map<String,dynamic>>[],
    };

    content['proofs'] = proofs.map((p) => {
      'id': p.id,
      'amount': p.amountNum,
      'secret': p.secret,
      'C': p.C,
    }.cast<String,dynamic>()).toList();

    String? encryptedContent = await Signer.shared.nip44Encrypt(jsonEncode(content));

    List<List<String>> tags = [];
    tags.add(['a', '37375:${Signer.shared.pub}:${wallet['id']}']);

    Event? event = await createEvent(
      kind: 7375, 
      tags: tags, 
      content: encryptedContent!,
    );
    
    proofEvents[event!.id] = jsonDecode(event.serialize())[1];
    eventProofs[event.id] = proofs;
    RelayPool.shared.send(event.serialize());
    return event.id;
  }

  Future<void> deleteTokenEvent(List<String> events) async {
    List<List<String>> tags = [["k","7375"]];
    for (var evt in events) {
      tags.add(["e", evt]);
      proofEvents.remove(evt);
      eventProofs.remove(evt);
    }
    Event? event = await createEvent(
      kind: 5, 
      tags: tags, 
      content: "Spent token!!",
    ); 
    RelayPool.shared.send(event!.serialize());
  }

  Future<(List<String>,List<String>)> rollOverTokenEvent(
    List<Proof> inProofs, 
    List<Proof> outProofs, 
    String mintUrl
  ) async {
    List<String> evtIds = [];
    List<String> rolloverEvent = [];
    List<Proof> unspendProofs = [];
    eventProofs.forEach((evt,prfs) {
      final spendProofs = prfs.where((p) => inProofs.contains(p)).toList();
      if (spendProofs.isNotEmpty) {
        rolloverEvent.add(evt);
        unspendProofs.addAll(prfs.where((p) => !spendProofs.contains(p)));
      }
    });

    // if (unspendProofs.isNotEmpty) evtIds.add(await createTokenEvent(unspendProofs, mintUrl));
    // if (outProofs.isNotEmpty) evtIds.add(await createTokenEvent(outProofs, mintUrl));
    if (unspendProofs.isNotEmpty || outProofs.isNotEmpty) {
      evtIds.add(await createTokenEvent([...unspendProofs, ...outProofs], mintUrl));
    }

    return (evtIds, rolloverEvent);
  }

  Subscription fetchTokenEvent(Function updateProofEvent) {
    Subscription subscription = Subscription( 
      filters: [Filter(
        kinds: [7375],
        authors: [Signer.shared.pub!],
      )], 
      onEvent: (events) async {
        await Future.forEach(events.entries, (MapEntry entry) async {
          final event = entry.value;
          if (event['tags'].where((e) => e[0] == 'a').toList().isEmpty) return;
          if (proofEvents.containsKey(event['id'])) return;
          
          String aTag = event['tags'].where((e) => e[0] == 'a').toList()[0][1];
          if(aTag.split(':').length < 3) return;
          if(aTag.split(':')[2] != Nip60.shared.wallet['id']) return;

          proofEvents[event['id']] = event;
        });
        await updateProofEvent();
      }
    );
    
    RelayPool.shared.subscribe(subscription, timeout: 3);
    return subscription;
  }

  Future<void> eventToProof() async {
    eventProofs.clear();
    for (var mint in Cashu.shared.proofs.keys) {
      Cashu.shared.proofs[mint]!.clear();
    }
    for(var id in proofEvents.keys) {
      final event = proofEvents[id];
      dynamic decryptMsg;
      try {
        decryptMsg = jsonDecode((await Signer.shared.nip44Decrypt(event['content']))!);
      } catch (_) {
        return;
      }
      
      if (Cashu.shared.mints.where((mint) => mint.mintURL == decryptMsg['mint']).isEmpty) {
        bool added = await Cashu.shared.addMint(decryptMsg['mint']);
        if (!added) continue;
      }

      IMint mint = Cashu.shared.getMint(decryptMsg['mint']);
      eventProofs[id] = [];
      for (var proof in decryptMsg['proofs']){
        if (Cashu.shared.proofs[mint]!.where((prf) => prf.secret == proof['secret']).isEmpty) {
          final prf = Proof(
            id: proof['id'], 
            amount: proof['amount'].toString(), 
            secret: proof['secret'], 
            C: proof['C'],
          );
          eventProofs[id]!.add(prf);
          Cashu.shared.proofs[mint]!.add(prf);
        } 
      }
    }
  }
}