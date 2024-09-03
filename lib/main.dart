import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:lnwcash/loginpage.dart';
import 'package:lnwcash/walletpage.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    return GlobalLoaderOverlay(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'lnw.Cash',
        theme: ThemeData(
          colorSchemeSeed: Colors.orange,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.purple,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.light,
        home: const UserAuthenication(),
      ),
    );
  }
}

class UserAuthenication extends StatefulWidget {
  const UserAuthenication({super.key});

  @override
  State<UserAuthenication> createState() => _UserAuthenication();
}

class _UserAuthenication extends State<UserAuthenication> {

  String loginType = '';
  late final SharedPreferences prefs;

  @override
  void initState() {
    super.initState();

    _loadPreference();
  }

  void _loadPreference() async {
    prefs = await SharedPreferences.getInstance();

    setState(() {
      loginType = prefs.getString("loginType") ?? '';
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return loginType == ''? const LoginPage() : WalletPage(prefs: prefs);
  }
}