import '../services/premium_service.dart';

/// Cloud AI (Pro) features are unlocked at runtime via in-app purchase.
/// Returns true when the user has purchased the premium unlock (or in debug).
bool get kCloudAiEnabled => PremiumService.instance.isPremium;

/// Human-readable edition name, derived from purchase state.
String get kEditionName => kCloudAiEnabled ? 'Pro' : 'Free';