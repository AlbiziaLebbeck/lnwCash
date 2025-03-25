import 'dart:async';
import 'dart:convert';

import 'package:bech32/bech32.dart';
import 'package:cashu_dart/utils/network/http_client.dart';
import 'package:encrypt_shared_preferences/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconly/iconly.dart';
import 'package:loader_overlay/loader_overlay.dart';

// ignore: implementation_imports
import 'package:bolt11_decoder/src/word_reader.dart';

import 'package:cashu_dart/core/nuts/nut_00.dart';
import 'package:cashu_dart/model/invoice.dart';
import 'package:cashu_dart/model/invoice_listener.dart';
import 'package:cashu_dart/model/mint_model.dart';

import 'package:lnwcash/pages/qrscanpage.dart';

import 'package:lnwcash/utils/relay.dart';
import 'package:lnwcash/utils/subscription.dart';
import 'package:lnwcash/utils/nip01.dart';
import 'package:lnwcash/utils/nip60.dart';
import 'package:lnwcash/utils/cashu.dart';

import 'package:lnwcash/widgets/profilecard.dart';
import 'package:lnwcash/widgets/transactionview.dart';
import 'package:lnwcash/widgets/receivebottom.dart';
import 'package:lnwcash/widgets/sendbottom.dart';
import 'package:lnwcash/widgets/sidebar.dart';

import 'package:lnwcash/widgets/walletmanager.dart';


class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.prefs});

  final EncryptedSharedPreferences prefs;

  @override
  State<StatefulWidget> createState() => _WalletPage();
}

class _WalletPage extends State<WalletPage> with CashuListener {

  String version = '0.1.3';

  late final String pub;
  late final String priv;
  late final String name;

  Completer popUp = Completer();

  num balance = 0;

  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();

    pub = widget.prefs.getString('pub') ?? '';
    priv = widget.prefs.getString('priv') ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Signer.shared.initialize(priv);
      
      List<String> initRelays = widget.prefs.getStringList('relays') ?? [
        'wss://relay.siamstr.com',
        'wss://relay.notoshi.win',
        'wss://relay.damus.io',
        'wss://nos.lol'
      ];
      if (mounted) context.loaderOverlay.show();
      await RelayPool.shared.init(initRelays);
      if (mounted) context.loaderOverlay.hide();

      widget.prefs.setStringList('relays', RelayPool.shared.getRelayURL());

