import 'package:encrypt_shared_preferences/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:lnwcash/pages/loginpage.dart';
import 'package:lnwcash/pages/walletpage.dart';
import 'package:pwa_install/pwa_install.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  if (kIsWeb) {
    PWAInstall().setup(installCallback: () {
      debugPrint('APP INSTALLED!');
    });
  }

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
              title: 'LnwCash',
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
  late final EncryptedSharedPreferences prefs;

  @override
  void initState() {
    super.initState();

    _loadPreference();
    _initSettings();
  }

  void _loadPreference() async {
    await dotenv.load(fileName: '.env');
    final secret = dotenv.env['SECRET']!;
    await EncryptedSharedPreferences.initialize(secret);
    prefs = EncryptedSharedPreferences.getInstance();

    final oldPrefs = await SharedPreferences.getInstance();
    if (oldPrefs.containsKey('loginType')) {
      final oldKeys = oldPrefs.getKeys();
      for (var key in oldKeys) {
        try {
          prefs.setString(key, oldPrefs.getString(key) ?? '');
        } catch(_) {
          
        }
        oldPrefs.remove(key);
      }
    }

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
      Colors.lightBlue;
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
    _colorScheme = Colors.lightBlue;
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