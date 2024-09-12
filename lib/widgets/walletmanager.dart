import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lnwcash/utils/relay.dart';
import 'package:lnwcash/utils/nip07.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> walletManager(context, prefs, wallets, relaypools) {
  return showModalBottomSheet(context: context, 
    builder: (context) => WalletManager(wallets, prefs, relaypools),
  );
}

class WalletManager extends StatefulWidget {
  const WalletManager(this.wallets, this.prefs, this.relayPool, {super.key});

  final SharedPreferences prefs;
  final List<Map<String,String>> wallets;
  final RelayPool relayPool;

  @override
  State<WalletManager> createState() => _WalletManager();
}

class _WalletManager extends State<WalletManager>{

  late List<Map<String,String>> wallets;
  int _selectedWallet = 0;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    wallets = widget.wallets;
    if (wallets.isNotEmpty) {
      wallets[0]['selected'] = 'true';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (wallets.isEmpty) {
        await createWalletDialog(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Column(
        children: [
          Text('Select Wallet', 
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 24, 
              fontWeight: FontWeight.bold, 
              fontFamily: ''
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: MediaQuery.of(context).size.height/2 -100,
            child: ListView(
              scrollDirection: Axis.vertical,
              children: List.generate(wallets.length, 
                (index) => ListTile(
                  title: Row(children: [ 
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(wallets[index]['name']!, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                        Text('Balance: ${wallets[index]['balance']!} sats', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary)),
                      ]
                    ),
                    const Expanded(child: SizedBox()),
                    IconButton(
                      onPressed: () async {
                        if (wallets.length > 1) {
                          showDialog(context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Delete "${wallets[index]['name']}"'),
                              content: const Text('Are you sure you want to delete your wallet?'),
                              actions: [
                                TextButton(onPressed: () {Navigator.of(context).pop();}, child: const Text('Cancel')),
                                FilledButton(
                                  onPressed: () {
                                    _deleteWallet(index);
                                    Navigator.of(context).pop();
                                  }, 
                                  child: const Text('Delete')
                                ),
                              ],
                            )
                          );
                          //_deleteWallet(index);
                        }
                        else {
                          showDialog(context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Warning!'),
                              content: const Text('You need at least one wallet.'),
                              actions: [
                                TextButton(onPressed: () {Navigator.of(context).pop();}, child: const Text('OK')),
                              ],
                            )
                          );
                        }
                      }, 
                      icon: Icon(Icons.delete_forever, size: 32, color: Theme.of(context).colorScheme.error,),
                    )
                  ]),
                  leading: Radio<int>(
                    value: index,
                    groupValue: _selectedWallet,
                    onChanged: (int? value) {
                      setState(() {
                        wallets[_selectedWallet]['selected'] = 'false';
                        _selectedWallet = value ?? 0;
                        wallets[_selectedWallet]['selected'] = 'true';
                      });
                    },
                  ),
                ),
              )
            )
          ),
          const SizedBox(height: 15),
          TextButton(child: const Text("Create New Wallet", style: TextStyle(fontSize: 16)),
            onPressed: () async {
              await createWalletDialog(context);
            }
          ),
        ]
      ),
    );
  }

  Future<void> createWalletDialog (BuildContext context) async {
    String walletName = "";
    showDialog(context: context,
      barrierDismissible: wallets.isNotEmpty,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('Create Wallet'),
          content: Form(
            key: _formKey,
            child: TextFormField(
              decoration: const InputDecoration(hintText: "Enter wallet name"),
              validator: (value) {
                if (value!.isNotEmpty) {
                  walletName = value;
                  return null;
                } else {
                  return "Wallet name is required";
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.of(context).pop(walletName);
                }
              }, 
              child: const Text('OK')
            ),
          ],
        );
      })
    ).then((value) async{
      if (value == null ) {
        return;
      }
      _createWallet(value);
    });
  }

  _createWallet(String name) async {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    Random rnd = Random();
    String walletId = String.fromCharCodes(Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    
    List<List<String>> tags = [];
    tags.add(['d', walletId]);
    List<String> relays = widget.prefs.getStringList('relays')!; 
    for (var relay in relays) {
      tags.add(['relay', relay]);  
    }
    String content = jsonEncode([
        ["name", name],
        ["balance", "0", "sat"],
        ["privkey", generate64RandomHexChars()],
        ['unit','sat'],
    ]);

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

    bool succeed = widget.relayPool.send(event.serialize());
    if (succeed) {
      setState(() {
        bool isFirst = wallets.isEmpty;
        wallets.add({
          'id': event.id,
          'created_at': event.createdAt.toString(),
          'name': name,
          'balance': '0',
          'mints': '[]',
          'selected': isFirst.toString(), 
        });
      });
    }
  }

  _deleteWallet(int index) async {
    Event event;
    if (widget.prefs.getString('loginType') == 'nsec') {
      String pub = widget.prefs.getString('pub')!;
      String priv = widget.prefs.getString('priv')!;
      event = await Event.from(
        kind: 37375, 
        tags: [['d', wallets[index]['id']!],['deleted']], 
        content: "",
        pubkey: pub,
        privkey: priv,
      );
    } else {
      JSObject? signEvt = await nip07Sign(
        currentUnixTimestampSeconds(), 
        37375, 
        [['d', wallets[index]['id']!],['deleted']], 
        ''
      );
      dynamic signEvent = jsonDecode(jsonStringfy(signEvt!));
      event = Event(
        signEvent['id'],
        signEvent['pubkey'],
        signEvent['created_at'],
        signEvent['kind'],
        [['d', wallets[index]['id']!],['deleted']],
        signEvent['content'],
        signEvent['sig'],
      );
    }

    bool succeed = widget.relayPool.send(event.serialize());
    if (succeed) {
      setState(() {
        if (wallets[index]['selected'] == 'true'){
          wallets[(index+1) % wallets.length]['selected'] = 'true';
        }
        wallets.remove(wallets[index]);
      });
    }
  }
}
