import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arman_vpn/app_settings.dart';
import 'package:arman_vpn/core/core_controller.dart';
import 'package:arman_vpn/core/models.dart';
import 'package:arman_vpn/l10n/app_localizations.dart';
import 'package:arman_vpn/mobile/speed_sparkline.dart';
import 'package:arman_vpn/ui/app.dart';
import 'package:arman_vpn/ui/servers_page.dart';

import 'widget_test.dart' show FakeApi;

class _MobileFakeApi extends FakeApi {
  @override
  Future<CoreStatus> status() async => CoreStatus.fromJson({
    'state': on ? {'phase': 'running', 'message': ''} : {'phase': 'off'},
    'system_proxy': 'clear',
    'system_proxy_supported': false,
    'selection': location,
    'proxy': {
      'listen': '127.0.0.1:10810',
      'country_code': 'NL',
      'country_name': 'Netherlands',
      'city_name': 'Amsterdam',
      'transport': 'HTTP/2',
      'started_at': DateTime.now()
          .subtract(const Duration(seconds: 75))
          .toUtc()
          .toIso8601String(),
    },
    'traffic': {
      'up': 1024,
      'down': 4096,
      'direct_up': 0,
      'direct_down': 0,
      'up_rate': 512,
      'down_rate': 2048,
    },
    'active_account': accountsJson.first,
    'accounts': {'total': 2, 'ready': 1, 'reauth_required': 1},
    'switch_threshold_percent': 90,
    'version': '1.0.18',
  });
}

void main() {
  test('AppSettings persists favoriteCountries and showSpeedChart', () async {
    final dir = Directory.systemTemp.createTempSync('mobile_settings_');
    try {
      final settings = await AppSettings.load(dir.path);
      expect(settings.favoriteCountries, isEmpty);
      expect(settings.showSpeedChart, isTrue);

      settings.toggleFavoriteCountry('de');
      settings.toggleFavoriteCountry('NL');
      settings.update(showSpeedChart: false);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final reloaded = await AppSettings.load(dir.path);
      expect(reloaded.favoriteCountries, ['DE', 'NL']);
      expect(reloaded.showSpeedChart, isFalse);

      reloaded.toggleFavoriteCountry('DE');
      expect(reloaded.favoriteCountries, ['NL']);
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('SpeedHistory records samples and resets when proxy stops', () {
    final running = CoreStatus.fromJson({
      'state': {'phase': 'running'},
      'proxy': {'started_at': DateTime.now().toUtc().toIso8601String()},
      'traffic': {'up': 1024, 'down': 4096, 'up_rate': 512, 'down_rate': 2048},
    });
    SpeedHistory.record(running);
    SpeedHistory.record(running);
    expect(SpeedHistory.samples.length, greaterThanOrEqualTo(2));

    final stopped = CoreStatus.fromJson({
      'state': {'phase': 'off'},
      'traffic': {'up': 0, 'down': 0, 'up_rate': 0, 'down_rate': 0},
    });
    SpeedHistory.record(stopped);
    expect(SpeedHistory.samples, isEmpty);
  });

  testWidgets('Phone home shows live speed chart and quick location chips', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = _MobileFakeApi();
    final core = CoreController(
      () async => api,
      pollInterval: const Duration(hours: 1),
      turnOn: (on) async => api.on = on,
    );
    final settings = AppSettings()
      ..themeMode = ThemeMode.dark
      ..favoriteCountries = const ['DE'];

    await tester.pumpWidget(VpnApp(core: core, settings: settings));
    core.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(LiveSpeedCard), findsOneWidget);
    expect(find.byType(SessionDurationText), findsOneWidget);
    expect(find.text('DE'), findsOneWidget);

    await tester.tap(find.text('DE'));
    await tester.pump();
    expect(api.location, 'DE');

    await tester.pumpWidget(const SizedBox());
    core.dispose();
  });

  testWidgets('ServersPage filters countries and pins favorites', (
    tester,
  ) async {
    final api = FakeApi();
    final core = CoreController(
      () async => api,
      pollInterval: const Duration(hours: 1),
    );
    final settings = AppSettings();
    core.start();
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ServersPage(core: core, settings: settings),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ping & connect fastest'), findsOneWidget);

    await tester.tap(find.byTooltip('Pin to favorites').first);
    await tester.pumpAndSettle();
    expect(settings.favoriteCountries, isNotEmpty);

    await tester.pumpWidget(const SizedBox());
    core.dispose();
  });
}
