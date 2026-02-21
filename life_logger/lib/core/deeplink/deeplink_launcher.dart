/// Life Logger — Outbound Deep Link Launcher.
///
/// Provides static helpers for launching external applications via
/// custom URL schemes. Currently supports CalAI for food photo logging.
///
/// This is distinct from [DeeplinkHandler], which handles *inbound*
/// deep links (`lifelogger://`). This class handles *outbound* links
/// to third-party apps.
library;

import 'package:url_launcher/url_launcher.dart';

/// Launches external apps via deep links with smart fallback.
///
/// All methods are safe to call on any platform — they return
/// `false` when the target app cannot be launched and the fallback
/// URL is also unavailable.
class DeepLinkLauncher {
  DeepLinkLauncher._();

  // -- CalAI ---------------------------------------------------------------

  /// Hypothetical CalAI deep link URI.
  ///
  /// If CalAI changes their scheme, update this constant.
  static const _calaiDeepLink = 'calai://camera';

  /// Fallback web/store URL when CalAI is not installed.
  ///
  /// Replace with the actual CalAI App Store or web-app URL once known.
  static const _calaiWebUrl = 'https://www.calai.app';

  /// Attempts to open CalAI for food photo logging.
  ///
  /// 1. Tries to launch the native CalAI app via `calai://camera`.
  /// 2. If the app is not installed, falls back to the CalAI web/store URL.
  /// 3. Returns `true` if either launch succeeds, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final opened = await DeepLinkLauncher.openFoodLogging();
  /// if (!opened) {
  ///   showSnackBar('Could not open CalAI');
  /// }
  /// ```
  static Future<bool> openFoodLogging() async {
    final deepLinkUri = Uri.parse(_calaiDeepLink);

    try {
      if (await canLaunchUrl(deepLinkUri)) {
        return await launchUrl(
          deepLinkUri,
          mode: LaunchMode.externalApplication,
        );
      }
    } on Exception {
      // CalAI app not found — fall through to web fallback.
    }

    // Fallback: open CalAI website or App Store page.
    final webUri = Uri.parse(_calaiWebUrl);
    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } on Exception {
      // Web fallback also failed.
    }

    return false;
  }
}
