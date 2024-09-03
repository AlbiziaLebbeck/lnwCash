import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

paymentButtomSheet(context){
  return showModalBottomSheet(context: context,
    builder: (context) => const PaymentButtomSheet()    
  );
}

// enum PaymentType { ecash, lightning }

class PaymentButtomSheet extends StatefulWidget {
  const PaymentButtomSheet({super.key});

  @override
  State<PaymentButtomSheet> createState() => _PaymentButtomSheet();
}

class _PaymentButtomSheet extends State<PaymentButtomSheet> {

  int _selected = 0;

  final _ecashFormKey = GlobalKey<FormState>();
  final _lightningFormKey = GlobalKey<FormState>();

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
                  ),
                ),
                const SizedBox(height: 25,),
                FilledButton(
                  style: FilledButton.styleFrom(
                    // backgroundColor: Theme.of(context).colorScheme.primaryFixedDim,
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  onPressed: () {
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
                    labelText: 'Amount (sats)',
                  ),
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
                  value: 'mint1',
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'mint1', child: Text('mint1')),
                    DropdownMenuItem(value: 'mint2', child: Text('mint2'))
                  ],
                  onChanged: (value) => {},
                ),
                const SizedBox(height: 25,),
                FilledButton(
                  style: FilledButton.styleFrom(
                    // backgroundColor: Theme.of(context).colorScheme.primaryFixedDim,
                    minimumSize: const Size(double.infinity, 55),
                    textStyle: const TextStyle(fontSize: 16)
                  ),
                  onPressed: () {
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
