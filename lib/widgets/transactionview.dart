import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lnwcash/utils/nip60.dart';
import 'package:nostr_core_dart/nostr.dart';


getTransactionHistory(context){
  return Container(
    height: MediaQuery.of(context).size.height - 530, //621
    padding: const EdgeInsets.only(left: 15, right: 15),
    child: ListView(
      scrollDirection: Axis.vertical,
      children: List.generate(Nip60.shared.histories.length, 
        (index) => FadeInUp(child: TransactionView(transactionData: Nip60.shared.histories[index]))
      )
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8, right: 2),
      padding: const EdgeInsets.only(top: 16, bottom: 16, left: 32, right: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(1),
        borderRadius: BorderRadius.circular(32),
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
          Expanded(
            child: Text(
              '${(transactionData['type'] == 'out' ? '-':'')}${transactionData['amount']!} sat', 
                style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.secondary
              ),
            )
          ),
          Text(timediffStr, 
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.secondary
            ),
          ),
        ],
      )
    );
  }
}