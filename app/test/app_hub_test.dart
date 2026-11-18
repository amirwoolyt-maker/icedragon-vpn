import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:icedragon_vpn/app_hub/app_intelligence.dart';
import 'package:icedragon_vpn/app_hub/hub_controller.dart';
import 'package:icedragon_vpn/app_hub/hub_models.dart';
import 'package:icedragon_vpn/app_hub/hub_repository.dart';
import 'package:icedragon_vpn/app_hub/pages/app_compare_page.dart';
import 'package:icedragon_vpn/app_hub/pages/app_profile_page.dart';
import 'package:icedragon_vpn/app_hub/pages/apps_manager_page.dart';
import 'package:icedragon_vpn/app_hub/pages/assistant_hub_page.dart';
import 'package:icedragon_vpn/app_hub/pages/hub_settings_page.dart';
import 'package:icedragon_vpn/app_hub/pages/store_hub_page.dart';
import 'package:icedragon_vpn/app_hub/store_aggregator.dart';
import 'package:icedragon_vpn/app_settings.dart';
import 'package:icedragon_vpn/core/android_core.dart';
import 'package:icedragon_vpn/core/core_controller.dart';
import 'package:icedragon_vpn/core/updates.dart';
import 'package:icedragon_vpn/l10n/app_localizations.dart';
import 'package:icedragon_vpn/ui/mobile_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show FakeApi;

class _FakeHubPlatform implements HubPlatform {
  final List<String> launched = [];
  final List<String> uninstalled = [];
  final List<String> openedSettings = [];
  final List<(String, String)> openedStores = [];
  final List<String> shared = [];
  final Map<String, String> secrets = {};
  final String dirPath;

  _FakeHubPlatform({this.dirPath = ''});

  bool launchReturn = true;
  bool uninstallReturn = true;
  Future<bool> Function(String package)? onUninstall;
  AppRouting routingState = AppRouting(
    onlyChosen: false,
    bypass: {},
    only: {},
    suggested: {},
  );

  List<InstalledAppDetail> apps = [
    InstalledAppDetail(
      package: 'com.picsart.studio',
      label: 'Picsart',
      versionName: '20.0.0',
      versionCode: 2000,
      lastUpdateTime: DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch,
      apkBytes: 95 * 1024 * 1024,
      cacheBytes: 12 * 1024 * 1024,
      minSdk: 24,
      installer: 'com.farsitel.bazaar',
      permissions: const [
        'android.permission.CAMERA',
        'android.permission.INTERNET',
      ],
      grantedPermissions: const ['android.permission.CAMERA'],
    ),
    InstalledAppDetail(
      package: 'com.niksoftware.snapseed',
      label: 'Snapseed',
      versionName: '2.22.0',
      versionCode: 222,
      lastUpdateTime: DateTime.now()
          .subtract(const Duration(days: 240))
          .millisecondsSinceEpoch,
      apkBytes: 38 * 1024 * 1024,
      minSdk: 24,
      installer: 'com.android.vending',
      permissions: const [
        'android.permission.READ_EXTERNAL_STORAGE',
      ],
    ),
    InstalledAppDetail(
      package: 'com.example.calculator',
      label: 'Simple Calc',
      versionName: '1.0.0',
      versionCode: 1,
      lastUpdateTime: DateTime.now()
          .subtract(const Duration(days: 10))
          .millisecondsSinceEpoch,
      apkBytes: 4 * 1024 * 1024,
      minSdk: 23,
      permissions: const [
        'android.permission.READ_SMS',
        'android.permission.READ_CONTACTS',
        'android.permission.ACCESS_BACKGROUND_LOCATION',
      ],
      grantedPermissions: const [
        'android.permission.READ_SMS',
        'android.permission.READ_CONTACTS',
      ],
    ),
  ];

  @override
  Future<Uint8List?> appIcon(String package) async => null;

  @override
  Future<AppRouting?> appRouting() async => routingState;

  @override
  Future<BoostReport?> boostMemory(String launchedPackage) async => BoostReport(
    beforeAvailBytes: 1800 * 1024 * 1024,
    afterAvailBytes: 2150 * 1024 * 1024,
    totalRamBytes: 8192 * 1024 * 1024,
    processesTrimmed: 0,
    launchedPackage: launchedPackage,
  );

  @override
  Future<String> dataDir() async => dirPath;

  @override
  Future<DeviceEnvironment> deviceInfo() async => const DeviceEnvironment(
    sdkInt: 34,
    androidRelease: '14',
    model: 'Pixel Test',
    totalRamBytes: 8192 * 1024 * 1024,
    availRamBytes: 2048 * 1024 * 1024,
    totalStorageBytes: 128 * 1024 * 1024 * 1024,
    freeStorageBytes: 24 * 1024 * 1024 * 1024,
    hasUsageAccess: false,
  );

