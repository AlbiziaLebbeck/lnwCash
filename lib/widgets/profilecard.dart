import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lnwcash/utils/nip01.dart';
import 'package:lnwcash/utils/subscription.dart';
import 'package:nostr_core_dart/nostr.dart';

import 'package:lnwcash/widgets/avatar_image.dart';
import 'package:lnwcash/utils/relay.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileCard extends StatefulWidget {
  const ProfileCard({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<StatefulWidget> createState() => _ProfileCard();
}

class _ProfileCard extends State<ProfileCard> {

  String pub = '';
  String name = 'Name';
  String picture = 'images/nopicAvatar.png';

  @override
  void initState() {
    super.initState();

    pub = widget.prefs.getString('pub') ?? '';
    final profile = jsonDecode(widget.prefs.getString('profile') ?? '{}');
    if (profile.isNotEmpty) {
      name = profile['display_name'] ?? profile['name'];
      picture = profile['picture'] ?? 'images/nopicAvatar.png';
    } 

    _loadPreference();
  }

  void _loadPreference() async {
    Subscription subscription = Subscription(
      filters: [Filter(
        kinds: [0],
        authors: [pub],
        limit: 10,
      )], 
      onEvent: (event) {
        dynamic content = jsonDecode(event['content']);
        setState(() {
          name = content["display_name"] ?? content["name"];
          picture = content['picture'] ?? 'images/nopicAvatar.png';
        });
        widget.prefs.setString('profile', event['content']);
      }
    );
    RelayPool.shared.subscribe(subscription, timeout: 3);
    await subscription.timeout.future;
    RelayPool.shared.unsubscribe(subscription.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 15, right: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Scaffold.of(context).openDrawer();
            },
            child: AvatarImage(picture, 
              width: 45, height: 45, 
              radius: 15,
            )
          ),
          const SizedBox(width: 10,),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome", style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w300),),
              const SizedBox(height: 1,),
              Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary, fontSize: 16,)),
            ],
          ),
        ],
      ),
    );
  }
}