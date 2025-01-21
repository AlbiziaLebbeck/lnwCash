import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pwa_install/pwa_install.dart';

// import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt_shared_preferences/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:lnwcash/pages/signuppage.dart';
import 'package:lnwcash/pages/walletpage.dart';
import 'package:lnwcash/utils/nip07.dart'
  if (dart.library.js) 'package:lnwcash/utils/nip07_web.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.sizeOf(context).height;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Center(
        child: Container(
          // padding: EdgeInsets.only(left: 48, right: 48, top: MediaQuery.sizeOf(context).height / 2 - 330),
          padding: EdgeInsets.only(left: 48, right: 48, top: height > 700 ? (height - 700)/2 : 0),
          width: 500,
          child: Column(
            children: [
              FadeInDown(
                child: Container(
                  height: 200,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('images/lnwCash.png'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeInLeft(
                child: Text('Take Control of Your Satoshi with Ecash', 
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary, 
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              FadeInRight(
                child: Text(
                  'LnwCash is a custodial wallet that holds your funds with ecash, a bearer token fully backed by Bitcoin through the Lightning Network and the Cashu protocol.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary, 
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              FadeInRight(
                child: Text(
                  'This wallet ensures privacy and security in payments while allowing seamless backup of your ecash in Nostr relays.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary, 
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              if (kIsWeb && PWAInstall().installPromptEnabled) FadeInUp(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  onPressed: () {
                    try {
                      PWAInstall().promptInstall_();
                    } catch (e) {
                      debugPrint(e.toString());
                    }
                  }, 
                  child: const Text('Install PWA', style: TextStyle(fontSize: 18,)),
                ),
              ),
              if (kIsWeb && PWAInstall().installPromptEnabled) const SizedBox(height: 10),
              FadeInUp(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GetStartedPage()),
                    );
                  },
                  child: const Text('Get Started', style: TextStyle(fontSize: 16)),
                ),
              ),
            ]
          ),
        ),
      ),
    );
  }
}

class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.surfaceContainer),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 42),
          width: 500,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FadeInDown(
                child: Container(
                  height: 200,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('images/logo.png'),
                    ),
                  ),
                ),
              ),
              FadeInDown(
                child: Text(
                  'Already have a Nostr account?\nLogin to instantly access your wallet.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              FadeInRight(child: const LoginForm()),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Divider(
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('or', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary)),
                  ),
                  const Expanded(
                    child: Divider(
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'New to Nostr?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary, 
                  fontSize: 16, 
                  fontWeight: FontWeight.bold
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              FadeInUp(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  onPressed: () => {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignupPage()),
                    )
                  }, 
                  child: const Text("Generate new Nostr account", style: TextStyle(fontSize: 16))
                ),
              ),
            ],
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
  late final EncryptedSharedPreferences prefs;

  bool passwordVisible=false; 

  late String pub;

  final nsecCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  void _loadPreference() async {
    await dotenv.load(fileName: '.env');
    final secret = dotenv.env['SECRET']!;
    await EncryptedSharedPreferences.initialize(secret);
    prefs = EncryptedSharedPreferences.getInstance();
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
              backgroundColor: Theme.of(context).colorScheme.primary,
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
            child: const Text('Login with nsec', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 10,),
          kIsWeb ? FilledButton(
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
          ) : const SizedBox(height: 0,),
        ],
      )
    );
  }
}

