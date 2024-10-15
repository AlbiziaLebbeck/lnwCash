import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';


List transactionHist = [
  // {
  //   'type': 'send',
  //   'method': 'Cashu',
  //   'amount': '42',
  //   'date': '1 hr'
  // },
  // {
  //   'type': 'send',
  //   'method': 'Lightning',
  //   'amount' : '42',
  //   'date': '4 hr'
  // },
  // {
  //   'type': 'receive',
  //   'method': 'Cashu',
  //   'amount' : '3,345',
  //   'date': '1 day'
  // },
  // {
  //   "type": "receive",
  //   "method": "Lightning",
  //   "amount" : "1,000,000",
  //   'date': '1 day'
  // },
  // {
  //   "type": "receive",
  //   "method": "Lightning",
  //   "amount" : "1,000,000",
  //   'date': '1 day'
  // },
  // {
  //   "type": "receive",
  //   "method": "Lightning",
  //   "amount" : "1,000,000",
  //   'date': '1 day'
  // }
];

getTransactionHistory(context){
  return Container(
    height: MediaQuery.of(context).size.height - 621,
    padding: const EdgeInsets.only(left: 15, right: 15),
    child: ListView(
      scrollDirection: Axis.vertical,
      children: List.generate(transactionHist.length, 
        (index) => FadeInUp(child: TransactionView(transactionData: transactionHist[index]))
      )
    // ),
    ),
  );
}

class TransactionView extends StatelessWidget {
  const TransactionView({super.key, required this.transactionData});

  final Map transactionData;

  @override
  Widget build(BuildContext context) {
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
          transactionData['type']== 'send' ? const Icon(Icons.call_made, color: Colors.red,) : const Icon(Icons.call_received, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${(transactionData['type']== 'send' ? '-':'') + transactionData['amount']} sats', 
                style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.secondary
              ),
            )
          ),
          Text(transactionData['date'], 
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