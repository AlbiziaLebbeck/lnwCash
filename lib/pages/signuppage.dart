import 'package:flutter/material.dart';
import 'package:lnwcash/utils/nip01.dart';
import 'package:lnwcash/utils/relay.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lnwcash/pages/walletpage.dart';
import 'package:nostr_core_dart/nostr.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

   @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.surfaceContainer),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 150),
          width: 500,
          // decoration: BoxDecoration(
          //   color: Theme.of(context).colorScheme.surfaceContainer,
          // ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInLeft(
                child: Text("Sign Up",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary, 
                    fontSize: 42, 
                    fontWeight: FontWeight.bold, 
                    fontFamily: ''
                  ),
                ),
              ),
              const SizedBox(height: 10,),
              FadeInLeft(
                child: Text('Create your nostr account', 
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary, 
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 20,),
              FadeInUp(
                child: const SignupForm(),
              ),
            ]
          )
        ),
      ),
    );
  }
}


class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();

  late final SharedPreferences prefs;
  late Keychain keychain;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  void _loadPreference() async {
    prefs = await SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          TextFormField(
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
              labelText: 'How should we call you?',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Your name or AKA is required';
              }

              context.loaderOverlay.show();
              keychain = Keychain.generate();
              context.loaderOverlay.hide();
              prefs.setString('loginType', 'nsec');
              prefs.setString('priv', keychain.private);
              prefs.setString('pub', keychain.public);
              prefs.setString('profile', '{"name":"$value","display_name":"$value"}');

              return null;
            },
          ),
          const SizedBox(height: 20,),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              minimumSize: const Size(double.infinity, 55),
            ),
            onPressed: () async{
              // Validate returns true if the form is valid, or false otherwise.
              if (_formKey.currentState!.validate()) {
                var profile = prefs.getString('profile') ?? '{}';
                Event? event = await createEvent(
                  kind: 0, 
                  tags: [], 
                  content: profile,
                  pub: prefs.getString('pub'),
                  priv: prefs.getString('priv'),
                );
                RelayPool.shared.send(event!.serialize());
                Navigator.pushReplacement(
                  // ignore: use_build_context_synchronously
                  context,
                  MaterialPageRoute(builder: (context) => WalletPage(prefs: prefs,)),
                );
              }
            },
            child: const Text('Sign Up', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}