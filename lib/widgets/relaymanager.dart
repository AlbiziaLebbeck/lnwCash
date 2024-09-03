import 'package:flutter/material.dart';
import 'package:lnwcash/utils/relay.dart';

relayManager(context, relayPool, onDone) {
  return showModalBottomSheet(context: context, 
    builder: (context) => RelayManager(relayPool)
  ).then(onDone);
}

class RelayManager extends StatefulWidget {
  const RelayManager(this.relayPool, {super.key});

  final RelayPool relayPool;

  @override
  State<RelayManager> createState() => _RelatManager();
}

class _RelatManager extends State<RelayManager>{

  final _relayKey = GlobalKey<FormState>();

  late final RelayPool relayPool;

  @override
  void initState() {
    super.initState();

    setState(() {
      relayPool = widget.relayPool;
    });
  }

  @override
  Widget build(BuildContext context) {

    List<String> relaysURL = relayPool.getRelayURL();

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
          Text('Configure Nostr Relay', 
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 24, 
              fontWeight: FontWeight.bold, 
              fontFamily: ''
            ),
          ),
          const SizedBox(height: 25),
          Form(
            key: _relayKey,
            child: Column(
              children: [
                TextFormField(
                  initialValue: "wss://",
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25)
                    ),
                    labelText: 'Add new relay',
                  ),
                  validator: (value) { 
                    if (value == null || value.isEmpty || value == 'wss://') {
                      return "Relay url is required";
                    }

                    if (relaysURL.contains(value)) {
                      return "This relay is already added";
                    }

                    setState(() {
                      relayPool.add(value);
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
                    if(_relayKey.currentState!.validate()) {
                      _relayKey.currentState!.reset();
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
              children: List.generate(relaysURL.length, 
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
                      Expanded(child: Text(relaysURL[index], 
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
                          if (relaysURL.length > 1) {
                            setState(() {
                              relayPool.remove(relaysURL[index]);
                            });
                          }
                          else {
                            showDialog(context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Warning!'),
                                content: const Text('You need at least one relay.'),
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