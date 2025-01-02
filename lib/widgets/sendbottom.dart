import 'dart:convert';

import 'package:cashu_dart/core/nuts/nut_00.dart';
import 'package:cashu_dart/core/nuts/v1/nut_05.dart';
import 'package:cashu_dart/model/mint_model.dart';
import 'package:cashu_dart/utils/network/http_client.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lnwcash/pages/qrscanpage.dart';
import 'package:lnwcash/utils/cashu.dart';

import 'package:loader_overlay/loader_overlay.dart';
import 'package:bech32/bech32.dart';
// ignore: implementation_imports
import 'package:bolt11_decoder/src/word_reader.dart';

Future<dynamic> sendButtomSheet(context) async{
  return showModalBottomSheet(context: context,
    builder: (context,) => const SendButtomSheet()    
  );
}

class SendButtomSheet extends StatefulWidget {
  const SendButtomSheet({super.key});

  @override
  State<SendButtomSheet> createState() => _SendButtomSheet();
}

class _SendButtomSheet extends State<SendButtomSheet> {

  int _selected = 0;
  String currentMint = Cashu.shared.mints[0].mintURL;

  final _ecashFormKey = GlobalKey<FormState>();
  final _lightningFormKey = GlobalKey<FormState>();

  final TextEditingController _lightningController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 400,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      child: Column(
        children: [
          Text('Send', 
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 24, 
              fontWeight: FontWeight.bold, 
              fontFamily: ''
            ),
          ),
          const SizedBox(height: 15,),
          SegmentedButton(
            style: SegmentedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
            segments: const <ButtonSegment<int>>[
              ButtonSegment(value: 0, label: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                  child: Text('Ecash', style: TextStyle(fontSize: 14,),),
                )
              ),
              ButtonSegment(value: 1, label: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                  child: Text('Lightning', style: TextStyle(fontSize: 14,)),
                )
              ),
            ],
            showSelectedIcon: false,
            selected: {_selected},
            onSelectionChanged: (Set<int> index) => {
              setState(() {
                _selected = index.first;
              })
            },
          ),
          const SizedBox(height: 25,),
          _selected == 0 ? Form(
            key: _ecashFormKey,
            child: Column(
              children: [
                TextFormField(
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly
                  ], 
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                    labelText: 'Amount (sat)',
                  ),
                  validator: (value) {
                    if (value == "") {
                      return "Please fill amount of sat";
                    }

                    int amount = int.parse(value!);
                    if (amount <= 0) {
                      return "Amount should greater than 0"; 
                    }
                    
                    IMint mint = Cashu.shared.getMint(currentMint);
                    if (amount > Cashu.shared.proofs[mint]!.totalAmount) {
                      return "Mint balance is insufficient";
                    }  
                    
                    context.loaderOverlay.show();
                    Cashu.shared.sendEcash(mint, amount);
                    return null;
                  },
                ),
                const SizedBox(height: 10,),
                DropdownButtonFormField(
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25))
                  ),
                  isExpanded: true,
                  value: Cashu.shared.mints[0].mintURL,
                  items: List.generate(
                    Cashu.shared.mints.length,
                    (idx) => DropdownMenuItem(
                      value: Cashu.shared.mints[idx].mintURL, 
                      child: Text('${Cashu.shared.mints[idx].name} (${Cashu.shared.proofs[Cashu.shared.mints[idx]]!.totalAmount} sat)'),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      currentMint = value!;
                    });
                  },
                ),
                const SizedBox(height: 25,),
                FilledButton(
                  style: FilledButton.styleFrom(
                    // backgroundColor: Theme.of(context).colorScheme.primaryFixedDim,
                    minimumSize: const Size(double.infinity, 55),
                    textStyle: const TextStyle(fontSize: 16)
                  ),
                  onPressed: () {
                    if(_ecashFormKey.currentState!.validate()) {
                      Navigator.of(context).pop('cashu');
                    }
                  },
                  child: const Text('Send'),
                )
              ],
            )
          ) : 
          Form(
            key: _lightningFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _lightningController,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    labelText: 'Paste a lightning invoice or address',
                    suffixIcon: Container(
                      margin: const EdgeInsets.only(right: 5),
                      child:Column(
                        // mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () async {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const BarcodeScannerSimple(),
                                ),
                              ).then((captureText) {
                                _lightningController.text = captureText;
                              });
                            },
                            icon: const Icon(Icons.qr_code),
                          ), 
                          IconButton(
                            onPressed: () async {
                              final invoice = await Clipboard.getData('text/plain');
                              if (invoice != null) {
                                _lightningController.text = invoice.text ?? '';
                              }
                            },
                            icon: const Icon(Icons.paste),
                          ),
                        ],
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return 'Lightning invoice or address is empty';
                    
                    return Cashu.shared.payingLightningInvoice(value);
                  }
                ),
                const SizedBox(height: 25,),
                FilledButton(
                  style: FilledButton.styleFrom(
                    // backgroundColor: Theme.of(context).colorScheme.primaryFixedDim,
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  onPressed: () async {
                    final lnurl = await checkLnAddress(_lightningController.text, context);
                    if (lnurl != null) {
                      Cashu.shared.payingLightningInvoice(lnurl);
                      // ignore: use_build_context_synchronously
                      context.loaderOverlay.show();
                      // ignore: use_build_context_synchronously
                      Navigator.of(context).pop('lightning');
                    } else if (_lightningFormKey.currentState!.validate()) {
                      // ignore: use_build_context_synchronously
                      context.loaderOverlay.show();
                      // ignore: use_build_context_synchronously
                      Navigator.of(context).pop('lightning');
                    }
                  },
                  child: const Text('Send', style: TextStyle(fontSize: 16)),
                )
              ],
            )
          ),
        ],
      )
    );
  }
}

