import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:lnwcash/utils/relay.dart';
import 'package:lnwcash/utils/subscription.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Future<void> r 

class RelayPage extends StatefulWidget {
  const RelayPage({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<RelayPage> createState() => _RelatPage();
}

class _RelatPage extends State<RelayPage>{

  final _relayKey = GlobalKey<FormState>();
  final List<String> recommendedRelays = [];

  @override
  void initState() {
    super.initState();
    fetchRecommendedRelays();
  }

  @override
  Widget build(BuildContext context) {

    List<String> relaysURL = RelayPool.shared.getRelayURL();

    return SettingsScreen(
      title: 'Relays',
      children: [
        SettingsGroup(
          title: 'Add New Relay',
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              child: Form(
                key: _relayKey,
                child: Row(
                  children: [
                    Expanded(child: TextFormField(
                        initialValue: "wss://",
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25)
                          ),
                        ),
                        validator: (value) { 
                          if (value == null || value.isEmpty || value == 'wss://') {
                            return "Relay url is required";
                          }

                          if (relaysURL.contains(value)) {
                            return "This relay is already added";
                          }

                          setState(() {
                            RelayPool.shared.add(value).then((_) {
                              setState(() {});
                            });
                            widget.prefs.setStringList('relays', RelayPool.shared.getRelayURL());
                          });

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 90,
                      height: 46,
                      child: FilledButton(
                        onPressed: () {
                          if(_relayKey.currentState!.validate()) {
                            _relayKey.currentState!.reset();
                          }
                        },
                        child: const Text('Add', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ]
        ),
        SettingsGroup(
          title: 'Connected Relays',
          children: List.generate(relaysURL.length, 
            (index) => Container(
              margin: const EdgeInsets.only(top: 8, left: 15, right: 15),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 15),
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
                  RelayPool.shared.getRelayConnection(relaysURL[index]) ?
                    const Icon(Icons.check_circle, size: 24, color: Colors.green,):
                    const Icon(Icons.sync, size: 24, color: Colors.orange,),
                  const SizedBox(width: 10),
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
                      showDialog(context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Warning!'),
                          content: const Text('Are you sure you want to delete?'),
                          actions: [
                            TextButton(onPressed: () {Navigator.of(context).pop();}, child: const Text('Cancel')),
                            FilledButton(onPressed: () {
                              Navigator.of(context).pop();
                              setState(() {
                                RelayPool.shared.remove(relaysURL[index]);
                                widget.prefs.setStringList('relays', RelayPool.shared.getRelayURL());
                              });
                            }, child: const Text('Confirm')),
                          ],
                        )
                      );
                    }, 
                    icon: Icon(Icons.remove_circle, size: 24, color: Theme.of(context).colorScheme.error,),
                  )
                ],
              )
            ),
          ),
        ),
        const SizedBox(height: 10),
        SettingsGroup(
          title: 'Recommended Relays',
          children: List.generate(recommendedRelays.length, 
            (index) => FadeInUp(
              child: Container(
                margin: const EdgeInsets.only(top: 8, left: 15, right: 15),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 15),
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
                    Expanded(child: Text(recommendedRelays[index], 
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
                        RelayPool.shared.add(recommendedRelays[index]).then((_) {
                          setState(() {});
                        });
                        recommendedRelays.removeAt(index);
                        widget.prefs.setStringList('relays', RelayPool.shared.getRelayURL());
                      }, 
                      icon: Icon(Icons.add_circle, size: 24, color: Theme.of(context).colorScheme.primary),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  fetchRecommendedRelays () async {
    Subscription subscription = Subscription(
      filters: [Filter(kinds: [10002], limit: 1)],
      onEvent: (events) async {
        final relayList = RelayPool.shared.getRelayURL();
        setState(() {
          for (var relay in events[events.keys.first]['tags']) {
            if(relayList.contains(relay[1])) continue;
            recommendedRelays.add(relay[1]);
          }          
        });
      }
    );
    RelayPool.shared.subscribe(subscription, timeout: 3);
    await subscription.finish.future;
    RelayPool.shared.unsubscribe(subscription.id);
  }
}