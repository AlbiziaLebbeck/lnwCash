import 'package:flutter/material.dart';
import 'package:lnwcash/utils/nip60.dart';

Future<void> walletManager(context) {
  return showModalBottomSheet(context: context,
    isDismissible: false,
    builder: (context) => const WalletManager(),
  );
}

class WalletManager extends StatefulWidget {
  const WalletManager({super.key});

  @override
  State<WalletManager> createState() => _WalletManager();
}

class _WalletManager extends State<WalletManager>{

  int _selectedWallet = 0;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    String walletName = '';
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
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25)
                    ),
                    labelText: 'Enter wallet name',
                  ),
                  validator: (value) { 
                    if (value!.isNotEmpty) {
                      walletName = value;
                      return null;
                    } else {
                      return "Wallet name is required";
                    }
                  },
                ),
                const SizedBox(height: 10,),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  onPressed: () async {
                    if(_formKey.currentState!.validate()) {
                      await Nip60.shared.createWallet(walletName);
                      setState(() {
                        _selectedWallet = Nip60.shared.wallets.length - 1; 
                      });
                      _formKey.currentState!.reset();
                    }
                  },
                  child: const Text('Create new wallet', style: TextStyle(fontSize: 16)),
                )
              ],
            )
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: MediaQuery.of(context).size.height/2 - 235,
            child: ListView(
              scrollDirection: Axis.vertical,
              children: List.generate(Nip60.shared.wallets.length, 
                (index) => ListTile(
                  title: Row(children: [ 
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Nip60.shared.wallets[index]['name']!, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                        Text('Balance: ${Nip60.shared.wallets[index]['balance']!} sats', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary)),
                      ]
                    ),
                    const Expanded(child: SizedBox()),
                    IconButton(
                      onPressed: () async {
                        if (Nip60.shared.wallets.length <= 1) {
                          showDialog(context: context,
                            builder: (context) => const AlertDialog(
                              title: Text('Warning!'),
                              content: Text('You need at least one wallet'),
                            )
                          );
                          return;
                        }

                        showDialog(context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Delete "${Nip60.shared.wallets[index]['name']}"'),
                            content: const Text('Are you sure you want to delete your wallet?'),
                            actions: [
                              TextButton(onPressed: () {Navigator.of(context).pop();}, child: const Text('Cancel')),
                              FilledButton(
                                onPressed: () async {
                                  await Nip60.shared.deleteWallet(index);
                                  if (_selectedWallet == index) {
                                    _selectedWallet = 0; 
                                  }
                                  setState(() {});
                                  // ignore: use_build_context_synchronously
                                  Navigator.of(context).pop();
                                }, 
                                child: const Text('Delete')
                              ),
                            ],
                          )
                        );
                      }, 
                      icon: Icon(Icons.remove_circle, size: 24, color: Theme.of(context).colorScheme.error,),
                    )
                  ]),
                  leading: Radio<int>(
                    value: index,
                    groupValue: _selectedWallet,
                    onChanged: (int? value) {
                      setState(() {
                        _selectedWallet = value ?? 0;
                      });
                    },
                  ),
                ) 
              )
            )
          ),
          const SizedBox(height: 15),
          TextButton(child: const Text("Select", style: TextStyle(fontSize: 16)),
            onPressed: () async {
              if (Nip60.shared.wallets.isEmpty) {
                showDialog(context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Warning!'),
                    content: const Text('You need at least one wallet.'),
                    actions: [
                      TextButton(onPressed: () {Navigator.of(context).pop();}, child: const Text('OK')),
                    ],
                  )
                );
                return;
              }
              Nip60.shared.wallet = Nip60.shared.wallets[_selectedWallet];
              Navigator.of(context).pop();
            }
          ),
        ]
      ),
    );
  }
}
