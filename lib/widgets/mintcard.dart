import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';


getMintCards(BuildContext context, mints){
  return SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: 5, left: 15),
    scrollDirection: Axis.horizontal,
    child: Row(
      children: List.generate(mints.length, 
        (index) => FadeInRight(child: MintCard(mintData: mints[index]))
      ),
    ),
  );
}

class MintCard extends StatelessWidget {
  const MintCard({super.key, this.mintData});
  // ignore: prefer_typing_uninitialized_variables
  final mintData;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.all(15),
      width: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black87.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 1,
            offset: const Offset(1, 1), // changes position of shadow
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mintData["url"], overflow: TextOverflow.ellipsis, 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.secondary
            ),
          ),
          const SizedBox(height: 5,),
          Row(
            children: [ 
              Icon(Icons.account_balance, color: Theme.of(context).colorScheme.secondary,),
              const SizedBox(width: 10,),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Amount", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),),
                  const SizedBox(height: 3,),
                  Text('${mintData["amount"]} sats', maxLines:1, overflow: TextOverflow.ellipsis, 
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.secondary
                    ),
                  ),
                ],
              ),
            ],
          ),        
        ],
      )
    );
  }
}