      await _fetchWalletEvent();
      Cashu.shared.initialize(widget.prefs);
    });

    Cashu.shared.addListener(this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: <Widget>[
        SafeArea(child:
          Container(
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
            child: 
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: Column(
                children: [
                  const SizedBox(height: 5,),
                  ProfileCard(prefs: widget.prefs,),
                  SizedBox(height: MediaQuery.of(context).size.height/4,),
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
                      child: Text('$balance sat', 
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
                      FadeInLeft(
                        child:_sendreceive(context, 
                          title: 'Receive', 
                          icon: Icon(IconlyLight.arrow_down, size: 30, color: Theme.of(context).colorScheme.secondary,),
                          onPreesed: _onReceive,
                        )
                      ),
                      const SizedBox(width:16,),
                      FadeInRight(
                        child:_sendreceive(context, 
                          title: 'Send', 
                          icon: Icon(IconlyLight.arrow_up, size: 30, color: Theme.of(context).colorScheme.secondary,),
                          onPreesed: _onSend,
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 25,),
                  // getMintCards(context),
                ],
              ),
            ),
          ),
        ),
        SafeArea(child:
          Column(
            children: [
              const SizedBox(height: 25,),
              Text("Transaction History", style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),),
              const SizedBox(height: 25,),
              getTransactionHistory(context),
            ]
          )
        ),
      ][_currentPageIndex],
      drawer: getDrawer(context, 
        prefs:  widget.prefs,
        fetchWallet: _fetchWalletEvent,
        loadProofs: _loadProofs,
        version: version,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Theme.of(context).colorScheme.primary, spreadRadius: 0, blurRadius: 8),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentPageIndex,
          onTap: (int index) {
            setState(() {
              _currentPageIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(
                Icons.wallet,
                size: 25,
              ),
              label: 'Wallet',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.format_list_bulleted,
                size: 25,
              ),
              label: 'History',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const BarcodeScannerSimple(),
            ),
          ).then((captureText) async {
            if (captureText == null) return;

            String lnurl = '';
            final token = Nut0.decodedToken(captureText);// TokenHelper.getDecodedToken(value);
            if (token != null) {
              Cashu.shared.redeemEcash(token: token);
              // ignore: use_build_context_synchronously
              context.loaderOverlay.show();
              return;
            }

            if (captureText.startsWith('lightning:')) {
              captureText = captureText.substring('lightning:'.length);
            }

            if (Cashu.shared.payingLightningInvoice(captureText) == null) {
              lnurl = captureText;
            }

            if (captureText.toLowerCase().startsWith('lnurl') && lnurl == '') {
              final bech32 = const Bech32Codec().decode(
                captureText,
                2000,
              );
              var data = WordReader(bech32.data);
              final url = utf8.decode(data.read(data.words.length*5)); 
              final response = await HTTPClient.get(
                url.substring(0, url.length - 1),
                modelBuilder: (json) {
                  if (json is !Map) return null; 
                  return json;
                },
              );
              if (response.isSuccess) {
                // ignore: use_build_context_synchronously
                lnurl = await showDialog(context: context,
                  builder: (context) => PayLNAddressDialog(captureText, response.data),
                );

                if (lnurl != '') {
                  Cashu.shared.payingLightningInvoice(lnurl);
                }
              }
            }

            if (lnurl != '') { 
              final quotes = await Cashu.shared.getLastestQuote();
              // ignore: use_build_context_synchronously
              showDialog(context: context,
                builder: (context) => PayQuoteDialog(quotes),
              ).then((value) {
                if (value == "paying") {
                  // ignore: use_build_context_synchronously
                  context.loaderOverlay.show();
                }
              });
            }
          });
        },
        child: const Icon(Icons.qr_code_scanner, size: 42,),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  @override
  void handleInvoicePaid(Receipt receipt) {
    setState(() {
      balance = 0;
      for (IMint mint in Cashu.shared.mints) {
        balance += Cashu.shared.proofs[mint]!.totalAmount;
      }
    });

    Nip60.shared.wallet['balance'] = balance.toString();
    Nip60.shared.updateWallet();

    widget.prefs.setString('wallet', jsonEncode(Nip60.shared.wallet));
    widget.prefs.setString('proofs', jsonEncode(Nip60.shared.proofEvents));
    widget.prefs.setString('history', jsonEncode(Nip60.shared.histories));

    _callTransactionSnackBar(context, "lightning", int.parse(receipt.amount));
  }

  @override
  void handlePaymentCompleted(String paymentKey) async {
    context.loaderOverlay.hide();
    setState(() {
      balance = 0;
      for (IMint mint in Cashu.shared.mints) {
        balance += Cashu.shared.proofs[mint]!.totalAmount;
      }
    });

    Nip60.shared.wallet['balance'] = balance.toString();
    Nip60.shared.updateWallet();

    widget.prefs.setString('wallet', jsonEncode(Nip60.shared.wallet));
    widget.prefs.setString('proofs', jsonEncode(Nip60.shared.proofEvents));
    widget.prefs.setString('history', jsonEncode(Nip60.shared.histories));

    _callTransactionSnackBar(context, "lightning", -int.parse(paymentKey));
  }

  @override
  void handleBalanceChanged(IMint mint) async {
    context.loaderOverlay.hide();
    num oldBalance = balance;

    setState(() {
      balance = 0;
      for (IMint mint in Cashu.shared.mints) {
        balance += Cashu.shared.proofs[mint]!.totalAmount;
      }
    });

    Nip60.shared.wallet['balance'] = balance.toString();
    Nip60.shared.updateWallet();

    widget.prefs.setString('wallet', jsonEncode(Nip60.shared.wallet));
    widget.prefs.setString('proofs', jsonEncode(Nip60.shared.proofEvents));
    widget.prefs.setString('history', jsonEncode(Nip60.shared.histories));

    await popUp.future;
    if (mounted) _callTransactionSnackBar(context, "ecash", (balance - oldBalance).toInt());
  }

  @override
  void handleError(String errorMsg) {
    context.loaderOverlay.hide();
    _callSnackBar(context, errorMsg, error: true);
  }


  Future<void> _fetchWalletEvent({bool isInit = true}) async {
    Nip60.shared.wallet.clear();

    String walletStr = widget.prefs.getString('wallet') ?? '';
    if (isInit && walletStr != '') {
      Nip60.shared.wallet = Map.castFrom(jsonDecode(walletStr));
    } else {
      Subscription subscription = Nip60.shared.fetchWalletEvent();
      
      context.loaderOverlay.show();
      await subscription.finish.future;
      if (mounted) context.loaderOverlay.hide();
      RelayPool.shared.unsubscribe(subscription.id);
      
      while (Nip60.shared.wallet.isEmpty || !isInit) {
        if (mounted) await walletManager(context);
        widget.prefs.setString('wallet', jsonEncode(Nip60.shared.wallet));
        isInit = true;
      }
    }

    setState(() {
      balance = num.parse(Nip60.shared.wallet['balance']!);
    });

    _mintSetup(isInit: isInit);
  }

  Future<void> _mintSetup({bool isInit = true}) async {
    Cashu.shared.mints.clear();
    Cashu.shared.proofs.clear();
    Cashu.shared.keysets.clear();
    final dynamic mints = Nip60.shared.wallet.isEmpty ? [] : jsonDecode(Nip60.shared.wallet['mints']!);
    if (mints.isEmpty) {
      await Cashu.shared.addMint('https://mint.lnw.cash');
    } else {
      context.loaderOverlay.show();
      await Cashu.shared.setupMints(mints);
      if (mounted) context.loaderOverlay.hide();
    }
    Nip60.shared.wallet['mints'] =  jsonEncode(Cashu.shared.mints.map((m) => m.mintURL).toList());
    Nip60.shared.updateWallet();
    widget.prefs.setString('wallet', jsonEncode(Nip60.shared.wallet));
    _loadProofs(isInit: isInit);
  }

  Future<void> _loadProofs({bool isInit = true}) async {
    if (!isInit) {
      widget.prefs.setString('history', '');
      widget.prefs.setString('proofs', '');
    }

    Nip60.shared.histories.clear();
    String history = widget.prefs.getString('history') ?? '';
    if (history != '') {
      // Get history event from local storage
      for (var hist in jsonDecode(history)) {
        // Nip60.shared.deleteHistEvent([hist['id']]);
        if (Nip60.shared.histories.where((e) => e['id'] == hist['id']).isEmpty) {
          Nip60.shared.histories.add(Map.castFrom(hist));
        }
      }
    }

    Nip60.shared.proofEvents.clear();    
    String proofEvts = widget.prefs.getString('proofs') ?? '';
    if (proofEvts != '') {
      // Get proof event from local storage
      for (var id in jsonDecode(proofEvts).keys) {
        final evt = jsonDecode(proofEvts)[id];
        Nip60.shared.proofEvents[id] = evt;
      }
    }

    //update all proof events to local storage
    widget.prefs.setString('proofs', jsonEncode(Nip60.shared.proofEvents));

    await Nip60.shared.eventToProof();

    setState(() {
      balance = 0;
      for (IMint mint in Cashu.shared.mints) {
        mint.balance = Cashu.shared.proofs[mint]!.totalAmount;
        balance += mint.balance; 
      }
      Nip60.shared.wallet['balance'] = balance.toString();
    });

    _fetchProofs();
  }

  Future<void> _fetchProofs() async {
    if (Nip60.shared.histories.isEmpty || Nip60.shared.proofEvents.isEmpty) {
      context.loaderOverlay.show();
    }

    // Get history event from relays
    Subscription histSubscription = Nip60.shared.fetchHistoryEvent((newHist) async {
      // update local histories
      Nip60.shared.histories.sort((t1,t2) => t2['time']!.compareTo(t1['time']!));
      widget.prefs.setString('history', jsonEncode(Nip60.shared.histories));
      
      // Check deleted proofs from history
      for (final hist in newHist) {
        for (final evtId in jsonDecode(hist['deleted']!)) {
          if (Nip60.shared.proofEvents.containsKey(evtId)) {
            await Nip60.shared.deleteTokenEvent([evtId]);
          }
        }
      }
    });
    await histSubscription.finish.future;
    RelayPool.shared.unsubscribe(histSubscription.id);
    
    // Get proof event from relays
    Subscription tokenSubscription = Nip60.shared.fetchTokenEvent(() async {
      // Check deleted proofs from history
      for (final hist in Nip60.shared.histories) {
        for (final evtId in jsonDecode(hist['deleted']!)) {
          if (Nip60.shared.proofEvents.containsKey(evtId)) {
            await Nip60.shared.deleteTokenEvent([evtId]);
          }
        }
      }

      // //update all proof events to local storage
      widget.prefs.setString('proofs', jsonEncode(Nip60.shared.proofEvents));
    }); 
    await tokenSubscription.finish.future;   
    RelayPool.shared.unsubscribe(tokenSubscription.id); 
    
    await Nip60.shared.eventToProof();

    bool balanceChange = false;
    setState(() {
      balance = 0;
      for (IMint mint in Cashu.shared.mints) {
        mint.balance = Cashu.shared.proofs[mint]!.totalAmount;
        balance += mint.balance; 
      }
      if (Nip60.shared.wallet['balance'] != balance.toString()) {
        Nip60.shared.wallet['balance'] = balance.toString();
        balanceChange = true;
      }
    });
    
    if (mounted) context.loaderOverlay.hide();

    if (balanceChange) {
      widget.prefs.setString('wallet', jsonEncode(Nip60.shared.wallet));
      Nip60.shared.updateWallet();
    }
  }

  _onReceive () async {
    popUp = Completer();
    var action = await receiveButtomSheet(context);
          
    if (action == 'lightning') {
      if (mounted) context.loaderOverlay.show();
      Receipt receipt = await Cashu.shared.getLastestInvoice();
      // ignore: use_build_context_synchronously
      context.loaderOverlay.hide();            

      GlobalKey dialogKey = GlobalKey();

      if (mounted) {
        showDialog(context: context,
          builder: (context) => ScaffoldMessenger(
            key: dialogKey,
            child: _qrDialog('Lightning invoice', 'lightning:${receipt.request}'),
          ),
        ).then((value) {popUp.complete();});
      }

      await Cashu.shared.invoicePaid.future;
      if (dialogKey.currentContext != null) {
        Navigator.of(dialogKey.currentContext!).pop();
        return;
      }
    } else if (action == 'cashu') {
      if (mounted) context.loaderOverlay.show();
    }  
    if (!popUp.isCompleted) popUp.complete();
  }

  _onSend () async {
    popUp = Completer();
    var action = await sendButtomSheet(context);
    if (action == 'cashu') {
      String ecash = await Cashu.shared.getLastestEcash();
      if (mounted) context.loaderOverlay.hide();

      // ignore: use_build_context_synchronously
      showDialog(context: context,
        builder: (context) => ScaffoldMessenger(
          child: _qrDialog("Ecash token", ecash), 
        ),
      ).then((value) {popUp.complete();});
    } else if (action == 'lightning') {
      final quotes = await Cashu.shared.getLastestQuote();
      if (mounted) context.loaderOverlay.hide();
      
      // ignore: use_build_context_synchronously
      showDialog(context: context,
        builder: (context) => PayQuoteDialog(quotes),
      ).then((value) {
        popUp.complete();
        if (value == "paying") {
          // ignore: use_build_context_synchronously
          context.loaderOverlay.show();
        }
      });
    } else {
      popUp.complete();
    }
  }

  _sendreceive(BuildContext context, {required String title, required Icon icon, required VoidCallback onPreesed}) {
    return SizedBox(
      width: 100,
      height: 80,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder( borderRadius: BorderRadius.all(Radius.circular(10))),
          padding: const EdgeInsets.all(0),
          side: BorderSide(color: Theme.of(context).colorScheme.secondary),
        ),
        onPressed: onPreesed,
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

  void _callSnackBar(BuildContext context, String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? Colors.red : Theme.of(context).snackBarTheme.backgroundColor,
        content: Text(text, style: TextStyle(color: error ? Colors.white : Theme.of(context).primaryColor)),
        duration: const Duration(seconds: 3),
        width: 200, // Width of the SnackBar.
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      )
    );
  }

  void _callTransactionSnackBar(BuildContext context, String method, int amount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: amount > 0 ? Colors.green : Colors.red,
        content: Text("${amount > 0 ? "Receive" : "Send"} ${amount.abs()} sat via $method", 
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
  }

  Builder _qrDialog(String title, String data) {
    return Builder(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: AlertDialog(
          title: Text(title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary
            ),
          ),
          content: SizedBox(
            width: 320.0,
            height: 350.0,
            child: Column(children: [ 
              QrImageView(
                data: data,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 15,),
              Text('${data.substring(0,21)}...',
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.secondary
                ),
              ),
            ]),
          ),
          actions: [
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: data));
                    // ignore: use_build_context_synchronously
                    _callSnackBar(context, "Copy to clipboard!");
                  }, 
                  child: const Text('Copy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
                ),
                const Expanded(child: SizedBox(height: 10,)),
                TextButton(
                  onPressed: () {Navigator.of(context).pop();}, 
                  child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
                ),
              ]
            ),
          ],
        )
      ),
    );
  }
}