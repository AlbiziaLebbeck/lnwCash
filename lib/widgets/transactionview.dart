import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nostr_core_dart/nostr.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:lnwcash/utils/nip60.dart';


getTransactionHistory(context){
  return Expanded(
    child: ListView(
      scrollDirection: Axis.vertical,
      children: List.generate(Nip60.shared.histories.length, 
        (index) => FadeInUp(child: TransactionView(transactionData: Nip60.shared.histories[index]))
      ),
    // ),
    ),
  );
}

class TransactionView extends StatelessWidget {
  const TransactionView({super.key, required this.transactionData});

  final Map<String,String> transactionData;

  @override
  Widget build(BuildContext context) {

    String timediffStr = "";
    int timediff = currentUnixTimestampSeconds() - int.parse(transactionData['time']!);
    if (timediff < 60) {
      timediffStr = "< 1 minute";
    } else if (timediff < 3600) {
      timediffStr = "${timediff~/60} minute${timediff~/60 > 1 ?"s":""}";
    } else if (timediff < 3600*24) {
      timediffStr = "${timediff~/3600} hour${timediff~/3600 > 1 ?"s":""}";
    } else {
      timediffStr = "${timediff~/(3600*24)} day${timediff~/(3600*24) > 1 ?"s":""}";
    }

    var dt = DateTime.fromMillisecondsSinceEpoch(1000 * int.parse(transactionData['time']!));

    final type = transactionData['type'] ?? '';

    return GestureDetector(
      onTap: () {
        showDialog(context: context,
          builder: (context) => ScaffoldMessenger(
            child: Builder(
              builder: (context) => Scaffold(
                backgroundColor: Colors.transparent,
                body: AlertDialog(
                  title: Text('${transactionData['direction'] == 'out' ? 'Send' : 'Receive'} ${type == 'lightning' ? 'via lightning' : type}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary
                    ),
                  ),
                  content: SizedBox(
                    width: 320,
                    height: transactionData['detail'] == '' ? 110 : 450,
                    child: Column(children: [
                      Text('${transactionData['amount']!} sat',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.secondary
                        ),
                      ),
                      const SizedBox(height: 15,),
                      Text(DateFormat('E, d MMM y - H:mm').format(dt),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.secondary
                        ),
                      ),
                      const SizedBox(height: 10,),
                      transactionData['detail'] == '' ? 
                        const SizedBox(height: 0,) :
                        QrImageView(
                          data: transactionData['detail']!,
                          version: QrVersions.auto,
                          backgroundColor: Colors.white,
                        ),
                      const SizedBox(height: 15,),
                      transactionData['detail'] == '' ? 
                        const SizedBox(height:  0,) :
                        Text('${transactionData['detail']!.substring(0,21)}...',
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
                        transactionData['detail'] == '' ? const SizedBox(width: 0,):
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: transactionData['detail']!));
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
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                )
              ),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 15, right: 15),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 25),
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
            transactionData['direction'] == 'out' ? const Icon(Icons.call_made, color: Colors.red,) : const Icon(Icons.call_received, color: Colors.green),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${transactionData['direction'] == 'out' ? 'Send' : 'Receive'} ${type == 'lightning' ? 'via lightning' : type}', 
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.secondary
                  ),
                ),
                Text('$timediffStr ago', 
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.secondary
                  ),
                ),
              ],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transactionData['direction'] == 'out' ? '-' : ''}${transactionData['amount']!} sat', 
                      style: TextStyle(
                      fontSize: 15, 
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.secondary
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
      ),
    );
  }

  void _callSnackBar(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 3),
        width: 200, // Width of the SnackBar.
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      )
    );
  }
}