  @override
  Future<List<InstalledAppDetail>> installedAppsDetailed() async => [...apps];

  @override
  Future<bool> launchApp(String package) async {
    launched.add(package);
    return launchReturn;
  }

  @override
  Future<bool> openAppSettings(String package) async {
    openedSettings.add(package);
    return true;
  }

  @override
  Future<bool> openStore(
    String package,
    String store, {
    String fallbackUrl = '',
  }) async {
    openedStores.add((package, store));
    return true;
  }

  @override
  Future<bool> openUsageAccessSettings() async => true;

  @override
  Future<void> setAppRouting(AppRouting routing, {required bool apply}) async {
    routingState = routing;
  }

  @override
  Future<bool> saveSecret(String key, String value) async {
    if (value.isEmpty) {
      secrets.remove(key);
    } else {
      secrets[key] = value;
    }
    return true;
  }

  @override
  Future<String> readSecret(String key) async => secrets[key] ?? '';

  @override
  Future<bool> shareText(String text, {String subject = ''}) async {
    shared.add(text);
    return true;
  }

  @override
  Future<bool> uninstallApp(String package) async {
    uninstalled.add(package);
    final ok = onUninstall != null
        ? await onUninstall!(package)
        : uninstallReturn;
    if (ok) {
      apps.removeWhere((a) => a.package == package);
    }
    return ok;
  }
}

class _StubStoreAggregator extends StoreAggregator {
  @override
  Future<void> enrichUnifiedApp(
    UnifiedAppResult unified, {
    String hl = 'en',
    String? proxyAddress,
  }) async {}

  @override
  Future<UnifiedAppResult> fetchUnifiedApp(
    String packageName, {
    String hl = 'en',
    String? proxyAddress,
  }) async => UnifiedAppResult(packageName: packageName);

  @override
  Future<List<AppVersionRecord>> fetchVersionHistory(
    String packageName, {
    String? proxyAddress,
    List<AppVersionRecord> localRecords = const [],
    UnifiedAppResult? unified,
  }) async => localRecords;

  @override
  Future<List<UnifiedAppResult>> fetchAppRadar({
    String hl = 'en',
    String? proxyAddress,
  }) async => const [];

