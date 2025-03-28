import 'dart:convert';

import 'package:encrypt_shared_preferences/provider.dart';
import 'package:flutter/material.dart';
import 'package:lnwcash/pages/mintpage.dart';
import 'package:lnwcash/utils/relay.dart';
import 'package:nostr_core_dart/nostr.dart';

import 'package:lnwcash/pages/loginpage.dart';
import 'package:lnwcash/pages/nostrkeyspage.dart';
import 'package:lnwcash/pages/appearancepage.dart';

import 'package:lnwcash/widgets/avatar_image.dart';
import 'package:lnwcash/pages/relaypage.dart';

import 'package:lnwcash/utils/cashu.dart';
import 'package:lnwcash/utils/nip60.dart';

Drawer getDrawer(BuildContext context, {
  required EncryptedSharedPreferences prefs,
  required Future<void> Function({bool isInit}) fetchWallet,
  required Future<void> Function({bool isInit}) loadProofs,
  required String version,
}) {
  final npub = Nip19.encodePubkey(prefs.getString('pub') ?? '').toString();
  final nsec = Nip19.encodePrivkey(prefs.getString('priv') ?? '').toString();

  final profile = jsonDecode(prefs.getString('profile') ?? '{}');
  final name = profile['display_name'] ?? 'Name';
  final nip05 = profile['nip05'] ?? '';
  final picture = profile['picture'] ?? 'images/nopicAvatar.png';

  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        UserAccountsDrawerHeader(
          currentAccountPicture: AvatarImage(picture), 
          accountName: Row(
            children: [
              Text(name, 
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w600
                ),
              ),
              // const SizedBox(width: 10,),
              // const Icon(Icons.qr_code),
            ],
          ),
          accountEmail: Text(nip05, style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 14),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
          child: const Text("Cashu", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),),
        ),
        ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: const Text('Wallets'),
          onTap: () {
            Navigator.of(context).pop();
            fetchWallet(isInit: false);
          },
        ),
        ListTile(
          leading: const Icon(Icons.account_balance),
          title: const Text('Mints'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.push(context,
              MaterialPageRoute(builder: (context) => const MintPage()),
            ).then((_) {
              Nip60.shared.wallet['mints'] =  jsonEncode(Cashu.shared.mints.map((m) => m.mintURL).toList());
              Nip60.shared.updateWallet();
              prefs.setString('wallet', jsonEncode(Nip60.shared.wallet));
            });
          },
        ),
        const Divider(),
        Container(
          padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
          child: const Text("Nostr", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),),
        ),
        ListTile(
          leading: const Icon(Icons.dns),
          title: const Text('Relays'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.push(context,
              MaterialPageRoute(builder: (context) => RelayPage(prefs: prefs)),
            ).then((_) {
              Nip60.shared.updateWallet();
            });
          },
        ),
        nsec != 'nsec1jlrw3c' ? ListTile(
          leading: const Icon(Icons.key),
          title: const Text('Nostr Keys'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.push(context,
              MaterialPageRoute(builder: (context) => NostrKeyPage(nsec: nsec, npub: npub,)),
            );
          },
        ) : const SizedBox(),
        const Divider(),
        Container(
          padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
          child: const Text("App settings", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),),
        ),
        ListTile(
          leading: const Icon(Icons.bubble_chart),
          title: const Text('Appearance'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.push(context,
              MaterialPageRoute(builder: (context) => const AppearancePage()),
            );
          },
        ),
        const Divider(),
        Container(
          padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
          child: const Text("Account", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () {
            showDialog(context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Please ensure your nsec is saved before you logout or you will lose access to this account again.'),
                actions: [
                  TextButton(onPressed: () {Navigator.of(context).pop();}, child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () async {
                      prefs.clear();
                      Nip60.shared.wallet.clear();
                      Nip60.shared.proofEvents.clear();
                      Nip60.shared.eventProofs.clear();
                      Nip60.shared.histories.clear();
                      Cashu.shared.mints.clear();
                      Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                      RelayPool.shared.close();
                    }, 
                    child: const Text('Logout')
                  ),
                ],
              )
            );
          },
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
          child: Text('lnwCash v$version-beta', style: const TextStyle(fontSize: 14)),
        ),
      ],
    ),
  );
}