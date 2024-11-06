import 'package:cashu_dart/core/nuts/nut_00.dart';
import 'package:cashu_dart/core/nuts/v1/nut_05.dart';
import 'package:cashu_dart/model/mint_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lnwcash/utils/cashu.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:qrcode_reader_web/qrcode_reader_web.dart';

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
                      child: Text('${Cashu.shared.mints[idx].mintURL} (${Cashu.shared.proofs[Cashu.shared.mints[idx]]!.totalAmount} sat)'),
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
                    labelText: 'Paste a lightning invoice',
                    suffixIcon: Container(
                      margin: const EdgeInsets.only(right: 5),
                      child:Column(
                        // mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () async {
                              showDialog(context: context,
                                builder: (context) => AlertDialog(
                                  content: SizedBox(
                                    width: 320.0,
                                    height: 320.0,
                                    child: QRCodeReaderSquareWidget(
                                      onDetect: (QRCodeCapture capture) {
                                        _lightningController.text = capture.raw;
                                        Navigator.of(context).pop();
                                      },
                                      size: 320,
                                    ),
                                  ),
                                ),
                              );
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
                    if (value!.isEmpty) return 'Lightning invoice is empty';
                    
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
                    if(_lightningFormKey.currentState!.validate()) {
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
          const Text('Select mint:', style: const TextStyle(fontSize: 16),),
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
                child: Text(widget.quotes.keys.toList()[idx].mintURL),
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