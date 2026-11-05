import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// The offerId of the intro/discount offer on Google Play (Android only).
const String kWeeklyOfferId = 'weeklyoffer';

final String weeklyProduct = Platform.isAndroid ? 'weekly' : 'sophia_weekly';
final String monthlyProduct = Platform.isAndroid ? 'monthly' : 'sophia_monthly';

final Set<String> kAllProductIds = {weeklyProduct, monthlyProduct};

class PlanInfo {
  final ProductDetails product;

  /// The regular (base) price, e.g. "₹249/week"
  final String regularPrice;

  /// Android only: discounted intro offer price, e.g. "₹49" — null if none.
  final String? offerPrice;

  /// Android only: offer token for the intro offer — null if none.
  final String? offerToken;

  /// Android only: base plan token (no-offer flow).
  final String? baseOfferToken;

  const PlanInfo({
    required this.product,
    required this.regularPrice,
    this.offerPrice,
    this.offerToken,
    this.baseOfferToken,
  });

  /// True when an Android intro offer is present and should be displayed.
  bool get hasOffer => offerPrice != null && offerToken != null;
}

class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  final StreamController<List<PurchaseDetails>> _purchaseController =
      StreamController<List<PurchaseDetails>>.broadcast();

  StreamSubscription<List<PurchaseDetails>>? _iapSubscription;

  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseController.stream;

  PlanInfo? _weeklyPlanInfo;
  PlanInfo? get weeklyPlanInfo => _weeklyPlanInfo;

  PlanInfo? _monthlyPlanInfo;
  PlanInfo? get monthlyPlanInfo => _monthlyPlanInfo;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _iapSubscription = _iap.purchaseStream.listen((purchases) {
      _handlePurchaseUpdates(purchases);
      _purchaseController.add(purchases);
    }, onError: (e) => debugPrint('[IapService] Stream error: $e'));

    await _loadProducts();
    await restorePurchases();
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (!kAllProductIds.contains(purchase.productID)) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _isPremium = true;
        debugPrint(
          '[IapService] Premium active — product: ${purchase.productID} status: ${purchase.status}',
        );
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('[IapService] Purchase error: ${purchase.error}');
      }

      if (purchase.pendingCompletePurchase) {
        completePurchase(purchase);
      }
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
      debugPrint('[IapService] Restore purchases triggered.');
    } catch (e) {
      debugPrint('[IapService] Restore error: $e');
    }
  }

  Future<void> _loadProducts() async {
    _isLoading = true;
    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('[IapService] Store not available.');
      _isLoading = false;
      return;
    }
    _weeklyPlanInfo = null;
    _monthlyPlanInfo = null;
    final ProductDetailsResponse response = await _iap.queryProductDetails(
      kAllProductIds,
    );
    if (response.error != null) {
      debugPrint('[IapService] Query error: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[IapService] Products not found: ${response.notFoundIDs}');
    }
    for (final product in response.productDetails) {
      final PlanInfo info = Platform.isAndroid
          ? _parseAndroid(product)
          : _parseIOS(product);

      if (product.id == weeklyProduct) {
        _weeklyPlanInfo = info;
      } else if (product.id == monthlyProduct) {
        _monthlyPlanInfo = info;
      }
    }
    _isLoading = false;
  }

  PlanInfo _parseAndroid(ProductDetails product) {
    final androidProduct = product as GooglePlayProductDetails;
    final offers = androidProduct.productDetails.subscriptionOfferDetails ?? [];

    SubscriptionOfferDetailsWrapper? baseOffer;
    SubscriptionOfferDetailsWrapper? introOffer;

    for (final offer in offers) {
      if (offer.offerId == kWeeklyOfferId) {
        if (product.id == weeklyProduct) {
          introOffer = offer;
        }
      } else if (offer.offerId == null) {
        baseOffer = offer;
      }
    }
    baseOffer ??= offers.isNotEmpty ? offers.last : null;

    final regularPrice =
        baseOffer?.pricingPhases.last.formattedPrice ?? product.price;

    // Intro offer: use the first pricing phase (the discounted one)
    final String? offerPrice = introOffer != null
        ? introOffer.pricingPhases.first.formattedPrice
        : null;

    return PlanInfo(
      product: product,
      regularPrice: regularPrice,
      offerPrice: offerPrice,
      offerToken: introOffer?.offerIdToken,
      baseOfferToken: baseOffer?.offerIdToken,
    );
  }

  PlanInfo _parseIOS(ProductDetails product) {
    // SKProductDetails exposes introductoryPrice via the raw skProduct.
    // The plugin surfaces it on AppStorePurchaseDetails but not ProductDetails directly,
    // so we check the raw product via a try/catch to stay safe.
    String? offerPrice;
    try {
      // ignore: avoid_dynamic_calls
      final raw = (product as dynamic).skProduct;
      final intro = raw?.introductoryPrice;
      if (intro != null) {
        offerPrice = intro.localizedPrice as String?;
      }
    } catch (_) {}

    return PlanInfo(
      product: product,
      regularPrice: product.price,
      offerPrice: offerPrice,
      // offerToken is Android-only; not needed for iOS
    );
  }

  /// Buys the weekly plan.
  /// On Android, uses the intro offer token if the offer is available,
  /// otherwise falls back to the base plan token.
  Future<void> buyWeekly() async {
    final plan = _weeklyPlanInfo;
    if (plan == null) {
      debugPrint('[IapService] Weekly plan not loaded.');
      return;
    }
    await _buy(plan, preferOffer: true);
  }

  Future<void> buyMonthly() async {
    final plan = _monthlyPlanInfo;
    if (plan == null) {
      debugPrint('[IapService] Monthly plan not loaded.');
      return;
    }
    await _buy(plan, preferOffer: false);
  }

  Future<void> _buy(PlanInfo plan, {required bool preferOffer}) async {
    if (Platform.isAndroid) {
      final androidProduct = plan.product as GooglePlayProductDetails;
      final offers =
          androidProduct.productDetails.subscriptionOfferDetails ?? [];

      if (offers.isEmpty) {
        debugPrint('[IapService] No offers found for ${plan.product.id}');
        return;
      }

      // Use intro offer token when available and preferred (weekly only)
      String? targetToken;
      if (preferOffer && plan.hasOffer) {
        targetToken = plan.offerToken;
        debugPrint(
          '[IapService] Purchasing with INTRO offer token: $targetToken',
        );
      } else {
        targetToken = plan.baseOfferToken;
        debugPrint(
          '[IapService] Purchasing with BASE offer token: $targetToken',
        );
      }

      // Final fallback
      if (targetToken == null) {
        final fallback = offers.firstWhere(
          (o) => o.offerId == null,
          orElse: () => offers.first,
        );
        targetToken = fallback.offerIdToken;
        debugPrint('[IapService] Using fallback token: $targetToken');
      }

      await _iap.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: androidProduct,
          offerToken: targetToken,
          changeSubscriptionParam: null,
        ),
      );
      return;
    }

    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: plan.product),
    );
  }

  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  void dispose() {
    _iapSubscription?.cancel();
    _purchaseController.close();
  }
}
