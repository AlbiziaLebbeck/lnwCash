import 'package:cashu_dart/business/proof/token_helper.dart';
import 'package:cashu_dart/model/mint_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lnwcash/utils/cashu.dart';
import 'package:qrcode_reader_web/qrcode_reader_web.dart';

Future<dynamic> receiveButtomSheet(context) async{
  return showModalBottomSheet(context: context,
    builder: (context,) => const ReceiveButtomSheet()    
  );
}

class ReceiveButtomSheet extends StatefulWidget {
  const ReceiveButtomSheet({super.key});

  @override
  State<ReceiveButtomSheet> createState() => _ReceiveButtomSheet();
}

class _ReceiveButtomSheet extends State<ReceiveButtomSheet> {

  int _selected = 0;
  String currentMint = Cashu.shared.mints[0].mintURL;

  final _ecashFormKey = GlobalKey<FormState>();
  final _lightningFormKey = GlobalKey<FormState>();

  final TextEditingController _ecashController = TextEditingController();

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
          Text('Receive', 
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
                  controller: _ecashController,
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
                    labelText: 'Paste a cashu token',
                    suffixIcon: Container(
                      margin: const EdgeInsets.only(right: 5),
                      child: Column(
                        // mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () async {
                              showDialog(context: context,
                                builder: (context) => QRCodeReaderTransparentWidget(
                                  onDetect: (QRCodeCapture capture) {
                                    _ecashController.text = capture.raw;
                                    Navigator.of(context).pop();
                                  },
                                ),
                              );
                            },
                            icon: const Icon(Icons.qr_code),
                          ),
                          IconButton(
                            onPressed: () async {
                              final ecash = await Clipboard.getData('text/plain');
                              if (ecash != null) {
                                _ecashController.text = ecash.text ?? '';
                              }
                            },
                            icon: const Icon(Icons.paste),
                          ),
                        ]
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return 'Token is empty';
                    if (value.startsWith('cashuB')) return 'V4 is not supported';
                    final token = TokenHelper.getDecodedToken(value);
                    if (token == null) return 'Invalid token';

                    Cashu.shared.redeemEcash(token: token);

                    return null;
                  }
                ),
                const SizedBox(height: 25,),
                FilledButton(
                  style: FilledButton.styleFrom(
                    // backgroundColor: Theme.of(context).colorScheme.primaryFixedDim,
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  onPressed: () async {
                    if(_ecashFormKey.currentState!.validate()) {
                      Navigator.of(context).pop('cashu');
                    }
                  },
                  child: const Text('Receive', style: TextStyle(fontSize: 16)),
                )
              ],
            )
          ) : 
          Form(
            key: _lightningFormKey,
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
                    Cashu.shared.createLightningInvoice(mint: mint, amount: amount, context: context);
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
                  value: Cashu.shared.mints[0].mintURL,
                  items: List.generate(
                    Cashu.shared.mints.length,
                    (idx) => DropdownMenuItem(
                      value: Cashu.shared.mints[idx].mintURL, 
                      child: Text(Cashu.shared.mints[idx].mintURL),
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
                    if(_lightningFormKey.currentState!.validate()) {
                      Navigator.of(context).pop('lightning');
                    }
                  },
                  child: const Text('Receive'),
                )
              ],
            )
          ),
        ],
      )
    );
  }
}