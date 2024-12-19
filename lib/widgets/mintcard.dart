import 'package:cashu_dart/core/nuts/nut_00.dart';
import 'package:cashu_dart/model/mint_model.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lnwcash/utils/cashu.dart';


getMintCards(BuildContext context){
  return SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: 5, left: 15),
    scrollDirection: Axis.horizontal,
    child: Row(
      children: List.generate(Cashu.shared.mints.length, 
        (index) => FadeInRight(child: MintCard(mintData: Cashu.shared.mints[index]))
      ),
    ),
  );
}

class MintCard extends StatelessWidget {
  const MintCard({super.key, required this.mintData});
  // ignore: prefer_typing_uninitialized_variables
  final IMint mintData;

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
          Text(mintData.name, overflow: TextOverflow.ellipsis, 
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
                  Text('${Cashu.shared.proofs[mintData]!.isEmpty ? 0 : Cashu.shared.proofs[mintData]!.totalAmount} sat', maxLines:1, overflow: TextOverflow.ellipsis, 
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