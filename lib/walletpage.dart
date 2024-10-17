import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconly/iconly.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:nostr_core_dart/nostr.dart';

import 'package:cashu_dart/model/invoice.dart';
import 'package:cashu_dart/model/invoice_listener.dart';
import 'package:cashu_dart/model/mint_model.dart';

import 'package:lnwcash/utils/relay.dart';
import 'package:lnwcash/utils/subscription.dart';
import 'package:lnwcash/utils/nip07.dart';
import 'package:lnwcash/utils/cashu.dart';

import 'package:lnwcash/widgets/profilecard.dart';
import 'package:lnwcash/widgets/transactionview.dart';
import 'package:lnwcash/widgets/mintcard.dart';
import 'package:lnwcash/widgets/paymentbottom.dart';
import 'package:lnwcash/widgets/relaymanager.dart';
import 'package:lnwcash/widgets/walletmanager.dart';
import 'package:lnwcash/widgets/mintmanager.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<StatefulWidget> createState() => _WalletPage();
}

class _WalletPage extends State<WalletPage> with CashuListener {

  final RelayPool relayPool = RelayPool();

  late final String pub;
  late final String priv;
  late final String login;
  
  List<Map<String,String>> wallets = [];
  Map<String,String> wallet = {'balance': '0','mints': '[]'};
  
  List<Map<String,dynamic>> proofs = [];