  @override
  Future<MultiStoreSearchResponse> searchAcrossStores(
    String query, {
    String hl = 'en',
    String? proxyAddress,
    int limitPerStore = 12,
    int enrichTop = 8,
  }) async => const MultiStoreSearchResponse(
    results: [],
    storeReachable: {
      StoreId.googlePlay: true,
      StoreId.bazaar: true,
      StoreId.myket: true,
    },
    storeErrors: {},
  );
}

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  setUp(() {
    Updates.reset();
  });
  tearDown(() {
    Updates.reset();
  });

  test('normalizeDigits, version comparison and minSdk parsing', () {
    expect(normalizeDigits('۲.۲۶.۴۴.۷۵'), '2.26.44.75');
    expect(compareSemanticVersions('2.26.44.75', '2.25.10'), greaterThan(0));
    expect(
      isRemoteVersionNewer(
        localVersion: '20.0.0',
        localCode: 2000,
        remoteVersion: '31.1.6',
        remoteCode: 3101,
      ),
      isTrue,
    );
    expect(
      isRemoteVersionNewer(
        localVersion: '31.1.6',
        localCode: 3101,
        remoteVersion: '31.1.6',
        remoteCode: 3101,
      ),
      isFalse,
    );
    expect(parseMinSdkFromLabel('Android 7.0+'), 24);
    expect(parseMinSdkFromLabel('6.0 and up'), 23);
  });

  test('CategoryClassifier assigns multiple broad categories', () {
    const app = InstalledAppDetail(
      package: 'com.openai.chatgpt',
      label: 'ChatGPT AI Assistant',
    );
    final cats = CategoryClassifier.inferCategories(
      app: app,
      storeCategory: 'Productivity',
    );
    expect(cats, containsAll(['ai', 'productivity']));
  });

  test('Store parsers decode Bazaar, Myket and Google Play payloads', () {
    final bazaarSearch = jsonEncode({
      'singleReply': {
        'searchReply': {
          'resultRows': [
            {
              'app': {
                'packageName': 'com.picsart.studio',
                'name': 'Picsart',
                'image': 'https://s.cafebazaar.ir/icon.webp',
                'versionCode': 3000,
                'minimumSdkVersion': 23,
                'rate': 4.6,
                'price': 0,
                'priceString': 'رایگان',
                'category': 'عکاسی و ویدیو',
              },
            },
          ],
        },
      },
    });
    final bz = StoreAggregator.parseBazaarSearchJson(bazaarSearch);
    expect(bz.length, 1);
    expect(bz.first.packageName, 'com.picsart.studio');
    expect(bz.first.isFree, isTrue);
    expect(bz.first.minSdk, 23);

    const myketHtml = '''
      <html><head>
      <script type="application/ld+json">
      {"@type":"SoftwareApplication","name":"پیکس‌آرت","applicationCategory":"Photography","image":"https://myket.ir/icon.png","softwareVersion":"31.1.0","aggregateRating":{"ratingValue":"4.5","ratingCount":"1200"},"offers":{"price":"0"}}
      </script>
      </head><body>
      <table><tr><td>نسخه</td><td>۳۱.۱.۰</td></tr><tr><td>حجم</td><td>۸۵ مگابایت</td></tr></table>
      </body></html>
    ''';
    final mk = StoreAggregator.parseMyketDetailsHtml(
      'com.picsart.studio',
      myketHtml,
    );
    expect(mk, isNotNull);
    expect(mk!.versionName, '31.1.0');
    expect(mk.sizeBytes, greaterThan(80 * 1024 * 1024));

    const gpHtml = '''
      <script type="application/ld+json">
      {"@type":"SoftwareApplication","name":"Picsart AI Photo Editor","description":"Edit photos","applicationCategory":"PHOTOGRAPHY","image":"https://play-lh.googleusercontent.com/icon","author":{"name":"PicsArt"},"aggregateRating":{"ratingValue":"4.7","ratingCount":"9999"},"offers":[{"price":"0","priceCurrency":"USD"}]}
      </script>
    ''';
    final gp = StoreAggregator.parseGooglePlayDetailsHtml(
      'com.picsart.studio',
      gpHtml,
    );
    expect(gp, isNotNull);
    expect(gp!.title, 'Picsart AI Photo Editor');
    expect(gp.isFree, isTrue);

    // Unified merge deduplicates stores under ONE package
    final unified = UnifiedAppResult(packageName: 'com.picsart.studio');
    unified.mergeListing(bz.first);
    unified.mergeListing(mk);
    unified.mergeListing(gp);
    expect(unified.listings.length, 3);
    expect(unified.availableInAllThree, isTrue);
  });

  test('HubRepository persists categories, collections & share payload', () async {
    final dir = Directory.systemTemp.createTempSync('hub_repo_test_');
    try {
      final repo = await HubRepository.load(dir.path);
      repo.appCategories['com.picsart.studio'] = {'media', 'ai'};
      repo.geminiApiKey = 'test-key';
      final col = AppCollection(
        id: 'c1',
        nameEn: 'My Top',
        nameFa: 'برترین‌ها',
        items: const [
          CollectionAppEntry(
            packageName: 'com.picsart.studio',
            title: 'Picsart',
          ),
        ],
      );
      repo.collections.add(col);
      await repo.save();

      final reloaded = await HubRepository.load(dir.path);
      expect(
        reloaded.appCategories['com.picsart.studio'],
        containsAll(['media', 'ai']),
      );
      // Security: geminiApiKey is never persisted to unencrypted/backupable JSON.
      expect(reloaded.geminiApiKey, isEmpty);
      final rawDisk = File('${dir.path}/app-hub-state.json')
          .readAsStringSync();
      expect(rawDisk, isNot(contains('gemini_api_key')));
      expect(rawDisk, isNot(contains('test-key')));

      final shared = col.toShareText(fa: true);
      final imported = AppCollection.tryParseShared(shared);
      expect(imported, isNotNull);
      expect(imported!.items.first.packageName, 'com.picsart.studio');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('AppIntelligence detects large, stale, duplicate & risky apps', () {
    final platform = _FakeHubPlatform();
    final intel = AppIntelligence(stores: StoreAggregator());
    final report = intel.analyzePhone(
      device: const DeviceEnvironment(),
      apps: platform.apps,
      updateCache: {
        'com.picsart.studio': const StoreListing(
          store: StoreId.bazaar,
          packageName: 'com.picsart.studio',
          title: 'Picsart',
          versionName: '31.1.6',
          versionCode: 3116,
        ),
      },
      appCategories: {
        'com.picsart.studio': {'media'},
        'com.niksoftware.snapseed': {'media'},
        'com.example.calculator': {'tools'},
      },
    );

    expect(report.largeApps.first.package, 'com.picsart.studio');
    expect(report.outdatedApps.length, 1);
    expect(report.staleApps.any((a) => a.package == 'com.niksoftware.snapseed'), isTrue);
    expect(report.duplicateGroups.length, 1);
    expect(report.duplicateGroups.first.roleKey, 'photo_editor');
    expect(
      report.permissionAudits.any((p) => p.app.package == 'com.example.calculator'),
      isTrue,
    );
  });

  testWidgets('AppsManagerPage supports search, update badges, multi-select & launch', (
    tester,
  ) async {
    final platform = _FakeHubPlatform();
    final repo = HubRepository()
      ..updateCache['com.picsart.studio'] = const StoreListing(
        store: StoreId.bazaar,
        packageName: 'com.picsart.studio',
        title: 'Picsart',
        versionName: '31.1.6',
        versionCode: 3116,
      );
    final hub = HubController(
      platform: platform,
      stores: _StubStoreAggregator(),
      repository: repo,
    );
    addTearDown(hub.dispose);

    await tester.pumpWidget(_wrap(AppsManagerPage(hub: hub)));
    await tester.pumpAndSettle();

    expect(find.text('Picsart'), findsOneWidget);
    expect(find.text('Snapseed'), findsOneWidget);
    expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);

    // Boost & Launch
    await tester.tap(find.byIcon(Icons.rocket_launch_rounded).first);
    await tester.pumpAndSettle();
    expect(platform.launched, isNotEmpty);

    // Multi-select + Compare
    await tester.tap(find.byIcon(Icons.check_box_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picsart'));
    await tester.tap(find.text('Snapseed'));
    await tester.pumpAndSettle();
    expect(find.text('Compare'), findsOneWidget);
  });

  testWidgets('AppComparePage renders comparison table in Persian & English', (
    tester,
  ) async {
    final platform = _FakeHubPlatform();
    final hub = HubController(
      platform: platform,
      stores: _StubStoreAggregator(),
      repository: HubRepository(),
    );
    addTearDown(hub.dispose);

    await tester.pumpWidget(
      _wrap(
        AppComparePage(
          hub: hub,
          initialA: CompareTarget(
            packageName: platform.apps[0].package,
            installed: platform.apps[0],
          ),
          initialB: CompareTarget(
            packageName: platform.apps[1].package,
            installed: platform.apps[1],
          ),
        ),
        locale: const Locale('fa'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('مقایسه واقعی اپلیکیشن‌ها'), findsOneWidget);
    expect(find.text('Picsart'), findsOneWidget);
    expect(find.text('Snapseed'), findsOneWidget);
  });

  testWidgets('StoreHubPage, AssistantHubPage, and AppProfilePage render cleanly', (
    tester,
  ) async {
    final platform = _FakeHubPlatform();
    final hub = HubController(
      platform: platform,
      stores: _StubStoreAggregator(),
      repository: HubRepository(),
    );
    addTearDown(hub.dispose);

    await tester.pumpWidget(_wrap(StoreHubPage(hub: hub)));
    await tester.pumpAndSettle();
    expect(find.text('Multi-Store Hub'), findsOneWidget);

    await tester.pumpWidget(_wrap(AssistantHubPage(hub: hub)));
    await tester.pumpAndSettle();
    expect(find.text('Phone Doctor'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        AppProfilePage(
          hub: hub,
          packageName: 'com.picsart.studio',
          installed: platform.apps[0],
          initialUnified: UnifiedAppResult(
            packageName: 'com.picsart.studio',
            listings: {
              StoreId.bazaar: const StoreListing(
                store: StoreId.bazaar,
                packageName: 'com.picsart.studio',
                title: 'Picsart',
                versionName: '31.1.6',
                sizeLabel: '90 MB',
                minAndroidLabel: 'Android 6.0+',
                minSdk: 23,
              ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('App Profile'), findsOneWidget);
    expect(find.text('Picsart'), findsOneWidget);
  });

  test('Store parsers handle real Play variants, Myket card scoping & Bazaar errors', () {
    String gpDs5Html(String title, Object vBlock, {String extra = ''}) {
      final root = List<Object?>.filled(141, null, growable: true);
      root[0] = [title];
      root[140] = vBlock;
      final ds5 = jsonEncode([null, null, root]);
      return '''
        <script type="application/ld+json">
        {"@type":"SoftwareApplication","name":"$title","offers":[{"price":"0","priceCurrency":"USD"}]}
        </script>
        $extra
        <script>AF_initDataCallback({key: 'ds:5', hash: '1', data:$ds5, sideChannel: {}});</script>
      ''';
    }

    // Google Play path A1 (double-nested [1, 1, 0, 0] like live PicsArt)
    final picsArtPlayHtml = gpDs5Html(
      'Picsart',
      [
        [
          ['31.1.6'],
        ],
        [
          [
            [36],
          ],
          [
            [
              [23, '6.0'],
            ],
          ],
        ],
      ],
    );
    final picsGp = StoreAggregator.parseGooglePlayDetailsHtml(
      'com.picsart.studio',
      picsArtPlayHtml,
    );
    expect(picsGp, isNotNull);
    expect(picsGp!.versionName, '31.1.6');
    expect(picsGp.minSdk, 23);
    expect(picsGp.minAndroidLabel, 'Android 6.0+');

    // Google Play path B ([1, 0, 0] like VLC) + similarPackages
    final vlcPlayHtml = gpDs5Html(
      'VLC for Android',
      [
        [null, <Object?>[]],
        [
          [
            [26, '8.0'],
          ],
          [null, <Object?>[]],
        ],
      ],
      extra:
          '<a href="/store/apps/details?id=org.videolan.vlcbenchmark">B</a>'
          '<a href="/store/apps/details?id=org.videolan.vlc">Self</a>',
    );
    final vlcGp = StoreAggregator.parseGooglePlayDetailsHtml(
      'org.videolan.vlc',
      vlcPlayHtml,
    );
    expect(vlcGp, isNotNull);
    expect(vlcGp!.minSdk, 26);
    expect(vlcGp.minAndroidLabel, 'Android 8.0+');
    expect(vlcGp.versionName, isEmpty);
    expect(vlcGp.similarPackages, ['org.videolan.vlcbenchmark']);

    // WhatsApp-style bare [35] targetSdk array without release label must NOT become minSdk 35
    final whatsappTargetOnlyHtml = gpDs5Html('WhatsApp', [
      [null, <Object?>[]],
      [
        [
          [35],
        ],
        [null, <Object?>[]],
      ],
    ]);
    final waGp = StoreAggregator.parseGooglePlayDetailsHtml(
      'com.whatsapp',
      whatsappTargetOnlyHtml,
    );
    expect(waGp, isNotNull);
    expect(waGp!.minSdk, isNull);
    expect(waGp.minAndroidLabel, isEmpty);

    // Myket card scoping & .webp / download prefix isolation
    const myketSearchHtml = '''
      <div class="list-app"><a href="/app/org.videolan.vlc" class="app-detail-link" title="VLC for Android"><img src="https://myket.ir/asset-files/icons/large/vlc.png" title="دانلود VLC for Android"><p class="app-name">VLC for Android</p></a></div>
      <div class="list-app"><a href="/app/com.mxtech.videoplayer.ad"><img src="https://myket.ir/asset-files/icons/large/mx.png" title="دانلود MX Player"><p class="app-name">MX Player</p></a></div>
      <a href="/app/promo.webp">asset</a>
    ''';
    final mkCards = StoreAggregator.parseMyketSearchHtml(myketSearchHtml);
    expect(mkCards.length, 2);
    expect(mkCards[0].packageName, 'org.videolan.vlc');
    expect(mkCards[0].title, 'VLC for Android');
    expect(mkCards[0].isPriceKnown, isFalse);
    expect(mkCards[1].packageName, 'com.mxtech.videoplayer.ad');
    expect(mkCards[1].title, 'MX Player');

    // Myket details filters .webp and keeps price unknown when offers omitted
    const myketPartialDetails = '''
      <html><body>
      com.incomplete.app
      <a href="/app/cover.webp">bad</a>
      <a href="/app/org.videolan.vlc">VLC</a>
      </body></html>
    ''';
    final mkDet = StoreAggregator.parseMyketDetailsHtml(
      'com.incomplete.app',
      myketPartialDetails,
    );
    expect(mkDet, isNotNull);
    expect(mkDet!.isPriceKnown, isFalse);
    expect(mkDet.similarPackages, ['org.videolan.vlc']);

    // Bazaar handles API 14 cleanly and rejects HTML/malformed JSON without throwing
    final bzApi14 = StoreAggregator.parseBazaarSearchJson(
      jsonEncode({
        'singleReply': {
          'searchReply': {
            'resultRows': [
              {
                'app': {
                  'packageName': 'ir.app.oldcompat',
                  'name': 'Old Compat',
                  'minimumSdkVersion': 14,
                  'price': 0,
                },
              },
            ],
          },
        },
      }),
    );
    expect(bzApi14.single.minAndroidLabel, 'Android 4.0+');
    expect(StoreAggregator.parseBazaarSearchJson('<html>502</html>'), isEmpty);
    expect(StoreAggregator.parseBazaarDetailsJson('a.b', ''), isNull);
    expect(StoreAggregator.parseBazaarHomeJson('{invalid'), isEmpty);
  });

  test('isRemoteVersionNewer prevents ABI versionCode & Varies false positives', () {
    expect(
      isRemoteVersionNewer(
        localVersion: '2.26.1.0-arm64',
        localCode: 12000,
        remoteVersion: '2.26.1',
        remoteCode: 90012000,
      ),
      isFalse,
    );
    expect(
      isRemoteVersionNewer(
        localVersion: '2.26.0',
        localCode: 100,
        remoteVersion: '2.25.9',
        remoteCode: 900500,
      ),
      isFalse,
    );
    expect(
      isRemoteVersionNewer(
        localVersion: '3.1.0',
        localCode: 300,
        remoteVersion: 'Varies with device',
        remoteCode: 0,
      ),
      isFalse,
    );
    expect(
      isRemoteVersionNewer(
        localVersion: '2.0.5',
        localCode: 20500,
        remoteVersion: '',
        remoteCode: 10020500,
      ),
      isFalse,
    );
    expect(
      isRemoteVersionNewer(
        localVersion: '2.0.5',
        localCode: 20500,
        remoteVersion: '',
        remoteCode: 20600,
      ),
      isTrue,
    );
  });

  test('scanUpdates & autoCategorizeFromStores process all >40 / >20 user apps', () async {
    final platform = _FakeHubPlatform()
      ..apps = [
        for (var i = 0; i < 45; i++)
          InstalledAppDetail(
            package: 'com.test.app$i',
            label: 'Test App $i',
            versionName: '1.0.0',
            versionCode: 100,
            installer: 'com.android.vending',
          ),
      ];
    final stores = _CountingStoreAggregator();
    final hub = HubController(
      platform: platform,
      stores: stores,
      repository: HubRepository(),
    );
    addTearDown(hub.dispose);

    await hub.ensureLoaded();
    final updates = await hub.scanUpdates();
    expect(hub.scanTotal, 45);
    expect(hub.scanDone, 45);
    expect(stores.detailLookups.length, 45);
    expect(updates.length, 45);

    final catCount = await hub.autoCategorizeFromStores();
    expect(catCount, 45);
    expect(stores.unifiedLookups.length, 45);
  });

  testWidgets('AppComparePage shows Unknown (not Free/0) for missing remote data', (
    tester,
  ) async {
    final platform = _FakeHubPlatform();
    final hub = HubController(
      platform: platform,
      stores: _StubStoreAggregator(),
      repository: HubRepository(),
    );
    addTearDown(hub.dispose);

    await tester.pumpWidget(
      _wrap(
        AppComparePage(
          hub: hub,
          initialA: CompareTarget(
            packageName: platform.apps[0].package,
            installed: platform.apps[0],
          ),
          initialB: const CompareTarget(
            packageName: 'com.remote.unknown',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Unknown'), findsWidgets);
    expect(find.text('Free'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('Sequential batch uninstall, cancel handling, VPN bypass toggle & launch error', (
    tester,
  ) async {
    final order = <String>[];
    var inFlight = 0;
    var maxConcurrent = 0;
    final platform = _FakeHubPlatform()
      ..onUninstall = (pkg) async {
        inFlight++;
        if (inFlight > maxConcurrent) maxConcurrent = inFlight;
        order.add(pkg);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        inFlight--;
        return pkg != 'com.example.calculator';
      };
    final repo = HubRepository()
      ..updateCache['com.picsart.studio'] = const StoreListing(
        store: StoreId.bazaar,
        packageName: 'com.picsart.studio',
        title: 'Picsart',
        versionName: '31.1.6',
      );
    final hub = HubController(
      platform: platform,
      stores: _StubStoreAggregator(),
      repository: repo,
    );
    addTearDown(hub.dispose);

    await hub.ensureLoaded();
    await hub.runDiagnostics();
    expect(hub.assistantReport!.largeApps.first.package, 'com.picsart.studio');

    await tester.pumpWidget(_wrap(AppsManagerPage(hub: hub)));
    await tester.pumpAndSettle();

    // Verify failed launch shows honest failure snackbar
    platform.launchReturn = false;
    await tester.tap(find.byIcon(Icons.rocket_launch_rounded).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not launch'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Multi-select VPN bypass add AND remove
    await tester.tap(find.byIcon(Icons.check_box_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picsart'));
    await tester.tap(find.text('Snapseed'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('+ VPN Bypass'));
    await tester.tap(find.text('+ VPN Bypass'));
    await tester.pumpAndSettle();
    expect(
      platform.routingState.bypass,
      containsAll(['com.picsart.studio', 'com.niksoftware.snapseed']),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.ensureVisible(find.text('- VPN Bypass'));
    await tester.tap(find.text('- VPN Bypass'));
    await tester.pumpAndSettle();
    expect(platform.routingState.bypass, isEmpty);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Sequential batch uninstall removes Picsart & Snapseed and prunes caches
    final uninstallBtn = find.widgetWithText(OutlinedButton, 'Uninstall');
    await tester.ensureVisible(uninstallBtn);
    await tester.tap(uninstallBtn);
    await tester.pumpAndSettle();
    expect(maxConcurrent, 1);
    expect(order, unorderedEquals(['com.niksoftware.snapseed', 'com.picsart.studio']));
    expect(hub.updateAvailablePackages, isEmpty);
    expect(
      hub.assistantReport!.largeApps.any((a) => a.package == 'com.picsart.studio'),
      isFalse,
    );
    expect(find.text('Picsart'), findsNothing);
    expect(find.text('2 of 2 app(s) uninstalled'), findsOneWidget);
  });

  testWidgets('Collections error, AI error, HubSettings UI & Keystore + x-goog-api-key security', (
    tester,
  ) async {
    print('DEBUG: 1 start');
    // Legacy plaintext key migration scrubs JSON and moves key into Keystore secret
    final dir = Directory.systemTemp.createTempSync('hub_sec_test_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final legacyFile = File('${dir.path}/app-hub-state.json')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'gemini_api_key': 'AIzaLegacyKey99'}));

    final platform = _FakeHubPlatform(dirPath: dir.path);
    final stores = _FailingStoreAggregator();
    final hub = HubController(
      platform: platform,
      stores: stores,
      intelligence: AppIntelligence(
        stores: stores,
        clientFactory: () => _FakeGeminiHttpClient('{}'),
      ),
    );
    addTearDown(hub.dispose);

    print('DEBUG: 2 before ensureLoaded');
    await hub.ensureLoaded();
    print('DEBUG: 3 after ensureLoaded');
    expect(hub.repo.geminiApiKey, 'AIzaLegacyKey99');
    expect(platform.secrets['gemini_api_key'], 'AIzaLegacyKey99');
    expect(legacyFile.readAsStringSync(), isNot(contains('AIzaLegacyKey99')));

    // Mock client proves x-goog-api-key header is used without ?key= query string
    final fakeClient = _FakeGeminiHttpClient(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'summary': 'Try Snapseed',
                    'search_query': 'photo editor',
                    'packages': ['com.niksoftware.snapseed'],
                  }),
                },
              ],
            },
          },
        ],
      }),
    );

    final okIntel = AppIntelligence(
      stores: _StubStoreAggregator(),
      clientFactory: () => fakeClient,
    );
    print('DEBUG: 4 before recommendForNeed');
    final rec = await okIntel.recommendForNeed(
      'edit photos',
      device: const DeviceEnvironment(),
      fa: false,
      geminiApiKey: 'AIzaTestSecret123',
    );
    print('DEBUG: 5 after recommendForNeed');
    expect(rec.usedGemini, isTrue);
    expect(fakeClient.capturedUri?.queryParameters.containsKey('key'), isFalse);
    expect(fakeClient.capturedUri.toString(), isNot(contains('AIzaTestSecret123')));
    expect(fakeClient.capturedHeaders?.value('x-goog-api-key'), 'AIzaTestSecret123');

    // Failing store sets lastError and AssistantHubPage displays real error + invalid collection error
    await hub.setGeminiApiKey('');
    print('DEBUG: 6 before runAiRecommendation');
    await hub.runAiRecommendation('photo editor', fa: false);
    print('DEBUG: 7 after runAiRecommendation');
    expect(hub.lastError, contains('offline store error'));

    print('DEBUG: 8 before pump AssistantHubPage');
    await tester.pumpWidget(_wrap(AssistantHubPage(hub: hub)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    print('DEBUG: 9 after pump AssistantHubPage');

    // Switch to Collections sub-tab and trigger invalid import error
    await tester.tap(find.text('Collections'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    print('DEBUG: 10 after tap Collections');
    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    print('DEBUG: 11 after tap download');
    await tester.enterText(find.byType(TextField).last, 'invalid-collection-data');
    await tester.tap(find.text('Apply'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    print('DEBUG: 12 after tap Apply');
    expect(
      find.text('Invalid or corrupted collection code. Paste a valid IceDragon code or JSON.'),
      findsOneWidget,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    print('DEBUG: 13 after tap Cancel');

    // Switch to AI sub-tab and verify visible error banner
    await tester.tap(find.text('App Intelligence'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    print('DEBUG: 14 after tap App Intelligence');
    expect(find.textContaining('Recommendation failed:'), findsOneWidget);

    // HubSettingsPage updates Delete visibility on typing
    await hub.setGeminiApiKey('');
    print('DEBUG: 15 before pump HubSettingsPage');
    await tester.pumpWidget(
      _wrap(HubSettingsPage(hub: hub, settings: AppSettings())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    print('DEBUG: 16 after pump HubSettingsPage');
    await tester.ensureVisible(find.byType(TextField));
    expect(find.text('Delete'), findsNothing);
    await tester.enterText(find.byType(TextField), 'AIzaTypedKey');
    await tester.pump();
    print('DEBUG: 17 after enterText AIzaTypedKey');
    expect(find.text('Delete'), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    print('DEBUG: 18 done test body');
  }, timeout: const Timeout(Duration(seconds: 5)));

  testWidgets('MobileShell switches tabs and preserves existing VPN controls', (
    tester,
  ) async {
    Updates.reset();
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = FakeApi();
    final core = CoreController(
      () async => api,
      pollInterval: const Duration(hours: 1),
      turnOn: (on) async => api.on = on,
    );
    final settings = AppSettings();

    await tester.pumpWidget(
      _wrap(MobileShell(core: core, settings: settings, banner: null)),
    );
    core.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    for (final (idx, icon) in [
      (1, Icons.settings_outlined),
      (0, Icons.home_outlined),
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        idx,
      );
    }

    await core.setOn(true);
    expect(api.on, isTrue);

    await tester.pumpWidget(const SizedBox());
    core.dispose();
    Updates.reset();
  });
}

class _CountingStoreAggregator extends StoreAggregator {
  final List<String> detailLookups = [];
  final List<String> unifiedLookups = [];

  @override
  Future<StoreListing?> fetchBazaarDetails(
    String packageName, {
    String? proxyAddress,
  }) async => null;

  @override
  Future<StoreListing?> fetchMyketDetails(
    String packageName, {
    String? proxyAddress,
  }) async => null;

  @override
  Future<StoreListing?> fetchGooglePlayDetails(
    String packageName, {
    String hl = 'en',
    String? proxyAddress,
  }) async {
    detailLookups.add(packageName);
    return StoreListing(
      store: StoreId.googlePlay,
      packageName: packageName,
      title: packageName,
      versionName: '2.0.0',
      versionCode: 200,
    );
  }

  @override
  Future<UnifiedAppResult> fetchUnifiedApp(
    String packageName, {
    String hl = 'en',
    String? proxyAddress,
  }) async {
    unifiedLookups.add(packageName);
    return UnifiedAppResult(
      packageName: packageName,
      listings: {
        StoreId.googlePlay: StoreListing(
          store: StoreId.googlePlay,
          packageName: packageName,
          title: packageName,
          category: 'Productivity',
        ),
      },
    );
  }
}

class _FailingStoreAggregator extends _StubStoreAggregator {
  @override
  Future<MultiStoreSearchResponse> searchAcrossStores(
    String query, {
    String hl = 'en',
    String? proxyAddress,
    int limitPerStore = 12,
    int enrichTop = 8,
  }) async => throw const HttpException('offline store error');
}

extension on UnifiedAppResult {
  bool get availableInAllThree =>
      listings.containsKey(StoreId.googlePlay) &&
      listings.containsKey(StoreId.bazaar) &&
      listings.containsKey(StoreId.myket);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, Object> _headers = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = value;
  }

  @override
  String? value(String name) => _headers[name.toLowerCase()]?.toString();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.uri, this.responseBody);
  @override
  final Uri uri;
  final String responseBody;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  void add(List<int> data) {}

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse(responseBody);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeHttpClientResponse(this.body);
  final String body;

  @override
  int get statusCode => 200;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeGeminiHttpClient implements HttpClient {
  _FakeGeminiHttpClient(this.responseBody);
  final String responseBody;
  Uri? capturedUri;
  _FakeHttpHeaders? capturedHeaders;

  @override
  Duration? connectionTimeout;

  @override
  String Function(Uri url)? findProxy;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    capturedUri = url;
    final req = _FakeHttpClientRequest(url, responseBody);
    capturedHeaders = req.headers as _FakeHttpHeaders;
    return req;
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
