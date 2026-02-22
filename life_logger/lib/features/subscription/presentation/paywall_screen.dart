/// ZuraLog — Subscription Paywall Screen.
///
/// Presents the RevenueCat-configured paywall using the [PaywallView] widget.
/// Handles purchase/restore callbacks, awaits subscription state refresh before
/// popping, and guards all context usage behind [BuildContext.mounted] checks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'package:life_logger/features/subscription/domain/subscription_providers.dart';

/// Full-screen paywall for ZuraLog Pro.
///
/// Push this route whenever a gated feature is accessed or when the user
/// explicitly taps "Upgrade". Returns a [PaywallResult] via [Navigator.pop]
/// so the caller knows whether a purchase/restore occurred.
///
/// Example:
/// ```dart
/// final result = await Navigator.push<PaywallResult>(
///   context,
///   MaterialPageRoute(builder: (_) => const PaywallScreen()),
/// );
/// if (result == PaywallResult.purchased) { /* unlock feature */ }
/// ```
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, this.offering});

  /// Optional specific offering to display. Defaults to the current offering
  /// configured in the RevenueCat dashboard.
  final Offering? offering;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: PaywallView(
        offering: offering,
        displayCloseButton: true,
        onPurchaseStarted: (rcPackage) {
          debugPrint(
            '[PaywallScreen] Purchase started: ${rcPackage.identifier}',
          );
        },
        onPurchaseCompleted: (customerInfo, storeTransaction) async {
          debugPrint(
            '[PaywallScreen] Purchase completed: '
            '${storeTransaction.productIdentifier}',
          );
          // Await refresh so state is updated before the caller reads it.
          await ref.read(subscriptionProvider.notifier).refresh();
          if (context.mounted) {
            Navigator.of(context).pop(PaywallResult.purchased);
          }
        },
        onPurchaseCancelled: () {
          if (context.mounted) {
            Navigator.of(context).pop(PaywallResult.cancelled);
          }
        },
        onPurchaseError: (error) {
          debugPrint('[PaywallScreen] Purchase error: ${error.message}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Purchase failed: ${error.message}'),
                backgroundColor: const Color(0xFFFF6B6B),
              ),
            );
          }
        },
        onRestoreCompleted: (customerInfo) async {
          debugPrint('[PaywallScreen] Restore completed');
          await ref.read(subscriptionProvider.notifier).refresh();
          if (context.mounted) {
            Navigator.of(context).pop(PaywallResult.restored);
          }
        },
        onRestoreError: (error) {
          debugPrint('[PaywallScreen] Restore error: ${error.message}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Restore failed: ${error.message}'),
                backgroundColor: const Color(0xFFFF6B6B),
              ),
            );
          }
        },
        onDismiss: () {
          if (context.mounted) {
            Navigator.of(context).pop(PaywallResult.cancelled);
          }
        },
      ),
    );
  }
}
