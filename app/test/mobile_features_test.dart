import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arman_vpn/app_settings.dart';
import 'package:arman_vpn/core/core_controller.dart';
import 'package:arman_vpn/core/models.dart';
import 'package:arman_vpn/l10n/app_localizations.dart';
import 'package:arman_vpn/mobile/connection_doctor.dart';
import 'package:arman_vpn/mobile/location_ping_cache.dart';
import 'package:arman_vpn/mobile/speed_sparkline.dart';
import 'package:arman_vpn/ui/about_page.dart';
import 'package:arman_vpn/ui/app.dart';
import 'package:arman_vpn/ui/servers_page.dart';

import 'widget_test.dart' show FakeApi;

class _MobileFakeApi extends FakeApi {
  @override
  Future<List<DnsTestHost>> testDns(List<String> servers) async => [
    DnsTestHost.fromJson({
      'host': 'accounts.firefox.com',
      'addrs': ['34.120.1.2'],
    }),
  ];

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
    'last_test': {
      'at': DateTime.now().toUtc().toIso8601String(),
      'ok': true,
      'http_status': 204,
      'tunnel_ms': 100,
      'tls_ms': 80,
      'response_ms': 60,
      'total_ms': 240,
    },
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
    LocationPingCache.clear();
    addTearDown(LocationPingCache.clear);
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

    expect(tester.takeException(), isNull);
    expect(find.text('IceDragon VPN'), findsOneWidget);
    expect(find.byType(LiveSpeedCard), findsOneWidget);
    expect(find.byType(SessionDurationText), findsOneWidget);
    expect(find.text('DE'), findsOneWidget);
    expect(find.text('650ms'), findsOneWidget);

    await tester.ensureVisible(find.text('DE'));
    await tester.pump();
    await tester.tap(find.text('DE'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.location, 'DE');

    await tester.pumpWidget(const SizedBox());
    core.dispose();
  });

  testWidgets('AboutPage shows positive IceDragon info and Telegram channel', (
    tester,
  ) async {
    final api = _MobileFakeApi();
    final core = CoreController(
      () async => api,
      pollInterval: const Duration(hours: 1),
    );
    core.start();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AboutPage(core: core)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IceDragon VPN'), findsOneWidget);
    expect(find.text('@icedragon_lair', skipOffstage: false), findsOneWidget);
    expect(find.text('Telegram', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('Unofficial', skipOffstage: false), findsNothing);

    await tester.pumpWidget(const SizedBox());
    core.dispose();
  });

  testWidgets('LiveSpeedCard fits ultra-narrow screens without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final traffic = Traffic.fromJson({
      'up': 12 << 20,
      'down': 345 << 20,
      'up_rate': 950 << 10,
      'down_rate': 12 << 20,
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: LiveSpeedCard(
              traffic: traffic,
              samples: const [SpeedSample(1024, 512), SpeedSample(4096, 1024)],
              startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
              dark: true,
              textColor: Colors.white,
              mutedColor: Colors.white70,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(LiveSpeedCard), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
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
    await tester.pump(const Duration(milliseconds: 50));

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

  test('LocationPingCache stores measured delays and ignores failures', () {
    LocationPingCache.clear();
    addTearDown(LocationPingCache.clear);

    LocationPingCache.recordAll([
      Location.fromJson({'code': 'de', 'name': 'Germany', 'ping_ms': 95}),
      Location.fromJson({'code': 'jp', 'name': 'Japan', 'ping_ms': 0}),
    ]);

    expect(LocationPingCache.latencies.value, {'DE': 95});
  });

  testWidgets('Smart Connection Doctor autoStart probes profiles immediately', (
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
    core.start();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showConnectionDoctorSheet(context, core, autoStart: true),
              child: const Text('Open Doctor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Doctor'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Working profile found'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    core.dispose();
  });
}
