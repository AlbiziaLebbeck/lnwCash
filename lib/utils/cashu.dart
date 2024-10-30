import 'dart:async';

import 'package:bolt11_decoder/bolt11_decoder.dart';

import 'package:cashu_dart/business/mint/mint_helper.dart';
import 'package:cashu_dart/core/DHKE_helper.dart';
import 'package:cashu_dart/core/mint_actions.dart';
import 'package:cashu_dart/core/nuts/nut_00.dart';
import 'package:cashu_dart/model/invoice.dart';
import 'package:cashu_dart/model/invoice_listener.dart';
import 'package:cashu_dart/model/keyset_info.dart';
import 'package:cashu_dart/model/mint_model.dart';
import 'package:cashu_dart/utils/network/response.dart';
import 'package:cashu_dart/utils/task_scheduler.dart';
import 'package:cashu_dart/utils/tools.dart';
import 'package:flutter/material.dart';
import 'package:lnwcash/utils/nip60.dart';
// ignore: depend_on_referenced_packages
import 'package:pointycastle/export.dart';

class Cashu {
  static final Cashu shared = Cashu._internal();
  Cashu._internal();

  final List<IMint> mints = [];
  final Map<IMint,List<KeysetInfo>> keysets = {};
  final Map<IMint,List<Proof>> proofs = {};

  final _invoices = <Receipt>[];
  final _pendingInvoices = <Receipt>{};
  final List<CashuListener> _listeners = [];
  Completer _invoiceCreated = Completer();
  Completer invoicePaid = Completer();

  TaskScheduler? invoiceChecker;

  final List<String> _ecashToken = [];
  Completer _ecashCreated = Completer();

  Future<void> initialize() async {
    invoiceChecker = TaskScheduler(task: _periodicCheck)..start();
    Future.delayed(const Duration(seconds: 10), () => invoiceChecker?.initComplete());
  }

  Future<bool> addMint(String mintURL) async {
    final maxNutsVersion = await MintHelper.getMaxNutsVersion(mintURL);
    
    IMint mint = IMint(mintURL: mintURL, maxNutsVersion: maxNutsVersion);
    final response = await mint.requestMintInfoAction(mintURL: mint.mintURL);
    if (!response.isSuccess) return false;
    mint.info = response.data;
    if (mint.name.isEmpty)  mint.name = response.data.name;
    
    mints.add(mint);
    keysets[mint] = await MintHelper.fetchKeysetFromRemote(mint);
    proofs[mint] = <Proof>[];
    return true;
  }

  Future<void> setupMints(dynamic defaultMint) async {
    for (var mintURL in defaultMint){
      await addMint(mintURL);
    }
  }

  IMint getMint(String mintURL) {
    return mints.firstWhere((mint) => mint.mintURL == mintURL);
  }

  Future<Receipt> getLastestInvoice() async {
    await _invoiceCreated.future;
    return _invoices.last;
  }

  Future<String> getLastestEcash() async {
    await _ecashCreated.future;
    return _ecashToken.last;
  }

  Future<void> redeemEcash({
    required Token token,
    List<String> redeemPubkey = const [],
  }) async {
    for (var entry in token.entries) {
      final mint = Cashu.shared.getMint(entry.mint);

      final redeemProofs = [...entry.proofs];
      final newProofs = await swapProofs(
        mint: mint,
        swapProofs: redeemProofs,
      );
      _updateProofs(newProofs!, mint);
      final evtId = await Nip60.shared.createTokenEvent(newProofs, mint.mintURL);
      await Nip60.shared.createHistoryEvent([evtId], []);
      notifyListenerForBalanceChanged(mint);
    }
  }

  Future<List<Proof>?> swapProofs({
    required IMint mint,
    required List<Proof> swapProofs,
    int? supportAmount,
  }) async {
    final keysetInfo = keysets[mint]!.firstOrNull;
    final proofsTotalAmount = swapProofs.totalAmount;
    final amount = supportAmount ?? proofsTotalAmount;

    List<BlindedMessage> blindedMessages = [];
    List<String> secrets = [];
    List<BigInt> rs = [];
    final ( $1, $2, $3, _ ) = DHKEHelper.createBlindedMessages(
      keysetId: keysetInfo!.id,
      amount: amount,
    );
    blindedMessages.addAll($1);
    secrets.addAll($2);
    rs.addAll($3);
    
    if (proofsTotalAmount - amount > 0) {
      final ( $1, $2, $3, _ ) = DHKEHelper.createBlindedMessages(
        keysetId: keysetInfo.id,
        amount: proofsTotalAmount - amount,
      );
      blindedMessages.addAll($1);
      secrets.addAll($2);
      rs.addAll($3);
    }

    final response = await mint.swapAction(
      mintURL: mint.mintURL,
      proofs: swapProofs,
      outputs: blindedMessages,
    );

    if (response.isSuccess) {
      return constructProofs(mint, response.data, secrets, rs);
    }

    return null;
  }

