import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

class NostrKeyPage extends StatefulWidget {
  const NostrKeyPage({super.key, required this.nsec, required this.npub});
  
  final String nsec;
  final String npub;

  @override
  State<StatefulWidget> createState() => _NostrKeyPage();
}

class _NostrKeyPage extends State<NostrKeyPage> {

  bool passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nostr Keys'), 
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Column(
          children: [
            SettingsGroup(
              title: 'Public Key (npub)',
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: TextFormField(
                    initialValue: widget.npub,
                    readOnly: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                      suffixIcon: IconButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: widget.npub));

                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('npub is copied'),
                              duration: const Duration(seconds: 3),
                              width: 200, // Width of the SnackBar.
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            )
                          );
                        }, 
                        icon: const Icon(Icons.copy)
                      ),
                    )
                  )
                )
              ],
            ),
            SettingsGroup(
              title: 'Private Key (nsec)',
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: TextFormField(
                    initialValue: widget.nsec,
                    readOnly: true,
                    obscureText: !passwordVisible,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                      prefixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            passwordVisible = !passwordVisible;
                          });
                        }, 
                        icon: Icon(passwordVisible ? Icons.visibility_off : Icons.visibility),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: widget.nsec));

                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('nsec is copied'),
                              duration: const Duration(seconds: 3),
                              width: 200, // Width of the SnackBar.
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            )
                          );
                        }, 
                        icon: const Icon(Icons.copy)
                      ),
                    )
                  )
                )
              ],
            ),
          ]
        ),
      ),
    );
  }
}