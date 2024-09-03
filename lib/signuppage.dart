import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lnwcash/walletpage.dart';
import 'package:nostr_core_dart/nostr.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({super.key, required this.prefs});

  final SharedPreferences prefs;

   @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.surfaceContainer),
      body: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 150),
          width: 500,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
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
                child: SignupForm(prefs: prefs,),
              ),
            ]
          )
        ),
      ),
    );
  }
}


class SignupForm extends StatefulWidget {
  const SignupForm({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();

  late Keychain keychain;

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

              keychain = Keychain.generate();
              widget.prefs.setString('loginType', 'nsec');
              widget.prefs.setString('priv', keychain.private);
              widget.prefs.setString('pub', keychain.public);

              return null;
            },
          ),
          const SizedBox(height: 20,),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryFixedDim,
              minimumSize: const Size(double.infinity, 55),
            ),
            onPressed: () {
              // Validate returns true if the form is valid, or false otherwise.
              if (_formKey.currentState!.validate()) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => WalletPage(prefs: widget.prefs,)),
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