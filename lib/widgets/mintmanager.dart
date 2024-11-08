import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lnwcash/main.dart';
import 'package:lnwcash/utils/cashu.dart';
import 'package:loader_overlay/loader_overlay.dart';

Future<void> mintManager(context) async {
  return showModalBottomSheet(context: context, 
    builder: (context) => const MintManager(),
  );
}

class MintManager extends StatefulWidget {
  const MintManager({super.key});

  @override
  State<MintManager> createState() => _MintManager();
}

class _MintManager extends State<MintManager>{
  
  final _mintKey = GlobalKey<FormState>();
  String? addingMint;

  final TextEditingController _mintController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _mintController.text = "https://";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Column(
        children: [
          Text('Configure Cashu Mints', 
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 24, 
              fontWeight: FontWeight.bold, 
              fontFamily: ''
            ),
          ),
          const SizedBox(height: 25),
          Form(
            key: _mintKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _mintController,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25)
                    ),
                    labelText: 'Add new mint',
                    suffixIcon: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 5),
                      child: IconButton(
                        onPressed: () async {
                          final mintUrl = await Clipboard.getData('text/plain');
                          if (mintUrl != null) {
                            _mintController.text = mintUrl.text ?? '';
                          }
                        },
                        icon: const Icon(Icons.paste),
                      ),
                    ),
                  ),
                  validator: (value) { 
                    if (value == null || value.isEmpty || value == 'https://') {
                      _mintController.text = "https://";
                      return "Mint url is required";
                    }

                    if (!value.startsWith('https://')) {
                      _mintController.text = "https://";
                      return "Mint url is invalid";
                    }

                    if (Cashu.shared.mints.where((e) => e.mintURL == value).isNotEmpty) {
                      return "This mint is already added";
                    }

                    addingMint = value;

                    return null;
                  },
                ),
                const SizedBox(height: 10,),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  onPressed: () async {
                    if(_mintKey.currentState!.validate()) {
                      if (addingMint != null) {
                        context.loaderOverlay.show();
                        bool isAdded = await Cashu.shared.addMint(addingMint!);
                        // ignore: use_build_context_synchronously
                        context.loaderOverlay.hide();
                        if (isAdded) {
                          setState(() {});
                        } else {
                          // ignore: use_build_context_synchronously
                          showDialog(context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Error!'),
                              content: const Text('This mint is not found.'),
                              actions: [
                                TextButton(onPressed: () {Navigator.of(context).pop();}, child: const Text('OK')),
                              ],
                            )
                          );
                        }
                        addingMint = null;
                      }
                      _mintKey.currentState!.reset();
                    }
                  },
                  child: const Text('Add', style: TextStyle(fontSize: 16)),
                )
              ],
            )
          ),
          const SizedBox(height: 15,),
          SizedBox(
            height: MediaQuery.of(context).size.height/2 - 235,
            child: ListView(
              scrollDirection: Axis.vertical,
              children: List.generate(Cashu.shared.mints.length, 
                (index) => Container(
                  margin: const EdgeInsets.only(bottom: 8, right: 3),
                  padding: const EdgeInsets.only(top: 4, bottom: 4, left: 32, right: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black87.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 1,
                        offset: const Offset(1, 1), // changes position of shadow
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(Cashu.shared.mints[index].mintURL, 
                            style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.secondary
                          ),
                        )
                      ),
                      const SizedBox(width: 5),
                      IconButton(
                        onPressed: () {
                          showDialog(context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Warning!!'),
                              content: const Text('Are you sure that you want to delete this mint?'),
                              actions: [
                                FilledButton(onPressed: () {
                                  setState(() {
                                    Cashu.shared.mints.removeAt(index);
                                  });
                                  Navigator.of(context).pop();
                                }, child: const Text('Yes')),
                                TextButton(onPressed: () {Navigator.of(context).pop();}, child: const Text('No')),
                              ],
                            )
                          );
                        }, 
                        icon: Icon(Icons.delete_forever, size: 32, color: Theme.of(context).colorScheme.error,),
                      )
                    ],
                  )
                ),
              )
            )
          ),
          const SizedBox(height: 15),
          TextButton(child: const Text("Done", style: TextStyle(fontSize: 16)),
            onPressed: () async {
              Navigator.of(context).pop();
            }
          ),
        ]
      ),
    );
  }
}