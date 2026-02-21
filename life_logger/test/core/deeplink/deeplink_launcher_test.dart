import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:life_logger/core/deeplink/deeplink_launcher.dart';

class MockUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? launchedUrl;
  LaunchOptions? launchOptions;
  bool mockCanLaunch = false;
  bool launchResult = true;

  Future<bool> canLaunch(String url) async {
    return mockCanLaunch;
  }

  @override
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
}

class _FallbackMockUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? launchedUrl;

  Future<bool> canLaunch(String url) async {
    if (url.startsWith('calai')) return false;
    return true; // web url succeeds
  }

  @override
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
