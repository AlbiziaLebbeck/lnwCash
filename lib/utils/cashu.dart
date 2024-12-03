import 'dart:async';
import 'dart:convert';

import 'package:bolt11_decoder/bolt11_decoder.dart';

import 'package:cashu_dart/business/mint/mint_helper.dart';
import 'package:cashu_dart/business/proof/keyset_helper.dart';
import 'package:cashu_dart/core/DHKE_helper.dart';
import 'package:cashu_dart/core/mint_actions.dart';
import 'package:cashu_dart/core/nuts/nut_00.dart';
import 'package:cashu_dart/core/nuts/token/proof.dart';
import 'package:cashu_dart/core/nuts/token/token_model.dart';
import 'package:cashu_dart/core/nuts/v1/nut.dart';
import 'package:cashu_dart/model/invoice.dart';
import 'package:cashu_dart/model/invoice_listener.dart';
import 'package:cashu_dart/model/keyset_info.dart';
import 'package:cashu_dart/model/mint_model.dart';
import 'package:cashu_dart/utils/network/response.dart';
import 'package:cashu_dart/utils/task_scheduler.dart';
import 'package:cashu_dart/utils/tools.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:lnwcash/utils/nip60.dart';

// ignore: depend_on_referenced_packages
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final _quotes = <IMint,MeltQuotePayload>{};
  Completer _quoteCreated = Completer();

  TaskScheduler? invoiceChecker;

  final List<String> _ecashToken = [];
  Completer _ecashCreated = Completer();

  late SharedPreferences prefs;

  Future<void> initialize(SharedPreferences prefs) async {
    this.prefs = prefs;
    final preInvoices = prefs.getStringList('invoice');
    if (preInvoices != null) {
      for (var invStr in preInvoices) {
        final invMap = Map.castFrom(jsonDecode(invStr));
        final inv = IInvoice(
          quote: invMap['quote'], 
          request: invMap['request'], 
          paid: invMap['paid'], 
          amount: invMap['amount'].toString(), 
          expiry: invMap['expiry'], 
          mintURL: invMap['mintURL']
        );
        _invoices.add(inv);
      }
    }

    invoiceChecker = TaskScheduler(task: _periodicCheck)..start();
    Future.delayed(const Duration(seconds: 10), () => invoiceChecker?.initComplete());
    if (_invoices.isNotEmpty) startHighFrequencyDetection();
  }

  Future<bool> addMint(String mintURL) async {
    final maxNutsVersion = await MintHelper.getMaxNutsVersion(mintURL);
    
    IMint mint = IMint(mintURL: mintURL, maxNutsVersion: maxNutsVersion);
    proofs[mint] = <Proof>[];
    mints.add(mint);

    if (maxNutsVersion <= 0) return false;
    
    final response = await mint.requestMintInfoAction(mintURL: mint.mintURL);
    if (!response.isSuccess) return false;
    mint.info = response.data;
    if (mint.name.isEmpty) mint.name = response.data.name;

    keysets[mint] = await KeysetHelper.fetchKeysetFromRemote(mint);
    
    return true;
  }

  Future<void> setupMints(dynamic defaultMint) async {
    for (var mintURL in defaultMint){
      await addMint(mintURL);
    }
  }

  IMint getMint(String mintURL) {
    return mints.where((mint) => mint.mintURL == mintURL).first;
  }

  Future<Receipt> getLastestInvoice() async {
    await _invoiceCreated.future;
    return _invoices.last;
  }

  Future<String> getLastestEcash() async {
    await _ecashCreated.future;
    return _ecashToken.last;
  }

  Future<Map<IMint,MeltQuotePayload>> getLastestQuote() async {
    await _quoteCreated.future;
    return _quotes;
  }

  Future<void> redeemEcash({
    required Token token,
    List<String> redeemPubkey = const [],
  }) async {
    for (var entry in token.entries) {
      
      if (mints.where((mint) => mint.mintURL == entry.mint).isEmpty) {
        bool added = await addMint(entry.mint);
        if (!added) continue;
        Nip60.shared.wallet['mints'] =  jsonEncode(mints.map((m) => m.mintURL).toList());
      }
      
      IMint mint = getMint(entry.mint);

      final currentProofs = [...proofs[mint]!];
      try {
        final newProofs = await swapProofs(
          mint: mint,
          swapProofs: [...currentProofs, ...entry.proofs],
        );

        _updateProofs(newProofs!, mint);
        await Nip60.shared.rollOverTokenEvent(currentProofs, newProofs, mint.mintURL);
        for (final proof in currentProofs) {
          proofs[mint]!.remove(proof);
        }
        notifyListenerForBalanceChanged(mint);
      } catch (_) {
        notifyError('Error: Mint is disconnected');
        return;
      }
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
    if (!response.isSuccess) {
      notifyError('Error: Mint is disconnected');
      return null;
    }

    if (_invoices.isEmpty) {
      startHighFrequencyDetection();
    }

    invoicePaid = Completer();
    _invoices.add(response.data);
    prefs.setStringList('invoice', _invoices.map((inv) => jsonEncode({
      'quote': inv.redemptionKey,
      'request': inv.request,
      'paid': false,
      'amount': amount,
      'expiry': inv.expiry,
      'mintURL': inv.mintURL,
    })).toList());
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
    final mint = getMint(invoice.mintURL);
    
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

    prefs.setStringList('invoice', _invoices.map((inv) => jsonEncode({
      'quote': inv.redemptionKey,
      'request': inv.request,
      'paid': false,
      'amount': amount,
      'expiry': inv.expiry,
      'mintURL': inv.mintURL,
    })).toList());

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
    final List<Proof> usedProofs = getProofsWithAmount(mint, amount);
    final sendingProofs = <Proof>[];
    final change = <Proof>[];

    if (usedProofs.totalAmount > amount) {
      late final List<Proof>? swapedProof;
      try {
        swapedProof = await swapProofs(
          mint: mint, 
          swapProofs: usedProofs,
          supportAmount: amount,
        ); 
      } catch (_) {
        notifyError('Error: Mint is disconnected');
        return;
      }

      for (final proof in swapedProof!) {
        if (sendingProofs.totalAmount < amount) {
          sendingProofs.add(proof);
        } else {
          change.add(proof);
        }
      }
    } else {
      sendingProofs.addAll([...usedProofs]);
    }

    if (change.isNotEmpty) {
      _updateProofs(change, mint);
    }

    await Nip60.shared.rollOverTokenEvent(usedProofs, change, mint.mintURL);
    for (final proof in usedProofs) {
      proofs[mint]!.remove(proof);
    }

    final ecash = Nut0.encodedToken(
      Token(
        entries: [TokenEntry(mint: mint.mintURL, proofs: sendingProofs)],
        unit: "sat",
      ),
    );
    _ecashToken.add(ecash);
    _ecashCreated.complete();

    notifyListenerForBalanceChanged(mint);
  }

  List<Proof> getProofsWithAmount(IMint mint, int amount) {
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
    }

    return proofsToSend;
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


  String? payingLightningInvoice(String invoice) {
    final req = _tryConstructRequestFromPr(invoice);
    if (req == null) return 'Lightning invoice or address is incorrect';

    final amount = (req.amount * Decimal.fromInt(100000000)).toBigInt();
    List<IMint> availableMint = [];
    for (final mint in Cashu.shared.mints) {
      if (BigInt.from(Cashu.shared.proofs[mint]!.totalAmount) >= amount) {
        availableMint.add(mint);
      }
    }
    if (availableMint.isEmpty) return "Mint balance is insufficient";
    
    requestQuote(availableMint, req);
    return null;
  }

  Future<void> requestQuote(List<IMint> mints, Bolt11PaymentRequest req) async {
    _quoteCreated = Completer();
    _quotes.clear();
    for (final mint in mints) {
      final quoteResponse = await Nut5.requestMeltQuote(
        mintURL: mint.mintURL,
        request: req.paymentRequest,
      );
      if (quoteResponse.isSuccess && quoteResponse.data.quote.isNotEmpty) {
        _quotes[mint] = quoteResponse.data;
      } else {
        notifyError('Error: Mint is disconnected');
        return;
      }
    }

    _quoteCreated.complete();
  }

  payQuote(IMint mint, MeltQuotePayload quote) async {
    final ( blindedMessages, secrets, rs, _ ) = DHKEHelper.createBlankOutputs(
      keysetId: keysets[mint]!.firstOrNull!.id,
      amount: int.parse(quote.fee),
    );

    int amount = int.parse(quote.amount) + int.parse(quote.fee);
    final List<Proof> usedProofs = getProofsWithAmount(mint, amount);
    final sendingProofs = <Proof>[];
    final change = <Proof>[];

    if (usedProofs.totalAmount > amount) {
      try {
        final swapedProof = await swapProofs(
          mint: mint, 
          swapProofs: usedProofs,
          supportAmount: amount,
        );  
        for (final proof in swapedProof!) {
          if (sendingProofs.totalAmount < amount) {
            sendingProofs.add(proof);
          } else {
            change.add(proof);
          }
        }
      } catch(_) {
        notifyError('Error: Mint is disconnected');
        return;
      }
    } else {
      sendingProofs.addAll([...usedProofs]);
    }

    final meltResponse = await Nut8.payingTheQuote(
      mintURL: mint.mintURL, 
      quote: quote.quote,
      inputs: sendingProofs,
      outputs: blindedMessages,
    );

    if (!meltResponse.isSuccess) {
      if (change.isNotEmpty) {
        change.addAll(sendingProofs);
        _updateProofs(change, mint);

        await Nip60.shared.rollOverTokenEvent(usedProofs, change, mint.mintURL);
        for (final proof in usedProofs) {
          proofs[mint]!.remove(proof);
        }
      }
      notifyError(meltResponse.errorMsg);
      return;
    }

    final ( _, _, feeChange ) = meltResponse.data;
    final newProofs = constructProofs(mint, feeChange, secrets, rs);
    for (final proof in newProofs) {
      if (int.parse(proof.amount) > 0) {
        change.add(proof);
        amount -= int.parse(proof.amount);
      }
    }

    if (change.isNotEmpty) {
      _updateProofs(change, mint);
    }

    await Nip60.shared.rollOverTokenEvent(usedProofs, change, mint.mintURL);
    for (final proof in usedProofs) {
      proofs[mint]!.remove(proof);
    }
    
    notifyListenerForPaymentCompleted(amount.toString());
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

  static Bolt11PaymentRequest? _tryConstructRequestFromPr(String pr) {
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

  void notifyListenerForPaymentCompleted(String paymentKey) {
    for (var e in _listeners) {
      e.handlePaymentCompleted(paymentKey);
    }
  }

  void notifyError(String errorMsg) {
    for (var e in _listeners) {
      e.handleError(errorMsg);
    }
  }
}