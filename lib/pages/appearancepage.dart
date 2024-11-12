import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:provider/provider.dart';

import '../main.dart';

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, ThemeNotifier themeNotifier, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Appearance'), 
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: SettingsGroup(
              title: 'Theme',
              children: <Widget>[
                  SwitchSettingsTile(
                    leading: const Icon(Icons.dark_mode),
                    settingKey: 'key-dark-mode',
                    title: 'Dark Mode',
                    enabledLabel: 'Enabled',
                    disabledLabel: 'Disabled',
                    activeColor: Theme.of(context).colorScheme.onPrimary,
                    onChange: (value) {
                      themeNotifier.isDark = value;
                    },
                  ),
                  ColorPickerSettingsTile(
                    settingKey: 'key-color-picker',
                    title: 'Color',
                    defaultValue: themeNotifier.colorScheme,
                    onChange: (value) {
                      themeNotifier.colorScheme = value;
                    },
                  )
                ],
            ),
          ),
        );
      }
    );
  }
}