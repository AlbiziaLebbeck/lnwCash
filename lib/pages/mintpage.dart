import 'dart:math';

import 'package:animate_do/animate_do.dart';
import 'package:cashu_dart/core/nuts/nut_00.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:lnwcash/utils/cashu.dart';
import 'package:lnwcash/utils/relay.dart';
import 'package:lnwcash/utils/subscription.dart';
import 'package:nostr_core_dart/nostr.dart';

class MintPage extends StatefulWidget {
  const MintPage({super.key});

  @override
  State<MintPage> createState() => _MintPage();
}

class _MintPage extends State<MintPage> {
  final _formKey = GlobalKey<FormState>();

  final Map<String,int> recommendedMints = {};

  @override
  void initState() {
    super.initState();
    _fetchRecommendedMints();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(
      title: 'Mints',
      children: [
        SettingsGroup(
          title: 'Connected Mints',
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 15, bottom: 5, left: 15, right: 15),
              child: Form(
                key: _formKey,
                child: Row(
                  children: [
                    Expanded(child: 
                      TextFormField(
                        initialValue: "https://",
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25)
                          ),
                          label: const Text('Add New Relay'),
                        ),
                        validator: (value) { 
                          if (value == null || value.isEmpty || value == 'https://') {
                            return "Mint url is required";
                          }

                          if (!value.startsWith('https://')) {
                            return "Mint url is invalid";
                          }

                          if (Cashu.shared.mints.where((e) => e.mintURL == value).isNotEmpty) {
                            return "This mint is already added";
                          }

                          Cashu.shared.addMint(value).then((isAdded) {
                            if (isAdded) {
                              setState(() {});
                            } else {
                              // ignore: use_build_context_synchronously
                              showDialog(context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Error!'),
                                  content: const Text('This mint is not found.'),
                                  actions: [
                                    TextButton(onPressed: () {Navigator.of(context).pop();}, child: const Text('OK')),
                                  ],
                                )
                              );
                            }
                          });
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 90,
                      height: 46,
                      child: FilledButton(
                        onPressed: () {
                          if(_formKey.currentState!.validate()) {
                            _formKey.currentState!.reset();
                          }
                        },
                        child: const Text('Add', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...List.generate(Cashu.shared.mints.length, 
              (index) => Container(
                margin: const EdgeInsets.only(top: 8, left: 15, right: 15),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 15),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black87.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 1,
                      offset: const Offset(1, 1), // changes position of shadow
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(child:
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Cashu.shared.mints[index].name, 
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.secondary
                            ),
                          ),
                          Text(Cashu.shared.mints[index].mintURL, 
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.secondary
                            ),
                          )
                        ]
                      )
                    ),
                    const SizedBox(width: 5),
                    Text('${Cashu.shared.proofs[Cashu.shared.mints[index]]!.totalAmount} sat',
                      style: TextStyle(
                        fontSize: 15, 
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.secondary
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        showDialog(context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Warning!'),
                            content: const Text('Are you sure you want to delete?'),
                            actions: [
                              TextButton(onPressed: () {Navigator.of(context).pop();}, child: const Text('Cancel')),
                              FilledButton(onPressed: () {
                                Navigator.of(context).pop();
                                setState(() {
                                  Cashu.shared.mints.remove(Cashu.shared.mints[index]);
                                });
                              }, child: const Text('Confirm')),
                            ],
                          )
                        );
                      }, 
                      icon: Icon(Icons.remove_circle, size: 24, color: Theme.of(context).colorScheme.error,),
                    )
                  ],
                )
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SettingsGroup(
          title: 'Recommended Mints',
          children: List.generate(recommendedMints.length, 
            (index) {
              String mintURL = recommendedMints.keys.toList()[index];
              return FadeInUp(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, left: 15, right: 15),
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 15),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black87.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 1,
                        offset: const Offset(1, 1), // changes position of shadow
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(mintURL, 
                          style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.secondary
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      IconButton(
                        onPressed: () {
                          if (Cashu.shared.mints.where((mint) => mint.mintURL == mintURL).isNotEmpty) return;
                          Cashu.shared.addMint(mintURL).then((_) {
                                setState(() {});
                          });
                        }, 
                        icon: Icon(Icons.add_circle, size: 24, color: Theme.of(context).colorScheme.primary),
                      )
                    ],
                  ),
                ),
              );
            }
          ),
        ),
      ],
    );
  }

  _fetchRecommendedMints() async {
    Subscription subscription = Subscription(
      filters: [Filter(kinds: [38000], limit: 50, k: ["38172"])],
      onEvent: (events) async {
        recommendedMints.clear();
        setState(() {
          for (var mintevent in events.keys) {
            final mintURL = events[mintevent]['tags'].where((t) => t[0] == 'u').first[1];
            if (recommendedMints.containsKey(mintURL)) {
              recommendedMints[mintURL]= recommendedMints[mintURL]! + 1;
            } else {
              recommendedMints[mintURL] = 0;
            }
          }       
        });
      }
    );
    RelayPool.shared.subscribe(subscription, timeout: 3);
    await subscription.finish.future;
    RelayPool.shared.unsubscribe(subscription.id);
  }
}