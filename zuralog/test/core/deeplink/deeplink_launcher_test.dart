import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:zuralog/core/deeplink/deeplink_launcher.dart';

class MockUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? launchedUrl;
  LaunchOptions? launchOptions;
  bool mockCanLaunch = false;
  bool launchResult = true;

  @override
  Future<bool> canLaunch(String url) async {
    return mockCanLaunch;
  }

  Future<bool> canLaunchUrl(String url) async {
    return mockCanLaunch;
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrl = url;
    return launchResult;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    launchOptions = options;
    return launchResult;
  }
}

void main() {
  late MockUrlLauncher mock;

  setUp(() {
    mock = MockUrlLauncher();
    UrlLauncherPlatform.instance = mock;
  });

  group('DeepLinkLauncher - openFoodLogging', () {
    test('launches calai://camera if available', () async {
      mock.mockCanLaunch = true; // Simulates app is installed

      final result = await DeepLinkLauncher.openFoodLogging();

      expect(result, isTrue);
      expect(mock.launchedUrl, 'calai://camera');
      expect(mock.launchOptions?.mode, PreferredLaunchMode.externalApplication);
    });

    test('falls back to web app if calai:// is not canLaunchUrl', () async {
      // Custom logic: return false for calai, true for https
      UrlLauncherPlatform.instance = _FallbackMockUrlLauncher();

      final result = await DeepLinkLauncher.openFoodLogging();

      expect(result, isTrue);
      final fallbackMock =
          UrlLauncherPlatform.instance as _FallbackMockUrlLauncher;
      expect(fallbackMock.launchedUrl, 'https://www.calai.app');
    });

    test('returns false if both fail', () async {
      mock.mockCanLaunch = false;

      final result = await DeepLinkLauncher.openFoodLogging();

      expect(result, isFalse);
    });
  });

  group('DeepLinkLauncher - executeDeepLink', () {
    test('launches deep link URL when available', () async {
      mock.mockCanLaunch = true;

      final result = await DeepLinkLauncher.executeDeepLink(
        'strava://record',
      );

      expect(result, isTrue);
      expect(mock.launchedUrl, 'strava://record');
      expect(mock.launchOptions?.mode, PreferredLaunchMode.externalApplication);
    });

    test('uses fallback URL when deep link is unavailable', () async {
      // Use the fallback mock that rejects non-HTTPS schemes.
      final fallbackMock = _GenericFallbackMockUrlLauncher();
      UrlLauncherPlatform.instance = fallbackMock;

      final result = await DeepLinkLauncher.executeDeepLink(
        'strava://record',
        fallbackUrl: 'https://www.strava.com',
      );

      expect(result, isTrue);
      expect(fallbackMock.launchedUrl, 'https://www.strava.com');
    });

    test('returns false when both deep link and fallback fail', () async {
      mock.mockCanLaunch = false;

      final result = await DeepLinkLauncher.executeDeepLink(
        'strava://record',
        fallbackUrl: 'https://www.strava.com',
      );

      expect(result, isFalse);
    });

    test('returns false when no fallback provided and deep link fails',
        () async {
      mock.mockCanLaunch = false;

      final result = await DeepLinkLauncher.executeDeepLink(
        'strava://record',
      );

      expect(result, isFalse);
    });

    test('handles empty fallback URL gracefully', () async {
      mock.mockCanLaunch = false;

      final result = await DeepLinkLauncher.executeDeepLink(
        'strava://record',
        fallbackUrl: '',
      );

      expect(result, isFalse);
    });
  });
}

class _FallbackMockUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? launchedUrl;

  @override
  Future<bool> canLaunch(String url) async {
    if (url.startsWith('calai')) return false;
    return true; // web url succeeds
  }

  Future<bool> canLaunchUrl(String url) async {
    if (url.startsWith('calai')) return false;
    return true; // web url succeeds
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrl = url;
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    return true;
  }
}

/// Mock that rejects custom schemes but accepts HTTPS URLs.
///
/// Used by [executeDeepLink] tests to verify fallback behaviour
/// for arbitrary deep link schemes.
class _GenericFallbackMockUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? launchedUrl;

  @override
  Future<bool> canLaunch(String url) async {
    // Only allow HTTPS URLs, reject custom schemes.
    return url.startsWith('https');
  }

  Future<bool> canLaunchUrl(String url) async {
    // Only allow HTTPS URLs, reject custom schemes.
    return url.startsWith('https');
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrl = url;
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    return true;
  }
}
