import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lnwcash/widgets/avatar_image.dart';
import 'package:lnwcash/widgets/mintmanager.dart';
import 'package:lnwcash/widgets/relaymanager.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:shared_preferences/shared_preferences.dart';

Drawer getDrawer(BuildContext context, {
  required SharedPreferences prefs,
  required Future<void> Function({bool isInit}) fetchWalletEvent,
}) {
  final npub = Nip19.encodePubkey(prefs.getString('pub') ?? '').toString();
  final nsec = Nip19.encodePrivkey(prefs.getString('priv') ?? '').toString();

  final profile = jsonDecode(prefs.getString('profile') ?? '{}');
  final name = profile['display_name'] ?? 'Name';
  final nip05 = profile['nip05'] ?? '';
  final picture = profile['picture'] ?? 'assets/nopicAvatar.png';

  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        UserAccountsDrawerHeader(
          currentAccountPicture: AvatarImage(picture), 
          accountName: Row(
            children: [
              Text(name, 
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10,),
              Icon(Icons.qr_code, color: Theme.of(context).colorScheme.inversePrimary,),
            ],
          ),
          accountEmail: Text(nip05, style: const TextStyle(fontSize: 14),),
        ),
        Container(
          padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
          child: const Text("Cashu", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),),
        ),
        ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: const Text('Wallets'),
          onTap: () {
            fetchWalletEvent(isInit: false);
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.account_balance),
          title: const Text('Mints'),
          onTap: () {
            Navigator.of(context).pop();
            mintManager(context);
          },
        ),
        const SizedBox(height: 5),
        const Divider(),
        Container(
          padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
          child: const Text("Nostr", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),),
        ),
        ListTile(
          leading: const Icon(Icons.dns),
          title: const Text('Relays'),
          onTap: () {
            // Update the state of the app.
            Navigator.of(context).pop();
            relayManager(context);
          },
        ),
        nsec != 'nsec1jlrw3c' ? Column(children: [ 
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('Nostr Keys'),
            onTap: () {
              // Update the state of the app.
              // ...
            },
          ),]
        ) : const SizedBox(),
        const SizedBox(height: 5),
        const Divider(),
        Container(
          padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
          child: const Text("App settings", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),),
        ),
        ListTile(
          leading: const Icon(Icons.bubble_chart),
          title: const Text('Appearance'),
          onTap: () {
            // Update the state of the app.
            // ...
          },
        ),
        const SizedBox(height: 5),
        const Divider(),
        Container(
          padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
          child: const Text("Account", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () {
            // Update the state of the app.
            // ...
          },
        ),
        const SizedBox(height: 5),
        const Divider(),
        const SizedBox(height: 10),
      ],
    ),
  );
}