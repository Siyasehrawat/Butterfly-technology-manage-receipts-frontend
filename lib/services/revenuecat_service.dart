import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'webhook_service.dart';

class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  // API Keys - IMPORTANT: Replace with your actual production keys
  static const String _androidApiKeySandbox = 'goog_oKzqPhzDXCTrIDdFvcxTeLwyRxO';
  static const String _iosApiKeySandbox = 'appl_udzebtbwiCCfeKylykPojxsFANL';
  // TODO: Replace these with your actual production keys from RevenueCat dashboard
  static const String _androidApiKeyProduction = 'goog_YOUR_PRODUCTION_ANDROID_KEY';
  static const String _iosApiKeyProduction = 'appl_YOUR_PRODUCTION_IOS_KEY';

  // Product identifiers - these should match your RevenueCat/App Store Connect setup
  static const String premiumMonthlyProductId = 'MR_PRO_MONTHLY';
  static const String premiumYearlyProductId = 'MR_PRO_ANNUAL';
  static const String premiumEntitlementId = 'Pro';

  bool _isInitialized = false;
  bool _isPluginAvailable = false;
  Offerings? _offerings;
  CustomerInfo? _customerInfo;
  Timer? _periodicTimer;

  bool get isSandbox => kDebugMode;
  bool get isPluginAvailable => _isPluginAvailable;

  Future<bool> initialize() async {
    if (_isInitialized) return _isPluginAvailable;

    try {
      debugPrint('🚀 Initializing RevenueCat...');

      _isPluginAvailable = await _checkPluginAvailability();

      if (!_isPluginAvailable) {
        debugPrint('❌ RevenueCat plugin not available - running in fallback mode');
        return false;
      }

      // Set log level with error handling
      try {
        await Purchases.setLogLevel(isSandbox ? LogLevel.debug : LogLevel.info);
        debugPrint('✅ RevenueCat log level set successfully');
      } catch (e) {
        debugPrint('⚠️ Failed to set log level (non-critical): $e');
      }

      String apiKey;
      if (Platform.isAndroid) {
        apiKey = isSandbox ? _androidApiKeySandbox : _androidApiKeyProduction;
      } else if (Platform.isIOS) {
        apiKey = isSandbox ? _iosApiKeySandbox : _iosApiKeyProduction;
      } else {
        throw UnsupportedError('Unsupported platform');
      }

      // Validate API key
      if (apiKey.contains('YOUR_PRODUCTION') && !isSandbox) {
        throw Exception('Production API keys not configured. Please update RevenueCatService with your production keys.');
      }

      final configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      _isInitialized = true;

      // Set up customer info listener for real-time updates
      _setupCustomerInfoListener();

      // Load initial data
      await _loadOfferings();
      await _loadCustomerInfo();

      debugPrint('🎉 RevenueCat initialized successfully (${isSandbox ? 'SANDBOX' : 'PRODUCTION'})');

      // Run debug configuration check in debug mode
      if (kDebugMode) {
        await debugProductConfiguration();
      }

      return true;
    } catch (e) {
      debugPrint('❌ Failed to initialize RevenueCat: $e');
      _isPluginAvailable = false;
      return false;
    }
  }

  // Enhanced debug method with better formatting
  Future<void> debugProductConfiguration() async {
    if (!kDebugMode) return;

    try {
      debugPrint('');
      debugPrint('🔍 === RevenueCat Product Debug ===');
      debugPrint('🌍 Environment: ${isSandbox ? 'SANDBOX' : 'PRODUCTION'}');
      debugPrint('📦 Expected Products: $premiumMonthlyProductId, $premiumYearlyProductId');
      debugPrint('🎫 Expected Entitlement: $premiumEntitlementId');
      debugPrint('');

      final offerings = await Purchases.getOfferings();
      debugPrint('📋 Total offerings: ${offerings.all.length}');

      if (offerings.current != null) {
        debugPrint('✅ Current offering: ${offerings.current!.identifier}');
        debugPrint('📦 Available packages: ${offerings.current!.availablePackages.length}');
        debugPrint('');

        for (final package in offerings.current!.availablePackages) {
          debugPrint('  📦 Package: ${package.identifier}');
          debugPrint('     Product ID: ${package.storeProduct.identifier}');
          debugPrint('     Title: ${package.storeProduct.title}');
          debugPrint('     Price: ${package.storeProduct.priceString}');
          debugPrint('     Description: ${package.storeProduct.description}');
          debugPrint('     ---');
        }
      } else {
        debugPrint('❌ No current offering found');
      }

      // Check customer info
      final customerInfo = await Purchases.getCustomerInfo();
      debugPrint('👤 Customer ID: ${customerInfo.originalAppUserId}');
      debugPrint('🎫 Active entitlements: ${customerInfo.entitlements.active.keys.toList()}');
      debugPrint('🎫 All entitlements: ${customerInfo.entitlements.all.keys.toList()}');

      // Check specific entitlement
      final premiumEntitlement = customerInfo.entitlements.all[premiumEntitlementId];
      if (premiumEntitlement != null) {
        debugPrint('✅ Premium entitlement found:');
        debugPrint('   Active: ${premiumEntitlement.isActive}');
        debugPrint('   Product: ${premiumEntitlement.productIdentifier}');
        debugPrint('   Will Renew: ${premiumEntitlement.willRenew}');
        debugPrint('   Expires: ${premiumEntitlement.expirationDate}');
      } else {
        debugPrint('❌ Premium entitlement not found');
      }

      debugPrint('🔍 === End Debug ===');
      debugPrint('');

    } catch (e) {
      debugPrint('❌ Debug failed: $e');
    }
  }

  void _setupCustomerInfoListener() {
    try {
      debugPrint('⏰ Setting up periodic customer info updates');
      _setupPeriodicCustomerInfoUpdates();
    } catch (e) {
      debugPrint('❌ Error setting up customer info listener: $e');
      _setupPeriodicCustomerInfoUpdates();
    }
  }

  void _setupPeriodicCustomerInfoUpdates() {
    _periodicTimer?.cancel();

    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!_isInitialized || !_isPluginAvailable) {
        timer.cancel();
        return;
      }

      try {
        final newCustomerInfo = await Purchases.getCustomerInfo();

        if (_customerInfo == null ||
            _hasCustomerInfoChanged(_customerInfo!, newCustomerInfo)) {
          debugPrint('🔄 Customer info updated via periodic check');
          _customerInfo = newCustomerInfo;
          await _handleCustomerInfoUpdate(newCustomerInfo);
        }
      } catch (e) {
        debugPrint('❌ Error in periodic customer info update: $e');
      }
    });
  }

  bool _hasCustomerInfoChanged(CustomerInfo oldInfo, CustomerInfo newInfo) {
    try {
      final oldEntitlements = oldInfo.entitlements.active.keys.toSet();
      final newEntitlements = newInfo.entitlements.active.keys.toSet();

      if (!oldEntitlements.equals(newEntitlements)) {
        return true;
      }

      for (final entitlementId in newEntitlements) {
        final oldEntitlement = oldInfo.entitlements.active[entitlementId];
        final newEntitlement = newInfo.entitlements.active[entitlementId];

        if (oldEntitlement?.expirationDate != newEntitlement?.expirationDate) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error comparing customer info: $e');
      return true;
    }
  }

  Future<void> _handleCustomerInfoUpdate(CustomerInfo customerInfo) async {
    try {
      final activeEntitlements = customerInfo.entitlements.active;
      final allEntitlements = customerInfo.entitlements.all;

      for (final entitlement in allEntitlements.values) {
        final subscriptionData = {
          'productId': entitlement.productIdentifier,
          'entitlementId': entitlement.identifier,
          'entitlementIds': activeEntitlements.keys.toList(),
          'expirationAtMs': entitlement.expirationDate?.millisecondsSinceEpoch,
          'periodType': entitlement.periodType.name,
          'isFamilyShare': entitlement.isSandbox,
          'transactionId': entitlement.latestPurchaseDate?.millisecondsSinceEpoch.toString(),
          'originalTransactionId': entitlement.originalPurchaseDate?.millisecondsSinceEpoch.toString(),
          'offeringId': entitlement.productIdentifier,
          'appId': Platform.isIOS ? 'ios_app_id' : 'android_app_id',
        };

        String eventType;
        if (entitlement.isActive) {
          eventType = entitlement.willRenew ? 'RENEWAL' : 'INITIAL_PURCHASE';
        } else {
          eventType = 'EXPIRATION';
        }

        await WebhookService.handleRevenueCatEvent(
          eventType: eventType,
          userId: customerInfo.originalAppUserId,
          eventData: subscriptionData,
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling customer info update: $e');
    }
  }

  Future<bool> _checkPluginAvailability() async {
    try {
      await Purchases.isConfigured;
      return true;
    } on MissingPluginException catch (e) {
      debugPrint('❌ RevenueCat plugin not found: $e');
      return false;
    } catch (e) {
      debugPrint('⚠️ Error checking plugin availability: $e');
      return true;
    }
  }

  Future<void> _loadOfferings() async {
    if (!_isInitialized || !_isPluginAvailable) return;

    try {
      debugPrint('📦 Loading offerings...');
      _offerings = await Purchases.getOfferings();
      debugPrint('✅ Loaded ${_offerings?.all.length ?? 0} offerings');

      _offerings?.current?.availablePackages.forEach((package) {
        debugPrint('  📦 Available: ${package.storeProduct.identifier} - ${package.storeProduct.title}');
      });
    } catch (e) {
      debugPrint('❌ Error loading offerings: $e');
    }
  }

  Future<void> _loadCustomerInfo() async {
    if (!_isInitialized || !_isPluginAvailable) return;

    try {
      _customerInfo = await Purchases.getCustomerInfo();
      debugPrint('👤 Customer info loaded for user: ${_customerInfo?.originalAppUserId}');
    } catch (e) {
      debugPrint('❌ Error loading customer info: $e');
    }
  }

  Future<bool> isPremiumUser() async {
    if (!_isPluginAvailable) {
      debugPrint('⚠️ RevenueCat not available, returning false for premium status');
      return false;
    }

    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      final customerInfo = await getCustomerInfo();
      final isActive = customerInfo?.entitlements.all[premiumEntitlementId]?.isActive == true;
      debugPrint('🎫 Premium status check: $isActive');
      return isActive;
    } catch (e) {
      debugPrint('❌ Error checking premium status: $e');
      return false;
    }
  }

  Future<CustomerInfo?> getCustomerInfo() async {
    if (!_isPluginAvailable) return null;

    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    try {
      await _loadCustomerInfo();
      return _customerInfo;
    } catch (e) {
      debugPrint('❌ Error getting customer info: $e');
      return null;
    }
  }

  Future<PurchaseResult> purchasePremium({
    required String productId,
    required String userId,
    String? token,
  }) async {
    if (!_isPluginAvailable) {
      return PurchaseResult(
        success: false,
        error: 'RevenueCat not available. Please check your setup.',
      );
    }

    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return PurchaseResult(
          success: false,
          error: 'RevenueCat initialization failed. Please try again.',
        );
      }
    }

    try {
      debugPrint('💳 Starting purchase for product: $productId, user: $userId');

      await Purchases.logIn(userId);

      final offerings = await _getOfferings();
      if (offerings?.current == null) {
        return PurchaseResult(
          success: false,
          error: 'No offerings available. Please check your RevenueCat configuration.',
        );
      }

      Package? package = _findPackage(offerings!.current!, productId);
      if (package == null) {
        return PurchaseResult(
          success: false,
          error: 'Product not found: $productId. Available products: ${offerings.current!.availablePackages.map((p) => p.storeProduct.identifier).join(', ')}',
        );
      }

      debugPrint('✅ Found package: ${package.storeProduct.identifier}');

      final purchaserInfo = await Purchases.purchasePackage(package);
      debugPrint('🎉 Purchase completed, processing result...');

      final isPremium = purchaserInfo.entitlements.all[premiumEntitlementId]?.isActive == true;

      if (isPremium) {
        final purchaseData = {
          'productId': productId,
          'userId': userId,
          'transactionId': purchaserInfo.nonSubscriptionTransactions.isNotEmpty
              ? purchaserInfo.nonSubscriptionTransactions.first.transactionIdentifier
              : null,
          'purchaseDate': DateTime.now().toIso8601String(),
          'customerInfo': {
            'originalAppUserId': purchaserInfo.originalAppUserId,
            'entitlements': purchaserInfo.entitlements.active.keys.toList(),
          }
        };

        final webhookSuccess = await WebhookService.syncPurchaseWithBackend(
          userId: userId,
          purchaseData: purchaseData,
          token: token,
        );

        if (!webhookSuccess) {
          debugPrint('⚠️ Warning: Purchase successful but webhook sync failed');
        }
      }

      return PurchaseResult(
        success: isPremium,
        customerInfo: purchaserInfo,
        error: isPremium ? null : 'Purchase completed but premium not activated',
      );

    } on PlatformException catch (e) {
      return _handlePurchaseError(e);
    } catch (e) {
      debugPrint('❌ Unexpected purchase error: $e');
      return PurchaseResult(
        success: false,
        error: 'Purchase failed: $e',
      );
    }
  }

  Future<Offerings?> _getOfferings() async {
    if (_offerings == null) {
      await _loadOfferings();
    }
    return _offerings;
  }

  Package? _findPackage(Offering offering, String productId) {
    try {
      if (productId == premiumMonthlyProductId) {
        return offering.monthly ?? offering.availablePackages.firstWhere(
              (p) => p.storeProduct.identifier == premiumMonthlyProductId,
          orElse: () => throw Exception('Monthly package not found'),
        );
      } else if (productId == premiumYearlyProductId) {
        return offering.annual ?? offering.availablePackages.firstWhere(
              (p) => p.storeProduct.identifier == premiumYearlyProductId,
          orElse: () => throw Exception('Annual package not found'),
        );
      }

      for (final package in offering.availablePackages) {
        if (package.storeProduct.identifier == productId) {
          return package;
        }
      }
    } catch (e) {
      debugPrint('❌ Error finding package: $e');
    }
    return null;
  }

  PurchaseResult _handlePurchaseError(PlatformException e) {
    final errorCode = PurchasesErrorHelper.getErrorCode(e);
    String errorMessage;

    switch (errorCode) {
      case PurchasesErrorCode.purchaseCancelledError:
        errorMessage = 'Purchase was cancelled';
        break;
      case PurchasesErrorCode.purchaseNotAllowedError:
        errorMessage = 'Purchase not allowed';
        break;
      case PurchasesErrorCode.paymentPendingError:
        errorMessage = 'Payment is pending';
        break;
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        errorMessage = 'Product not available for purchase. Please check your App Store Connect configuration.';
        break;
      case PurchasesErrorCode.networkError:
        errorMessage = 'Network error occurred';
        break;
      case PurchasesErrorCode.receiptAlreadyInUseError:
        errorMessage = 'Receipt already in use';
        break;
      case PurchasesErrorCode.invalidReceiptError:
        errorMessage = 'Invalid receipt';
        break;
      default:
        errorMessage = e.message ?? 'Purchase failed';
    }

    debugPrint('❌ Purchase error: $errorMessage (Code: $errorCode)');
    return PurchaseResult(success: false, error: errorMessage);
  }

  Future<PurchaseResult> restorePurchases({String? token}) async {
    if (!_isPluginAvailable) {
      return PurchaseResult(
        success: false,
        error: 'RevenueCat not available',
      );
    }

    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return PurchaseResult(
          success: false,
          error: 'RevenueCat initialization failed',
        );
      }
    }

    try {
      debugPrint('🔄 Restoring purchases...');
      final customerInfo = await Purchases.restorePurchases();
      final isPremium = customerInfo.entitlements.all[premiumEntitlementId]?.isActive == true;

      if (isPremium) {
        final restoreData = {
          'userId': customerInfo.originalAppUserId,
          'restored': true,
          'entitlements': customerInfo.entitlements.active.keys.toList(),
          'restoreDate': DateTime.now().toIso8601String(),
        };

        await WebhookService.syncPurchaseWithBackend(
          userId: customerInfo.originalAppUserId,
          purchaseData: restoreData,
          token: token,
        );
      }

      return PurchaseResult(
        success: isPremium,
        customerInfo: customerInfo,
        error: isPremium ? null : 'No active subscriptions found',
      );
    } catch (e) {
      debugPrint('❌ Restore purchases error: $e');
      return PurchaseResult(
        success: false,
        error: 'Failed to restore purchases: $e',
      );
    }
  }

  Future<bool> isSandboxEnvironment() async {
    return isSandbox;
  }

  Future<void> logout() async {
    if (!_isInitialized || !_isPluginAvailable) return;

    try {
      await Purchases.logOut();
      _customerInfo = null;
      debugPrint('👋 RevenueCat user logged out');
    } catch (e) {
      debugPrint('❌ Error logging out: $e');
    }
  }

  void dispose() {
    _periodicTimer?.cancel();
  }
}

extension on String? {
  get millisecondsSinceEpoch => null;
}

class PurchaseResult {
  final bool success;
  final String? error;
  final CustomerInfo? customerInfo;

  PurchaseResult({
    required this.success,
    this.error,
    this.customerInfo,
  });

  @override
  String toString() {
    return 'PurchaseResult(success: $success, error: $error)';
  }
}

extension SetEquality<T> on Set<T> {
  bool equals(Set<T> other) {
    if (length != other.length) return false;
    return containsAll(other) && other.containsAll(this);
  }
}
