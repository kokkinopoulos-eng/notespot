import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kPremiumProductId = 'notespot_premium_unlock';

class PremiumService extends ChangeNotifier {
  PremiumService._();
  static final instance = PremiumService._();

  bool _isPremium = false;
  String? _lastError;
  String _priceText = '€4.99';
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool get isPremium => _isPremium;
  String? get lastError => _lastError;
  String get priceText => _priceText;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('premium_unlocked') ?? false;
    debugPrint('PREMIUM_INIT prefs=$_isPremium debug=$kDebugMode');
    // DEBUG ONLY: auto-unlock Pro for local testing; release uses real purchase state
    if (kDebugMode) {
      _isPremium = true;
    }
    debugPrint('PREMIUM_FINAL isPremium=$_isPremium');
    notifyListeners();
    _fetchPrice();
    _sub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchases,
      onError: (e) {
        _lastError = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    debugPrint('PREMIUM_STREAM got ${purchases.length} purchases');
    for (final p in purchases) {
      debugPrint('PREMIUM_STREAM product=${p.productID} status=${p.status}');
      if (p.productID == kPremiumProductId) {
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          await _setPremium(true);
        } else if (p.status == PurchaseStatus.error) {
          _lastError = p.error?.message ?? 'Purchase error';
          notifyListeners();
        }
        if (p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
      }
    }
  }

  Future<void> _fetchPrice() async {
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) return;
      final response = await InAppPurchase.instance
          .queryProductDetails({kPremiumProductId});
      if (response.productDetails.isNotEmpty) {
        _priceText = response.productDetails.first.price;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// TEST ONLY - REMOVE BEFORE PRODUCTION
  Future<void> testTogglePremium() async {
    await _setPremium(!_isPremium);
  }

  Future<void> _setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('premium_unlocked', value);
    notifyListeners();
  }

  Future<bool> buy() async {
    _lastError = null;
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      _lastError = 'Store not available';
      notifyListeners();
      return false;
    }
    final response = await InAppPurchase.instance
        .queryProductDetails({kPremiumProductId});
    if (response.productDetails.isEmpty) {
      _lastError = 'Product not found';
      notifyListeners();
      return false;
    }
    final param = PurchaseParam(
      productDetails: response.productDetails.first,
    );
    try {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> restore() async {
    _lastError = null;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}