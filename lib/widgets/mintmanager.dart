import 'package:flutter/material.dart';

Future<void> mintManager(context, mints) async {
  return showModalBottomSheet(context: context, 
    builder: (context) => MintManager(mints),
  );
}

class MintManager extends StatefulWidget {
  const MintManager(this.mints, {super.key});

  final dynamic mints;

  @override
  State<MintManager> createState() => _MintManager();
}

class _MintManager extends State<MintManager>{
  
  late dynamic mints;
  final _mintKey = GlobalKey<FormState>();
  
  @override
  void initState() {
    super.initState();
    mints = widget.mints;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Column(
        children: [
          Text('Configure Cashu Mints', 
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 24, 
              fontWeight: FontWeight.bold, 
              fontFamily: ''
            ),
          ),
          const SizedBox(height: 25),
          Form(
            key: _mintKey,
            child: Column(
              children: [
                TextFormField(
                  initialValue: "https://",
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25)
                    ),
                    labelText: 'Add new mint',
                  ),
                  validator: (value) { 
                    if (value == null || value.isEmpty || value == 'https://') {
                      return "Mint url is required";
                    }

                    if (mints.where((e) => e['url'] == value).isNotEmpty) {
                      return "This mint is already added";
                    }

                    setState(() {
                      mints.add({'url':value, 'amount':0});
                    });

                    return null;
                  },
                ),
                const SizedBox(height: 10,),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  onPressed: () {
                    if(_mintKey.currentState!.validate()) {
                      _mintKey.currentState!.reset();
                    }
                  },
                  child: const Text('Add', style: TextStyle(fontSize: 16)),
                )
              ],
            )
          ),
          const SizedBox(height: 15,),
          SizedBox(
            height: MediaQuery.of(context).size.height/2 -190,
            child: ListView(
              scrollDirection: Axis.vertical,
              children: List.generate(mints.length, 
                (index) => Container(
                  margin: const EdgeInsets.only(bottom: 8, right: 3),
                  padding: const EdgeInsets.only(top: 4, bottom: 4, left: 32, right: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black87.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 1,
                        offset: const Offset(1, 1), // changes position of shadow
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(mints[index]['url'], 
                            style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.secondary
                          ),
                        )
                      ),
                      const SizedBox(width: 5),
                      IconButton(
                        onPressed: () {
                          if (mints.length > 1) {
                            setState(() {
                              mints.removeAt(index);
                            });
                          }
                          else {
                            showDialog(context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Warning!'),
                                content: const Text('You need at least one mint.'),
                                actions: [
                                  TextButton(onPressed: () {Navigator.of(context).pop();}, child: const Text('OK')),
                                ],
                              )
                            );
                          }
                        }, 
                        icon: Icon(Icons.delete_forever, size: 32, color: Theme.of(context).colorScheme.error,),
                      )
                    ],
                  )
                ),
              )
            )
          ),
        ]
      ),
    );
  }
}