Future<String?> checkLnAddress(String lnText, BuildContext context) async {
  if (lnText.startsWith('lightning:')) {
    lnText = lnText.substring('lightning:'.length);
  }
  
  if (lnText.toLowerCase().startsWith('lnurl')) {
    final bech32 = const Bech32Codec().decode(
      lnText,
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
      final lnurl = await showDialog(context: context,
        builder: (context) => PayLNAddressDialog(lnText, response.data),
      );

      if (lnurl != null) {
        return lnurl;
      }
    }
  }

  if (lnText.split('@').length == 2) {
    final username = lnText.split('@')[0];
    final domain = lnText.split('@')[1];
    final response = await HTTPClient.get(
      'https://$domain/.well-known/lnurlp/$username',
      modelBuilder: (json) {
        if (json is !Map) return null; 
        return json;
      },
    );
    if (response.isSuccess) {
      // ignore: use_build_context_synchronously
      final lnurl = await showDialog(context: context,
        builder: (context) => PayLNAddressDialog(lnText, response.data),
      );

      if (lnurl != null) {
        return lnurl;
      }
    }
  }

  return null;
}

class PayQuoteDialog extends StatefulWidget {
  const PayQuoteDialog(this.quotes, {super.key});

  final Map<IMint,MeltQuotePayload> quotes;

  @override
  State<PayQuoteDialog> createState() => _PayQuoteDialog();
}

class _PayQuoteDialog extends State<PayQuoteDialog> {

  late IMint _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.quotes.keys.toList()[0];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Send ${widget.quotes[widget.quotes.keys.toList()[0]]!.amount} sat via lightning",
        style: const TextStyle(fontSize: 20),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select mint:', style: TextStyle(fontSize: 16),),
          const SizedBox(height: 10,),
          DropdownButtonFormField(
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25))
            ),
            isExpanded: true,
            value: widget.quotes.keys.toList()[0],
            items: List.generate(
              widget.quotes.length,
              (idx) => DropdownMenuItem(
                value: widget.quotes.keys.toList()[idx], 
                child: Text(widget.quotes.keys.toList()[idx].name),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _selected = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Text('Fee: ${widget.quotes[_selected]!.fee} sat', 
              style: const TextStyle(fontSize: 16),
            ),
            const Expanded(child: SizedBox(height: 10,)),
            FilledButton(
              onPressed: () {
                Cashu.shared.payQuote(
                  _selected, 
                  widget.quotes[_selected]!
                );
                Navigator.of(context).pop("paying");
              }, 
              child: const Text('Send', style: TextStyle(fontSize: 16))
            ),
            const SizedBox(width: 5,),
            TextButton(
              onPressed: () {Navigator.of(context).pop();}, 
              child: const Text('Close', style: TextStyle(fontSize: 16))
            ),
          ]
        ),
      ],
    );
  }
}

class PayLNAddressDialog extends StatefulWidget {
  const PayLNAddressDialog(this.address, this.payRequest, {super.key});

  final String address;
  final Map payRequest;

  @override
  State<PayLNAddressDialog> createState() => _PayLNAddressDialog();
}

class _PayLNAddressDialog extends State<PayLNAddressDialog> {

  bool _validate = false;
  String _errorText = '';
  final _amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Send to:",
        style: TextStyle(fontSize: 20),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.address,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 10,),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly
            ], 
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
              labelText: 'Amount (sat)',
              errorText: _validate ? _errorText : null,
            ),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            const Expanded(child: SizedBox(height: 10,)),
            FilledButton(
              onPressed: () async {
                if (_amountController.text == "") {
                  setState(() {
                    _errorText = 'Please fill amount of sat';
                    _validate = true;
                  });
                  return;
                }

                int amount = int.parse(_amountController.text);
                int minSendable = widget.payRequest['minSendable']~/1000;
                if (amount < minSendable) {
                  setState(() {
                    _errorText = 'Amount must not less than $minSendable';
                    _validate = true;
                  });
                  return;
                }

                int maxSendable = widget.payRequest['maxSendable']~/1000;
                if (amount > maxSendable) {
                  setState(() {
                    _errorText = 'Amount must not greater than $maxSendable';
                    _validate = true;
                  });
                  return;
                }

                final response = await HTTPClient.get(
                  widget.payRequest['callback'] + '?amount=${amount*1000}',
                  modelBuilder: (json) {
                    return json['pr'];
                  },
                );

                if (response.isSuccess) {
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop(response.data);
                } else {
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop();
                }
              }, 
              child: const Text('Send', style: TextStyle(fontSize: 16))
            ),
            const SizedBox(width: 5,),
            TextButton(
              onPressed: () {Navigator.of(context).pop();}, 
              child: const Text('Close', style: TextStyle(fontSize: 16))
            ),
          ]
        ),
      ],
    );
  }
}