  List<int>? _findOneSubsetWithSum(List<int> nums, int target) {
    List<List<int>?> dp = List.filled(target + 1, null);
    dp[0] = [];

    for (int i = 0; i < nums.length; i++) {
      int num = nums[i];

      for (int t = target; t >= num; t--) {
        if (dp[t - num] != null) {
          dp[t] = List.from(dp[t - num]!)..add(i);

          if (t == target) {
            return dp[target];
          }
        }
      }
    }
    return null;
  }

  Future<Receipt?> createLightningInvoice({
    required IMint mint,
    required int amount,
    required BuildContext context,
  }) async {
    _invoiceCreated = Completer();
    final response = await mint.createQuoteAction(
      mintURL: mint.mintURL,
      amount: amount,
    );
    if (!response.isSuccess) return null;

    if (_invoices.isEmpty) {
      startHighFrequencyDetection();
    }

    invoicePaid = Completer();
    _invoices.add(response.data);
    checkInvoice(response.data);
    _invoiceCreated.complete();
    return response.data;
  }


  Future _periodicCheck() async {
    final invoices = [..._invoices].reversed;
    for (var invoice in invoices) {
      checkInvoice(invoice);
    }
  }

  Future<void> checkInvoice(Receipt invoice) async {
    if (_pendingInvoices.contains(invoice)) return;
    _pendingInvoices.add(invoice);

    final amount = int.tryParse(invoice.amount)!;
    final mint = Cashu.shared.getMint(invoice.mintURL);
    
    final keysetInfo = keysets[mint]!.firstOrNull;
 
    final ( blindedMessages, secrets, rs, _ ) = DHKEHelper.createBlindedMessages(
      keysetId: keysetInfo!.id,
      amount: amount,
    );

    final response = await mint.requestTokensAction(
      mintURL: mint.mintURL,
      quote: invoice.redemptionKey,
      blindedMessages: blindedMessages,
    );
    if (response.isSuccess) {
      if (response.data.isNotEmpty) {
        invoicePaid.complete();
        final newProofs = constructProofs(mint, response.data, secrets, rs);
        _updateProofs(newProofs, mint);
        final evtId = await Nip60.shared.createTokenEvent(newProofs, mint.mintURL);
        await Nip60.shared.createHistoryEvent([evtId], []);
        notifyListenerForPaidSuccess(invoice);
      }
      _invoices.remove(invoice);
    } else {
      if (response.errorMsg.contains('quote already issued')) {
        _invoices.remove(invoice);
      } else if (response.code == ResponseCode.invoiceNotPaidError && invoice.isExpired) {
        _invoices.remove(invoice);
      }
    }

    _pendingInvoices.remove(invoice);

    if (_invoices.isEmpty) {
      stopHighFrequencyDetection();
    }
  }

  void startHighFrequencyDetection() {
    invoiceChecker?.enableFixedInterval(const Duration(seconds: 5));
  }

  void stopHighFrequencyDetection() {
    invoiceChecker?.disableFixedInterval();
  }

  Future<void> sendEcash(IMint mint, int amount) async {
    _ecashCreated = Completer();
    bool swap = false;
    final List<Proof> proofsToSend = [];
    List<int>? proofIdx = _findOneSubsetWithSum(proofs[mint]!.map((p) => p.amountNum).toList(), amount);
    if (proofIdx != null) {
      for (var idx in proofIdx) {
        proofsToSend.add(proofs[mint]![idx]);
      }
    } else {
      for (var proof in proofs[mint]!) {
        if (proofsToSend.totalAmount >= amount) break;
        proofsToSend.add(proof);
      }
      if (proofsToSend.totalAmount > amount) swap = true;
    }

    if (swap) {
      final swapedProof = await swapProofs(
        mint: mint, 
        swapProofs: proofsToSend,
        supportAmount: amount,
      );
      final swapedToSend = <Proof>[];
      final change = <Proof>[];  
      for (final proof in swapedProof!) {
        if (swapedToSend.totalAmount < amount) {
          swapedToSend.add(proof);
        } else {
          change.add(proof);
        }
      }
      _updateProofs(change, mint);
      
      final ecash = Nut0.encodedToken(
        Token(
          entries: [TokenEntry(mint: mint.mintURL, proofs: swapedToSend)],
          unit: "sat",
        ),
      );
      _ecashToken.add(ecash);
      _ecashCreated.complete();
      
      final evtId = await Nip60.shared.createTokenEvent(change, mint.mintURL);

      await Nip60.shared.rollOverTokenEvent(proofsToSend, mint.mintURL, [evtId]);
      for (final proof in proofsToSend) {
        proofs[mint]!.remove(proof);
      }
    } else {
      final ecash = Nut0.encodedToken(
        Token(
          entries: [TokenEntry(mint: mint.mintURL, proofs: proofsToSend)],
          unit: "sat",
        ),
      );
      _ecashToken.add(ecash);
      _ecashCreated.complete();

      await Nip60.shared.rollOverTokenEvent(proofsToSend, mint.mintURL, []);
      for (final proof in proofsToSend) {
        proofs[mint]!.remove(proof);
      }
    }
    notifyListenerForBalanceChanged(mint);
  }

  Future<void> payingLightningInvoice(Bolt11PaymentRequest pr) async {

  }

