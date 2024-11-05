import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:lnwcash/signuppage.dart';
import 'package:lnwcash/walletpage.dart';
import 'package:lnwcash/utils/nip07.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Center(
        child: Container(
          padding: EdgeInsets.only(left: 48, right: 48, top: 0.1*MediaQuery.sizeOf(context).height),
          // width: 500,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                child: Container(
                  height: 0.3*MediaQuery.sizeOf(context).height,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/logo.png'),
                    ),
                  ),
                ),
              ),
              FadeInLeft(
                child: Text('lnwCash', 
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary, 
                    fontSize: 42, 
                    fontWeight: FontWeight.bold, 
                    fontFamily: ''
                  ),
                ),
              ),
              FadeInLeft(
                child: Text('Lightning & Nostr Wallet for Cashu', 
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary, 
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 42,),
              FadeInUp(child: const LoginForm()),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom,),
            ]
          ),
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  late final SharedPreferences prefs;

  bool passwordVisible=false; 

  late String pub;

  final nsecCtl = TextEditingController();

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
            controller: nsecCtl,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
              labelText: 'Enter your nsec',
              suffixIcon: Row( 
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () async {
                      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                      String? clipboardText = clipboardData?.text;
                      setState(() {
                        nsecCtl.text = clipboardText ?? '';
                      });
                    }, 
                    icon: const Icon(Icons.paste_sharp)
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        passwordVisible = !passwordVisible;
                      });
                    }, 
                    icon: Icon(passwordVisible ? Icons.visibility_off : Icons.visibility)
                  )
                ]
              )
            ),
            obscureText: !passwordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'nsec is required';
              }

              try {
                String priv = Nip19.decodePrivkey(value);
                prefs.setString('loginType', 'nsec');
                prefs.setString('priv', priv);
                prefs.setString('pub', Keychain.getPublicKey(priv));
                
              } on Exception {
                // Anything else that is an exception
                return 'nsec is invalid';
              }

              return null;
            },
          ),
          const SizedBox(height: 15,),
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
                  MaterialPageRoute(builder: (context) => WalletPage(prefs: prefs,)),
                );
              }
            },
            child: const Text('Login with nsec (insecure)', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 10,),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryFixedDim,
              minimumSize: const Size(double.infinity, 55),
            ),
            onPressed: () async {
              if (!nip07Support()){
                return;
              }

              String pub = await nip07GetPublicKey() ?? '';
              if (pub == '')
              {
                return; 
              }
              
              prefs.setString('loginType', 'nip07');
              prefs.setString('pub', pub);

              if (context.mounted)
              {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => WalletPage(prefs: prefs,)),
                );
              }
            },
            child: const Text('Login with nip-07', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 15,),
          TextButton(
              style: FilledButton.styleFrom(
                fixedSize: const Size(150, 45),
              ),
              onPressed: () => {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignupPage(prefs: prefs,)),
                )
              }, 
              child: const Text("Sign Up", style: TextStyle(fontSize: 16))
            )
        ],
      )
    );
  }
}

