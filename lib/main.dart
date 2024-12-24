import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:lnwcash/pages/loginpage.dart';
import 'package:lnwcash/pages/walletpage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: Consumer<ThemeNotifier>(
        builder: (context, ThemeNotifier themeNotifier, child) {
          return GlobalLoaderOverlay(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'lnwCash',
              theme: ThemeData(
                colorSchemeSeed: themeNotifier.colorScheme,
                useMaterial3: true,
                brightness: themeNotifier.isDark ? Brightness.dark : Brightness.light,
              ),
              home: UserAuthenication(themeNotifier: themeNotifier),
            )
          );
        },
      )
    );
  }
}

class UserAuthenication extends StatefulWidget {
  const UserAuthenication({super.key, required this.themeNotifier});

  final ThemeNotifier themeNotifier;

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
    _initSettings();
  }

  void _loadPreference() async {
    prefs = await SharedPreferences.getInstance();

    setState(() {
      loginType = prefs.getString("loginType") ?? '';
    });
  }

  void _initSettings() async{
    await Settings.init(
      cacheProvider: SharePreferenceCache(),
    );

    widget.themeNotifier.isDark = Settings.getValue<bool>('key-dark-mode') ?? false;

    String? colorHex = Settings.getValue<String>('key-color-picker');
    widget.themeNotifier.colorScheme = colorHex != null ? 
      Color(int.parse(colorHex.replaceFirst('#', ''), radix: 16)) : 
      Colors.orange;
  }
  
  @override
  Widget build(BuildContext context) {
    return loginType == ''? const LoginPage() : WalletPage(prefs: prefs);
  }
}

class ThemeNotifier extends ChangeNotifier {
  late bool _isDark;
  bool get isDark => _isDark;

  late Color _colorScheme;
  Color get colorScheme => _colorScheme;

  ThemeNotifier() {
    _isDark = false;
    _colorScheme = Colors.orange;
  }

  set isDark(bool value) {
    _isDark = value;
    notifyListeners();
  }

  set colorScheme(Color value) {
    _colorScheme = value;
    notifyListeners();
  }
}