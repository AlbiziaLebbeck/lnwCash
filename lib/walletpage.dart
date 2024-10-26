import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconly/iconly.dart';
import 'package:loader_overlay/loader_overlay.dart';

import 'package:cashu_dart/core/nuts/nut_00.dart';
import 'package:cashu_dart/model/invoice.dart';
import 'package:cashu_dart/model/invoice_listener.dart';
import 'package:cashu_dart/model/mint_model.dart';

import 'package:lnwcash/utils/relay.dart';
import 'package:lnwcash/utils/subscription.dart';
import 'package:lnwcash/utils/nip01.dart';
import 'package:lnwcash/utils/nip60.dart';
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

  late final String pub;
  late final String priv;
  late final String login;

  num balance = 0;
  
  // List<Map<String,String>> wallets = [];
  // Map<String,String> wallet = {'balance': '0','mints': '[]'};
  
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Signer.shared.initialize(priv);
      initRelay(); 
    });

    Cashu.shared.addListener(this);
  }

  void initRelay() async {
    List<String> prefsRelays = widget.prefs.getStringList('relays') ?? [];
    for (String url in prefsRelays)
    {
      RelayPool.shared.add(url);
    }
    if (prefsRelays.isEmpty) {
      RelayPool.shared.add('wss://relay.siamstr.com');
      RelayPool.shared.add('wss://relay.notoshi.win');
    }
    if (prefsRelays.isEmpty) {
      await relayManager(context);
    }

    widget.prefs.setStringList('relays', RelayPool.shared.getRelayURL());

    await _fetchWalletEvent();
    await _mintSetup();
    await _fetchProofEvent();
    
    widget.prefs.setString('wallet', jsonEncode(Nip60.shared.wallet));
    Nip60.shared.updateWallet();
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
              ProfileCard(pub),
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
                  child: Text('$balance sats', 
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Mints", style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),),
                    IconButton(
                      onPressed: () async {
                        await mintManager(context);
                        setState(() {});
                        Nip60.shared.wallet['mints'] =  jsonEncode(Cashu.shared.mints.map((m) => m.mintURL).toList());
                        widget.prefs.setString('wallet', jsonEncode(Nip60.shared.wallet));
                        Nip60.shared.updateWallet();
                        setState(() {});
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
              getMintCards(context),
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
    
    widget.prefs.setString('proofs', Cashu.shared.proofSerializer());
    setState(() {
      balance = 0;
      for (IMint mint in Cashu.shared.mints) {
        balance += Cashu.shared.proofs[mint]!.totalAmount;
      }
    });

    Nip60.shared.wallet['balance'] = balance.toString();
    widget.prefs.setString('wallet', jsonEncode(Nip60.shared.wallet));
    Nip60.shared.updateWallet();
  
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
  }

  @override
  void handleBalanceChanged(IMint mint) {
    widget.prefs.setString('proofs', Cashu.shared.proofSerializer());
    
    num oldBalance = balance;

    setState(() {
      balance = 0;
      for (IMint mint in Cashu.shared.mints) {
        balance += Cashu.shared.proofs[mint]!.totalAmount;
      }
    });

    Nip60.shared.wallet['balance'] = balance.toString();
    widget.prefs.setString('wallet', jsonEncode(Nip60.shared.wallet));
    Nip60.shared.updateWallet();

    String snackText = balance > oldBalance ? 
      "Receive ${balance - oldBalance} sat via ecash" :
      "Send ${oldBalance - balance} sat via ecash";  

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: balance > oldBalance ?Colors.green : Colors.red,
        content: Text(snackText, 
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

  Future<void> _fetchWalletEvent() async {
    String walletStr = widget.prefs.getString('wallet') ?? '';
    if (walletStr != '') {
      setState(() {
        Nip60.shared.wallet = Map.castFrom(jsonDecode(walletStr));
      });
    }

    Subscription subscription = Nip60.shared.fetchWalletEvent();
    context.loaderOverlay.show();
    await subscription.timeout.future;
    RelayPool.shared.unsubscribe(subscription.id);
    if (mounted) context.loaderOverlay.hide();
    
    if (Nip60.shared.wallet.isEmpty) {
      if (mounted) await walletManager(context);
    }
    
    setState(() {
      balance = num.parse(Nip60.shared.wallet['balance']!);
    });
  }

  Future<void> _mintSetup() async {
    final dynamic mints = jsonDecode(Nip60.shared.wallet['mints']!);
    if (mints.isEmpty) {
      await Cashu.shared.addMint('https://mint.lnw.cash');
      // ignore: use_build_context_synchronously
      await mintManager(context);
    } else {
      await Cashu.shared.setupMints(mints);
    }

    Nip60.shared.wallet['mints'] =  jsonEncode(Cashu.shared.mints.map((m) => m.mintURL).toList());
  }

  Future<void> _fetchProofEvent() async { 
    String proofsStr = widget.prefs.getString('proofs') ?? '';
    if (proofsStr != '') {
      await Cashu.shared.proofDeserializer(proofsStr);
    }

    Subscription subscription = Nip60.shared.fetchProofEvent();
    if (mounted) context.loaderOverlay.show();
    await subscription.timeout.future;
    RelayPool.shared.unsubscribe(subscription.id);
    if (mounted) context.loaderOverlay.hide();
    widget.prefs.setString('proofs', Cashu.shared.proofSerializer());
    setState(() {
      balance = 0;
      for (IMint mint in Cashu.shared.mints) {
        balance += Cashu.shared.proofs[mint]!.totalAmount;
      }
      Nip60.shared.wallet['balance'] = balance.toString();
    });
  }

  _onReceive () async {
    var action = await receiveButtomSheet(context);
          
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
  }

  _onSend () async {
    var action = await sendButtomSheet(context);
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
}