  List<Proof> constructProofs(
    IMint mint,
    List<BlindedSignature> signatures,
    List<String> secrets,
    List<BigInt> rs,
  ) {
    List<Proof> constructedProofs = [];

    for (int i = 0; i < signatures.length; i++) {
      final promise = signatures[i];
      final secret = secrets[i];
      final keysetId = promise.id;
      final keys = keysets[mint]!.where((k) => k.id == keysetId).firstOrNull!.keyset;

      final r = rs[i];
      final K = keys[promise.amount];
      
      final dleq = promise.dleq?.map((key, value) => MapEntry(key.toString(), value));
      if (dleq != null && dleq.isNotEmpty) {
        dleq['r'] = r.toString();
      }

      final C = unblindingSignature(promise.C_, r, K!);
      final unblindingProof = Proof(
        id: promise.id,
        amount: promise.amount,
        secret: secret,
        C: ecPointToHex(C!),
        dleq: dleq,
      );
      constructedProofs.add(unblindingProof);
    }
    return constructedProofs;
  }

  void _updateProofs(List<Proof> updateProofs, IMint mint) {
    for (var updateProof in updateProofs) {
      if (proofs[mint]!.where((proof) => proof.secret == updateProof.secret).isEmpty) {
        proofs[mint]?.add(updateProof);
      }
    }
  }

  // String proofSerializer() {
  //   Map<String,List<Map<String,dynamic>>> proofsToJson = {};
  //   proofs.forEach((mint, prfs) {
  //     List<Map<String,dynamic>> prfsToJson = [];
  //     for (var prf in prfs) {
  //       Map<String,dynamic> strPrf = {
  //         'id': prf.id,
  //         'amount': prf.amount,
  //         'secret': prf.secret,
  //         'C': prf.C,
  //       };
  //       // if(prf.dleq != null && prf.dleq!.isNotEmpty) {
  //       //   prfToJson = '{\"id":\"${prf.id}\",\"amount\":\"${prf.amount},\"secret\":\"${prf.secret}\",\"C\",\"${prf.C}\",\"dleq":{"e":"${prf.dleq!['e']}","s":"${prf.dleq!['s']}","r":"${prf.dleq!['r']}"}}';
  //       // }
  //       prfsToJson.add(strPrf);
  //     }
  //     proofsToJson[mint.mintURL] =  prfsToJson;
  //   });
  //   return jsonEncode(proofsToJson);
  // }

  // Future<void> proofDeserializer (String jsonProofs) async {
  //   Map<String,dynamic> getProofs = Map.castFrom(jsonDecode(jsonProofs));
  //   List<String> mintStr = mints.map((m) => m.mintURL).toList(); 
  //    for (var mintUrl in getProofs.keys) {
  //     if (!mintStr.contains(mintUrl)) {
  //       bool ok = await addMint(mintUrl);
  //       if (!ok) continue;
  //     }

  //     IMint mint = getMint(mintUrl);

  //     for (var prf in getProofs[mintUrl]!) {
  //       proofs[mint]!.add(Proof(
  //         id: prf['id']!, 
  //         amount: prf['amount']!, 
  //         secret: prf['secret']!, 
  //         C: prf['C']!,
  //       ));
  //     }
  //    }
  // }

  static String ecPointToHex(ECPoint point, [bool compressed = true]) {
    return point.getEncoded(compressed).map(
      (byte) => byte.toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static ECPoint pointFromHex(String hex) {
    final handler = ECCurve_secp256k1();
    return handler.curve.decodePoint(hex.hexToBytes())!;
  }

  static ECPoint? unblindingSignature(String cHex, BigInt r, String kHex) {
    final C_ = pointFromHex(cHex);
    final rK = pointFromHex(kHex) * r;
    if (rK == null) return null;
    return C_ - rK;
  }

  static const _lnPrefix = [
    'lightning:',
    'lightning=',
    'lightning://',
    'lnurlp://',
    'lnurlp=',
    'lnurlp:',
    'lnurl:',
    'lnurl=',
    'lnurl://',
  ];

  static Bolt11PaymentRequest? tryConstructRequestFromPr(String pr) {
    pr = pr.trim();
    for (var prefix in _lnPrefix) {
      if (pr.startsWith(prefix)) {
        pr = pr.substring(prefix.length).trim();
        break; // Important to exit the loop once a match is found
      }
    }
    if (pr.isEmpty) return null;
    try {
      final req = Bolt11PaymentRequest(pr);
      for (var tag in req.tags) {
        debugPrint('[Cashu - invoice decode]${tag.type}: ${tag.data}');
      }
      return req;
    } catch (_) {
      return null;
    }
  }


  void addListener(CashuListener listener) {
    _listeners.add(listener);
  }

  void removeListener(CashuListener listener) {
    _listeners.remove(listener);
  }

  void notifyListenerForPaidSuccess(Receipt receipt) {
    for (var e in _listeners) {
      e.handleInvoicePaid(receipt);
    }
  }

  void notifyListenerForBalanceChanged(IMint mint) {
    for (var e in _listeners) {
      e.handleBalanceChanged(mint);
    }
  }
}