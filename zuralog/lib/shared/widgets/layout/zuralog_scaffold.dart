/// Zuralog Design System — Layout Shell Widget.
library;

import 'package:flutter/material.dart';

/// The standard layout shell for all Zuralog screens.
///
/// Enforces:
/// - Theme-aware scaffold background (never hardcoded)
/// - SafeArea wrapping body only (not the whole scaffold)
///
/// ## Bottom clearance for tab screens
///
/// [AppShell] uses `extendBody: true` on its [Scaffold]. Flutter therefore
/// automatically injects the frosted nav bar's rendered height into
/// [MediaQuery.padding.bottom] for all children of the body. This means:
///
/// - **Scrollable bodies** ([ListView], [CustomScrollView], etc.): padding is
///   applied either automatically (when no explicit `padding` is set on the
///   scroll view) or via [AppDimens.bottomClearance] in the explicit padding.
/// - **Non-scrollable bodies** (e.g. a [Column] with a pinned input bar):
///   add a [SizedBox] at the bottom whose height is
///   `MediaQuery.of(context).padding.bottom` to push content clear of the nav bar.
///
/// The [addBottomNavPadding] parameter is **deprecated** and is now a no-op.
/// Bottom clearance is handled by Flutter's `extendBody` MediaQuery injection
/// combined with each body's own scroll padding or explicit [SizedBox]. Setting
/// it had been causing a double-counted ~80 px dead-space gap on every tab.
///
/// Usage inside bottom nav shell:
/// ```dart
/// ZuralogScaffold(
///   appBar: ZuralogAppBar(title: 'Goals'),
///   body: ListView(...),  // auto-pads from MediaQuery.padding.bottom
/// )
/// ```
class ZuralogScaffold extends StatelessWidget {
  const ZuralogScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    @Deprecated(
      'addBottomNavPadding is a no-op. '
      'Bottom clearance is handled automatically by Flutter\'s extendBody '
      'MediaQuery injection. Remove this parameter from call sites.',
    )
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

  /// Deprecated — no-op. Bottom clearance is handled by Flutter's extendBody
  /// MediaQuery injection. See class documentation for the correct pattern.
  // ignore: deprecated_member_use_from_same_package
  @Deprecated(
    'addBottomNavPadding is a no-op. '
    'Bottom clearance is handled automatically by Flutter\'s extendBody '
    'MediaQuery injection. Remove this parameter from call sites.',
  )
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

    // NOTE: addBottomNavPadding is intentionally NOT applied here.
    // AppShell.Scaffold(extendBody: true) injects the nav bar height into
    // MediaQuery.padding.bottom automatically. Applying an additional Padding
    // here caused a double-counted ~80 px dead-space gap on every tab screen.

    // Wrap in SafeArea if required.
    if (useSafeArea) {
      final effectiveTop = safeAreaTop ?? (appBar == null);
      content = SafeArea(
        top: effectiveTop,
        bottom: false, // Bottom clearance is owned by the body's scroll view.
        child: content,
      );
    }

    // Lift the FAB above the outer AppShell nav bar.
    //
    // Flutter's automatic FAB lift only works when the FAB and the bottom
    // navigation bar live on the *same* Scaffold. AppShell's outer Scaffold
    // owns the nav bar, so this inner Scaffold never lifts its FAB. We
    // compensate by adding bottom padding equal to the nav bar height that
    // AppShell's `extendBody: true` has already injected into
    // MediaQuery.padding.bottom — but only when this Scaffold has no local
    // bottom navigation bar of its own.
    Widget? effectiveFab = floatingActionButton;
    if (effectiveFab != null && bottomNavigationBar == null) {
      effectiveFab = Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        child: effectiveFab,
      );
    }

    return Scaffold(
      // backgroundColor reads from theme — NEVER hardcoded.
      appBar: appBar,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: effectiveFab,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
    );
  }
}
