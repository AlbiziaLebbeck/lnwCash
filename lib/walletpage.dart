import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:lnwcash/utils/relay.dart';
import 'package:lnwcash/utils/subscription.dart';
import 'package:lnwcash/widgets/mintmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconly/iconly.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:nostr_core_dart/nostr.dart';

import 'package:lnwcash/widgets/profilecard.dart';
import 'package:lnwcash/widgets/transactionview.dart';
import 'package:lnwcash/widgets/mintcard.dart';

import 'package:lnwcash/widgets/paymentbottom.dart';

import 'package:lnwcash/widgets/relaymanager.dart';
import 'package:lnwcash/widgets/walletmanager.dart';
// import 'package:lnwcash/widgets/mintmanager.dart';

import 'package:lnwcash/utils/nip07.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<StatefulWidget> createState() => _WalletPage();
}

class _WalletPage extends State<WalletPage> {

  final RelayPool relayPool = RelayPool();

  late final String pub;
  late final String priv;
  late final String login;

  Map<String,String> wallet = {'balance': '0','mints': '[]'};
  
  List<Map<String,String>> wallets = [];

  List<Map<String,dynamic>> proofs = [];

  @override
  void initState() {
    super.initState();

    pub = widget.prefs.getString('pub') ?? '';
    priv = widget.prefs.getString('priv') ?? '';
    login = widget.prefs.getString('loginType') ?? ''; 

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initRelay(); 
    });
  }

  void initRelay() {
    List<String> prefsRelays = widget.prefs.getStringList('relays') ?? [];
    for (String url in prefsRelays)
    {
      relayPool.add(url);
    }
    if (prefsRelays.isEmpty) {
      relayPool.add('wss://relay.siamstr.com');
      relayPool.add('wss://relay.notoshi.win');
    }
    if (prefsRelays.isEmpty) {
      relayManager(context, relayPool, (value) {
        widget.prefs.setStringList('relays', relayPool.getRelayURL());
        _fetchWalletEvent();
      });
    } else {
      _fetchWalletEvent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [.0, 1],
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHighest,
              Theme.of(context).colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5,),
              ProfileCard(relayPool, pub),
              const SizedBox(height: 25,),
              FadeIn(
                child: Center(
                  child: Text('Current Balance', 
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary, 
                      fontSize: 18
                    ),
                  )
                ),
              ),
              FadeIn(
                child: Center(
                  child: Text('${(wallet['balance'] as String)} sats', 
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 45, 
                      fontWeight: FontWeight.bold, 
                      fontFamily: ''
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25,),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeInLeft(child:_sendReceive(context, title: 'Receive', icon: Icon(IconlyLight.arrow_down, size: 30, color: Theme.of(context).colorScheme.secondary,))),
                  const SizedBox(width:16,),
                  FadeInRight(child:_sendReceive(context, title: 'Send', icon: Icon(IconlyLight.arrow_up, size: 30, color: Theme.of(context).colorScheme.secondary,))),
                ],
              ),
              const SizedBox(height: 25,),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Mints", style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),),
                    IconButton(
                      onPressed: () {
                        final dynamic mints = jsonDecode(wallet['mints']!);
                        mintManager(context, mints, (value) {
                          setState(() {
                            wallet['mints'] = jsonEncode(mints);
                            widget.prefs.setString('wallet', jsonEncode(wallet));
                          });
                        });
                      },
                      iconSize: 27,
                      icon: Icon(Icons.add_circle_outline, 
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 15,),
              getMintCards(context, jsonDecode(wallet['mints']!)),
              const SizedBox(height: 25,),
              Container(
                padding: const EdgeInsets.only(left: 15, right: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Transaction History", style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),),
                    TextButton(
                      onPressed: () => {}, 
                      child: const Text("view all"),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 15,),
              getTransactionHistory(context),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Theme.of(context).colorScheme.primary, spreadRadius: 0, blurRadius: 8),
          ],
        ), 
        child: BottomNavigationBar(
          showSelectedLabels: false,
          showUnselectedLabels: false,
          backgroundColor: Theme.of(context).colorScheme.onPrimary,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).colorScheme.secondary,
          currentIndex: 0,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(
                IconlyLight.home,
                size: 25,
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                IconlyLight.chat,
                size: 25,
              ),
              label: '',
            ),
          ]
        ),
      ),
    );
  }

  _fetchWalletEvent() {
    String walletStr = widget.prefs.getString('wallet') ?? '';
    if (walletStr != '') {
      setState(() {
        wallet = Map.castFrom(jsonDecode(walletStr));
      }); 
      _fetchTokenEvent();
    }
    else {
      String subId = generate64RandomHexChars();
      Subscription subscription = Subscription(
        subId, 
        [Filter(
          kinds: [37375],
          authors: [pub],
        )], 
        (event) async {
          if (!nip07Support() && login == 'nip07'){
            return;
          }

          if (event != null) {
            if (event['tags'].where((e) => e[0] == 'deleted').toList().length > 0) {
              return;
            }
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

            dynamic decryptMsg = jsonDecode(login == 'nsec' ?
              (await Nip4.decryptContent(event['content'], pub, pub, priv)):
              (await nip07nip04Decrypt(pub, event['content']))!
            );
            String name = decryptMsg.where((e) => e[0] == 'name').toList()[0][1].toString();
            String privWal = decryptMsg.where((e) => e[0] == 'privkey').toList()[0][1].toString();
            wallets.add({
              'id': walletId,
              'created_at': event['created_at'].toString(),
              'name': name, 
              'balance': decryptMsg.where((e) => e[0] == 'balance').toList()[0][1],
              'mints': jsonEncode(event['tags'].where((e) => e[0] == 'mint').map((v) => {'url':v[1],'amount':0}).toList()),
              'privkey': privWal,
              'selected': 'false'
            });
          }
        }
      );
      relayPool.subscribe(subscription);
      context.loaderOverlay.show();
      Future.delayed(const Duration(seconds: 3), () {
        relayPool.unsubscribe(subId);
        if (mounted) {
          context.loaderOverlay.hide();
          walletManager(context, widget.prefs, wallets, relayPool, (value) {
            setState(() {
              wallet = wallets.where((e) => e['selected'] == 'true').toList()[0];
            });
            
            _fetchTokenEvent();
          });
        }
      });
    }
  }

  _fetchTokenEvent() {
    String subId = generate64RandomHexChars(); 
    Subscription subscription = Subscription(
      subId, 
      [Filter(
        kinds: [7375,7376],
        authors: [pub],
      )], 
      (event) async {
        String tokenWalId = event['tags'].where((e) => e[0] == 'a').toList()[0][1].split(':')[2];
        
        if (tokenWalId == wallet['id']) {
          dynamic decryptMsg = jsonDecode(login == 'nsec' ?
            (await Nip4.decode(event['content'], pub, priv))!.content:
            (await nip07nip04Decrypt(pub, event['content']))!
          );

          if (event['kind'] == 7375) {
            String mintURL = event['tags'].where((e) => e[0] == 'mint').toList()[0][1];
            dynamic mintJson = jsonDecode(wallet['mints']!);
            if (!mintJson.contains(mintURL)) {
              mintJson.add(mintURL);
            }
            int mintIdx =  mintJson.indexWhere((m) => m['url'] == mintURL);
            for (var proof in decryptMsg['proofs']) {
              wallet['balance'] = (int.parse(wallet['balance']!) + proof['amount']).toString();
              mintJson[mintIdx]['amount'] += proof['amount'];
              proofs.add(proof);
            }
            setState(() {
              wallet['mints'] = jsonEncode(mintJson);
            });
          }
        }
      }
    );
    wallet['balance'] = '0';
    relayPool.subscribe(subscription);
    context.loaderOverlay.show();
    Future.delayed(const Duration(seconds: 3), () {
      relayPool.unsubscribe(subId);
      context.loaderOverlay.hide();
      final dynamic mints = jsonDecode(wallet['mints']!);
      if (mints.isEmpty) {
        mints.add({'url':'https://mint.lnwasanee.com', 'amount':0});
        if (mounted) {
          mintManager(context, mints, (value) {
            setState(() {
              wallet['mints'] = jsonEncode(mints);
              widget.prefs.setString('wallet', jsonEncode(wallet));
            });
          });
        }
      }
      else {
        widget.prefs.setString('wallet', jsonEncode(wallet));
      }
    });
  }

  _sendReceive(BuildContext context, {required Icon icon, required String title}) {
    return SizedBox(
      width: 100,
      height: 80,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder( borderRadius: BorderRadius.all(Radius.circular(10))),
          padding: const EdgeInsets.all(0),
          side: BorderSide(color: Theme.of(context).colorScheme.secondary),
        ),
        onPressed: () { paymentButtomSheet(context);},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            Text(title, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.secondary),),
          ],
        )
      ),       
    );
  }
}