import 'dart:async';
import 'dart:convert';

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
  Completer invoiceCreated = Completer();
  Completer invoicePaid = Completer();

  TaskScheduler? invoiceChecker;

  Future<void> initialize() async {
    invoiceChecker = TaskScheduler(task: _periodicCheck)..start();
    Future.delayed(const Duration(seconds: 10), () => invoiceChecker?.initComplete());
  }

  Future<void> setupMints(dynamic defaultMint) async {
    for (var mintData in defaultMint){
      final maxNutsVersion = await MintHelper.getMaxNutsVersion(mintData['url']);
      IMint mint = IMint(mintURL: mintData['url'], maxNutsVersion: maxNutsVersion);
      await MintHelper.updateMintInfoFromRemote(mint);
      mints.add(mint);

      keysets[mint] = await MintHelper.fetchKeysetFromRemote(mint);
      proofs[mint] = <Proof>[];
    }
  }

  IMint getMint(String mintURL) {
    return mints.firstWhere((mint) => mint.mintURL == mintURL);
  }

  Future<Receipt> getLastestInvoice() async {
    await invoiceCreated.future;
    return _invoices.last;
  }

  Future<void> redeemEcash({
    required Token token,
    List<String> redeemPubkey = const [],
  }) async {
    for (var entry in token.entries) {
      final mint = Cashu.shared.getMint(entry.mint);

      final redeemProofs = [...entry.proofs];
      swapProofs(
        mint: mint,
        swapProofs: redeemProofs,
      );
    }
  }

  Future<void> swapProofs({
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
      constructProofs(mint, response.data, secrets, rs);
      notifyListenerForBalanceChanged(mint);
    }
  }

  Future<Receipt?> createLightningInvoice({
    required IMint mint,
    required int amount,
    required BuildContext context,
  }) async {
    invoiceCreated = Completer();
    final response = await mint.createQuoteAction(
      mintURL: mint.mintURL,
      amount: amount,
    );
    if (!response.isSuccess) return null;
    invoicePaid = Completer();
    _invoices.add(response.data);
    checkInvoice(response.data);
    invoiceCreated.complete();
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
        constructProofs(mint, response.data, secrets, rs);
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
  }

  constructProofs(
    IMint mint,
    List<BlindedSignature> signatures,
    List<String> secrets,
    List<BigInt> rs,
  ) {
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
      if (proofs[mint]!.where((proof) => proof.secret == unblindingProof.secret).isEmpty) {
        proofs[mint]?.add(unblindingProof);
      }
    }
  }

  String proofSerializer() {
    Map<String,String> proofsToJson = {};
    proofs.forEach((mint, prfs) {
      List<String> prfsToJson = [];
      for (var prf in prfs) {
        String prfToJson;
        if(prf.dleq != null && prf.dleq!.isNotEmpty) {
          prfToJson = '{"id":"${prf.id}","amount":"${prf.amount},"secret":"${prf.secret}","C","${prf.C}","dleq":{"e":"${prf.dleq!['e']}","s":"${prf.dleq!['s']}","r":"${prf.dleq!['r']}"}}';
        } else {
          prfToJson = '{"id":"${prf.id}","amount":"${prf.amount},"secret":"${prf.secret}","C","${prf.C}"}';
        }
        prfsToJson.add(prfToJson);
      }
      proofsToJson[mint.mintURL] =  jsonEncode(prfsToJson);
    });
    return jsonEncode(proofsToJson);
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