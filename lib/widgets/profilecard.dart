import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lnwcash/utils/nip01.dart';
import 'package:lnwcash/utils/subscription.dart';
import 'package:nostr_core_dart/nostr.dart';

import 'package:lnwcash/widgets/avatar_image.dart';
import 'package:lnwcash/utils/relay.dart';

class ProfileCard extends StatefulWidget {
  const ProfileCard(this._pub, {super.key, this.name = ''});

  final String _pub;
  final String name;

  @override
  State<StatefulWidget> createState() => _ProfileCard();
}

class _ProfileCard extends State<ProfileCard> {
  String name = 'Name';
  String picture = 'assets/nopicAvatar.png';

  @override
  void initState() {
    super.initState();

    _loadPreference();
  }

  void _loadPreference() async {
    
    bool hasProfile = false;

    Subscription subscription = Subscription(
      filters: [Filter(
        kinds: [0],
        authors: [widget._pub],
        limit: 10,
      )], 
      onEvent: (event) {
        hasProfile = true;
        dynamic content = jsonDecode(event['content']);
        setState(() {
          name = content["name"];
          picture = content['picture'] ?? 'assets/nopicAvatar.png';
        });
      }
    );
    RelayPool.shared.subscribe(subscription, timeout: 3);
    await subscription.timeout.future;
    if (!hasProfile) {
      Event? event = await createEvent(
        kind: 0, 
        tags: [], 
        content: '{"name":"${widget.name}"}',
      );
      RelayPool.shared.send(event!.serialize());
      name = widget.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 15, right: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: 
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Welcome", style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w300),),
                const SizedBox(height: 3,),
                Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary, fontSize: 18,)),
              ],
            )
          ),
          AvatarImage(picture, 
            width: 40, height: 40, 
            radius: 10,
          )
        ],
      ),
    );
  }
}