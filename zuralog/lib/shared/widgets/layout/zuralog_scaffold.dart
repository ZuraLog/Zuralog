/// Zuralog Design System — Layout Shell Widget.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_dimens.dart';

/// The standard layout shell for all Zuralog screens.
///
/// Enforces:
/// - Theme-aware scaffold background (never hardcoded)
/// - SafeArea wrapping body only (not the whole scaffold)
/// - Automatic bottom clearance for screens inside the nav shell
///
/// Usage inside bottom nav shell:
/// ```dart
/// ZuralogScaffold(
///   appBar: ZuralogAppBar(title: 'Goals'),
///   addBottomNavPadding: true,
///   body: ListView(...),
/// )
/// ```
class ZuralogScaffold extends StatelessWidget {
  const ZuralogScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.addBottomNavPadding = false,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.useSafeArea = true,
    this.safeAreaTop,
    this.bodyPadding,
  });

  /// The main content of the screen.
  final Widget body;

  /// Optional app bar. When provided, SafeArea top is automatically disabled
  /// (the AppBar already handles the status bar inset).
  final PreferredSizeWidget? appBar;

  /// Optional bottom navigation bar. Should only be used by AppShell.
  final Widget? bottomNavigationBar;

  /// Optional floating action button.
  final Widget? floatingActionButton;

  /// When true, adds [AppDimens.bottomClearance] padding below the body.
  /// Set to true for all screens hosted inside the bottom nav shell.
  final bool addBottomNavPadding;

  /// Whether to resize the body when the keyboard appears. Defaults to true.
  final bool resizeToAvoidBottomInset;

  /// Whether the body should extend behind the bottom navigation bar.
  final bool extendBody;

  /// Whether to wrap the body in SafeArea. Set to false for full-bleed screens
  /// (e.g., onboarding, splash) that handle insets manually.
  final bool useSafeArea;

  /// Override SafeArea top behavior. When null, auto-detects from [appBar]:
  /// - appBar present → top: false (AppBar handles status bar)
  /// - appBar absent → top: true (content must not render under status bar)
  final bool? safeAreaTop;

  /// Additional padding applied around [body] inside the SafeArea.
  final EdgeInsetsGeometry? bodyPadding;

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    // Apply optional body padding.
    if (bodyPadding != null) {
      content = Padding(padding: bodyPadding!, child: content);
    }

    // Apply bottom nav clearance padding.
    if (addBottomNavPadding) {
      content = Padding(
        padding: EdgeInsets.only(bottom: AppDimens.bottomClearance(context)),
        child: content,
      );
    }

    // Wrap in SafeArea if required.
    if (useSafeArea) {
      final effectiveTop = safeAreaTop ?? (appBar == null);
      content = SafeArea(
        top: effectiveTop,
        bottom: false, // Bottom clearance is handled explicitly above.
        child: content,
      );
    }

    return Scaffold(
      // backgroundColor reads from theme — NEVER hardcoded.
      appBar: appBar,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
    );
  }
}