  SnackBar clipboardSnackBar = SnackBar(
    content: const Text('Copy Invoice to Clipboard'),
    duration: const Duration(milliseconds: 3000),
    width: 200, // Width of the SnackBar.
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.0),
    ),
  );

  @override
  void initState() {
    super.initState();

    pub = widget.prefs.getString('pub') ?? '';
    priv = widget.prefs.getString('priv') ?? '';
    login = widget.prefs.getString('loginType') ?? ''; 

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initRelay(); 
    });

    Cashu.shared.addListener(this);
  }

  void initRelay() async {
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
      await relayManager(context, relayPool);
    }

    widget.prefs.setStringList('relays', relayPool.getRelayURL());

    await _fetchWalletEvent();
    print(wallet);
    await _mintSetup();
    await _fetchTokenEvent();
    
    widget.prefs.setString('wallet', jsonEncode(wallet));
    _updateWallet();
    Cashu.shared.initialize();
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
                  FadeInLeft(child:_sendreceive(context, title: 'Receive', icon: Icon(IconlyLight.arrow_down, size: 30, color: Theme.of(context).colorScheme.secondary,))),
                  const SizedBox(width:16,),
                  FadeInRight(child:_sendreceive(context, title: 'Send', icon: Icon(IconlyLight.arrow_up, size: 30, color: Theme.of(context).colorScheme.secondary,))),
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
                      onPressed: () async {
                        final dynamic mints = jsonDecode(wallet['mints']!);
                        await mintManager(context, mints);
                        setState(() {
                          wallet['mints'] = jsonEncode(mints);
                        });
                        widget.prefs.setString('wallet', jsonEncode(wallet));
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

  @override
  void handleInvoicePaid(Receipt receipt) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text("Receive ${receipt.amount} sat via lightning!", 
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 3),
        width: 220, // Width of the SnackBar.
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      )
    );
    widget.prefs.setString('proofs', Cashu.shared.ProofSerializer());
  }

  @override
  void handleBalanceChanged(IMint mint) {
    widget.prefs.setString('proofs', Cashu.shared.ProofSerializer());
  }

  Future<void> _fetchWalletEvent() async {
    String walletStr = widget.prefs.getString('wallet') ?? '';
    if (walletStr != '') {
      setState(() {
        wallet = Map.castFrom(jsonDecode(walletStr));
      });
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
            print(event);
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
            print(decryptMsg);
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
      await Future.delayed(const Duration(seconds: 3));
      relayPool.unsubscribe(subId);
      if (mounted) {
        context.loaderOverlay.hide();
        await walletManager(context, widget.prefs, wallets, relayPool);
        setState(() {
          wallet = wallets.where((e) => e['selected'] == 'true').toList()[0];
        });
      }
    }
  }

  Future<void> _updateWallet() async {
    String content = jsonEncode([
        ["name", wallet['name']],
        ["balance", wallet['balance'], "sat"],
        ["privkey", wallet['privkey']],
        ['unit','sat'],
    ]);

    List<List<String>> tags = [];
    tags.add(['d', wallet['id']!]);
    for(var relay in relayPool.getRelayURL()) {
      tags.add(['relay', relay]);  
    }
    for(var mint in jsonDecode(wallet['mints']!)) {
      tags.add(['mint', mint['url']]);
    }

    Event event;      
    if (widget.prefs.getString('loginType') == 'nsec') {
      String pub = widget.prefs.getString('pub')!;
      String priv = widget.prefs.getString('priv')!;
      String encryptedContent = await Nip4.encryptContent(content, pub, pub, priv);
      event = await Event.from(
        kind: 37375, 
        tags: tags, 
        content: encryptedContent,
        pubkey: pub,
        privkey: priv,
      );
    } else {
      String pub = widget.prefs.getString('pub')!;
      String? encryptedContent = await nip07nip04Encrypt(pub, content);
      JSObject? signEvt = await nip07Sign(
        currentUnixTimestampSeconds(), 
        37375, 
        tags, 
        encryptedContent!,
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

    relayPool.send(event.serialize());
  }

  Future<void> _mintSetup() async {
    final dynamic mints = jsonDecode(wallet['mints']!);
    if (mints.isEmpty) {
      mints.add({'url':'https://mint.lnwasanee.com', 'amount':0});
      await mintManager(context, mints);
      setState(() {
        wallet['mints'] = jsonEncode(mints);
      });
    }
    await Cashu.shared.setupMints(mints);
  }

  Future<void> _fetchTokenEvent() async {
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
    if (mounted) context.loaderOverlay.show();
    await Future.delayed(const Duration(seconds: 3));
    relayPool.unsubscribe(subId);
    if (mounted) context.loaderOverlay.hide();
  }

  _sendreceive(BuildContext context, {required String title, required Icon icon}) {
    return SizedBox(
      width: 100,
      height: 80,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder( borderRadius: BorderRadius.all(Radius.circular(10))),
          padding: const EdgeInsets.all(0),
          side: BorderSide(color: Theme.of(context).colorScheme.secondary),
        ),
        onPressed: () async { 
          var action = await receiveButtomSheet(context, wallet);
          
          if (action == 'lightning') {
            // ignore: use_build_context_synchronously
            context.loaderOverlay.show();
            Receipt receipt = await Cashu.shared.getLastestInvoice();
            // ignore: use_build_context_synchronously
            context.loaderOverlay.hide();

            GlobalKey dialogKey = GlobalKey();
            // ignore: use_build_context_synchronously
            showDialog(context: context,
              builder: (context) => ScaffoldMessenger(
                key: dialogKey,
                child: Builder(
                  builder: (context) => Scaffold(
                    backgroundColor: Colors.transparent,
                    body: AlertDialog(
                      title: const Text('Lightning invoice'),
                      content: SizedBox(
                        width: 300.0,
                        height: 300.0,
                        child: QrImageView(
                          data: 'lightning:${receipt.request}',
                          version: QrVersions.auto,
                          size: 200.0,
                        ),
                      ),
                      actions: [
                        Row(
                          children: [
                            TextButton(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: receipt.request));
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text("Copy to clipboard!"),
                                    duration: const Duration(seconds: 3),
                                    width: 200, // Width of the SnackBar.
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                  )
                                );
                              }, 
                              child: const Text('Copy', style: TextStyle(fontSize: 16))
                            ),
                            const Expanded(child: SizedBox(height: 10,)),
                            TextButton(
                              onPressed: () {Navigator.of(context).pop();}, 
                              child: const Text('Close', style: TextStyle(fontSize: 16))
                            ),
                          ]
                        ),
                      ],
                    )
                  ),
                ),
              ),
            );

            await Cashu.shared.invoicePaid.future;
            if (dialogKey.currentContext != null) {
              Navigator.of(dialogKey.currentContext!).pop();
            }
          }
        },
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