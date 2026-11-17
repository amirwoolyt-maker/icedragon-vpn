import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// What the window's close button does.
enum CloseAction { ask, tray, quit }

/// How a new account signs in: with the email and password form or through
/// the in-app browser on supported platforms.
enum SignInMethod { api, browser }

/// The app's own preferences (language, theme, close button), kept in
/// `app-settings.json` in the data folder beside the core's files. The VPN
/// settings belong to the core.
class AppSettings extends ChangeNotifier {
  AppSettings({this.file});

  final File? file;

  /// A language code (`en`, `fa`, `zh`, `ru`), or empty for the system
  /// language.
  String language = '';
  ThemeMode themeMode = ThemeMode.system;
  CloseAction closeAction = CloseAction.ask;

  /// True until the user finished the welcome page.
  bool firstRun = false;

  /// Android's first-run routing suggestion, prepared before the welcome
  /// page opens. Empty means no region; null keeps desktop suggestions.
  /// This is derived locally for this run and is not saved as a preference.
  String? firstRunRegion;

  /// Shows the public IP (the address websites see). Off by default: the
  /// location is shown by its country either way.
  bool showPublicIp = false;

  /// How a new account signs in (the accounts page's row).
  SignInMethod signInMethod = SignInMethod.api;

  /// When the user closed the "account running out" notice; it stays away
  /// for a day after.
  DateTime? lowQuotaDismissedAt;

  /// The newer version whose notice the user closed; a later one shows.
  String dismissedUpdate = '';

  /// The last successful look for a newer version, and the newer version it
  /// found ("" for none) with its page, so the notice outlasts a restart.
  DateTime? updateCheckedAt;
  String updateVersion = '';
  String updateUrl = '';
  Map<String, Object?> updateDetails = const {};
  List<Map<String, Object?>> announcementCache = const [];
  Map<String, int> announcementSeen = const {};
  Map<String, int> announcementAcknowledged = const {};
  Future<void> _saveTail = Future.value();

  /// Starts the app in the tray when the user signs in to Windows; on
  /// unless the user turned it off.
  bool autostart = true;

  /// Connects by itself when started with the computer ([autostart]); off
  /// until the user turns it on. The core decides how (Daemon.AutoConnect).
  bool autoConnect = false;

  /// The home page's card when TUN mode refused a program's call or game
  /// (UDP); on unless the user turned it off.
  bool udpNotice = true;

  /// The columns the Logs page's Connections tab hides (ConnectionsView):
  /// at first all but the time, the destination, the rule, and the
  /// protocol. Kept in this file.
  Set<String> hiddenConnectionColumns = {'inbound', 'traffic', 'duration'};

  /// Pinned favorite server country codes for 1-tap switching on mobile home.
  List<String> favoriteCountries = const [];

  /// User-named DNS resolvers available in Settings. These configure the
  /// core's own resolver, not the operating system's resolver.
  List<Map<String, Object?>> customDnsProviders = const [];

  /// Home-screen presentation mode; DNS does not start the VPN tunnel.
  String homeConnectionMode = 'vpn';
  bool homeDnsEnabled = false;
  String homeDnsName = '';
  List<String> homeDnsServers = const [];
  String dnsTestDay = '';
  int dnsTestCount = 0;

  /// Shows the live download/upload speed chart card on mobile home.
  bool showSpeedChart = true;

  /// Pro VIP subscription fields
  bool proActive = false;
  String proLicenseCode = '';
  String proPlanName = '';
  String proExpiresAt = '';
  int proDaysLeft = 0;
  bool proIsLifetime = false;
  String deviceId = '';

  /// VIP Features
  bool autoSwitchDns = false;
  int connectionTimerEndMillis = 0;
  List<Map<String, Object?>> networkTimeMachineHistory = const [];

  /// Monotonic trusted server time (ISO 8601) to prevent device clock rollback attacks
  String lastKnownServerTime = '';

  /// Bandwidth / Speed Limiter
  bool speedLimitEnabled = false;
  int speedLimitKbps = 0; // 0 = Unlimited

  /// The app's languages, in the order the language menus list them.
  /// 'zh' is Simplified and 'zh_Hant' Traditional Chinese.
  static const supportedLanguages = [
    'en',
    'fa',
    'zh',
    'zh_Hant',
    'ru',
    'tr',
    'ar',
    // The rest by their own names.
    'az',
    'id',
    'es',
    'fr',
    'hu',
    'pt',
    'vi',
    'bn',
  ];

  /// Languages written right to left.
  static const rtlLanguages = {'fa', 'ar'};

  /// The locale of a language code such as 'fa' or 'zh_Hant'.
  static Locale localeOf(String language) {
    final parts = language.split('_');
    return parts.length == 2
        ? Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1])
        : Locale(language);
  }

  /// The app language for the system's [locale]: Traditional Chinese for
  /// the Hant script or Taiwan, Hong Kong, and Macau; else the language
  /// when the app has it; else English.
  static String languageFor(Locale locale) {
    if (locale.languageCode == 'zh') {
      final traditional =
          locale.scriptCode == 'Hant' ||
          const {'TW', 'HK', 'MO'}.contains(locale.countryCode);
      return traditional ? 'zh_Hant' : 'zh';
    }
    return supportedLanguages.contains(locale.languageCode)
        ? locale.languageCode
        : 'en';
  }

  /// The app language for the system's preferred [locales], in order: the
  /// first one the app has; else English (not Flutter's default, the first
  /// language it was built with).
  static String languageForList(List<Locale>? locales) {
    for (final locale in locales ?? const <Locale>[]) {
      if (locale.languageCode == 'zh' ||
          supportedLanguages.contains(locale.languageCode)) {
        return languageFor(locale);
      }
    }
    return 'en';
  }

  /// The core's routing regions (`routing.region`); empty is none.
  static const regions = ['ir', 'cn', 'ru', 'af', 'tr', 'id', 'br', ''];

  /// Prefer the current network country, then the SIM's country, then the
  /// system country. A known unsupported country means no regional bypass:
  /// an Iranian SIM roaming in another country must not imply Iran.
  static String regionForCountries(Iterable<String?> countries) {
    for (final value in countries) {
      final country = (value ?? '').trim().toLowerCase();
      if (!RegExp(r'^[a-z]{2}$').hasMatch(country)) continue;
      return regions.contains(country) ? country : '';
    }
    return '';
  }

  Locale? get locale => language.isEmpty ? null : localeOf(language);

  /// The routing region most users of [language] want: Persian is Iran,
  /// Chinese China, Russian Russia; null when a language says nothing.
  static String? regionForLanguage(String language) => switch (language) {
    'fa' => 'ir',
    'zh' => 'cn',
    'ru' => 'ru',
    'id' => 'id',
    'tr' => 'tr',
    'pt' => 'br',
    _ => null,
  };

  /// The region to offer first: from [language], else from the system's
  /// country ([countryCode], such as IR), else none.
  static String suggestedRegion(String language, String? countryCode) {
    final byLanguage = regionForLanguage(language);
    if (byLanguage != null) return byLanguage;
    final country = (countryCode ?? '').toLowerCase();
    return regions.contains(country) ? country : '';
  }

  static Future<AppSettings> load(String dataDir) async {
    final s = AppSettings(
      file: File('$dataDir${Platform.pathSeparator}app-settings.json'),
    );
    try {
      final j = jsonDecode(await s.file!.readAsString());
      if (j is Map<String, Object?>) {
        if (j['language'] case final String l
            when supportedLanguages.contains(l)) {
          s.language = l;
        }
        s.themeMode =
            ThemeMode.values.asNameMap()[j['theme']] ?? ThemeMode.system;
        s.closeAction =
            CloseAction.values.asNameMap()[j['close']] ?? CloseAction.ask;
        s.firstRun = j['welcome_done'] != true;
        s.showPublicIp = j['show_public_ip'] == true;
        s.signInMethod =
            SignInMethod.values.asNameMap()[j['signin_method']] ??
            s.signInMethod;
        if (j['dismissed_update'] case final String v) s.dismissedUpdate = v;
        if (j['update_version'] case final String v) s.updateVersion = v;
        if (j['update_url'] case final String v) s.updateUrl = v;
        if (j['update_details'] case final Map<String, Object?> v) {
          s.updateDetails = v;
        }
        if (j['announcement_cache'] case final List<Object?> v) {
          s.announcementCache = v.whereType<Map<String, Object?>>().toList();
        }
        Map<String, int> history(Object? v) => v is Map<String, Object?>
            ? {
                for (final e in v.entries)
                  if (e.value is int) e.key: e.value! as int,
              }
            : {};
        s.announcementSeen = history(j['announcement_seen']);
        s.announcementAcknowledged = history(j['announcement_acknowledged']);
        s.updateCheckedAt = switch (j['update_checked_at']) {
          final String t => DateTime.tryParse(t),
          _ => null,
        };
        s.lowQuotaDismissedAt = switch (j['low_quota_dismissed_at']) {
          final String t => DateTime.tryParse(t),
          _ => null,
        };
        s.autostart = j['autostart'] != false;
        s.autoConnect = j['auto_connect'] == true;
        s.udpNotice = j['udp_notice'] != false;
        if (j['hidden_connection_columns'] case final List<Object?> v) {
          s.hiddenConnectionColumns = {...v.whereType<String>()};
        }
        if (j['favorite_countries'] case final List<Object?> v) {
          s.favoriteCountries = [
            for (final code in v.whereType<String>())
              if (code.trim().isNotEmpty) code.trim().toUpperCase(),
          ];
        }
        if (j['custom_dns_providers'] case final List<Object?> v) {
          s.customDnsProviders = [
            for (final item in v)
              if (item is Map<String, Object?> &&
                  item['name'] is String &&
                  item['servers'] is List<Object?>)
                {
                  'name': item['name']! as String,
                  'servers': [
                    for (final server in item['servers']! as List<Object?>)
                      if (server is String && server.trim().isNotEmpty)
                        server.trim(),
                  ],
                },
          ];
        }
        if (j['home_connection_mode'] == 'dns') s.homeConnectionMode = 'dns';
        s.dnsTestDay = j['dns_test_day'] as String? ?? '';
        s.dnsTestCount = j['dns_test_count'] as int? ?? 0;
        s.homeDnsEnabled = j['home_dns_enabled'] == true;
        if (j['home_dns_name'] case final String name) s.homeDnsName = name;
        if (j['home_dns_servers'] case final List<Object?> servers) {
          s.homeDnsServers = servers.whereType<String>().toList();
        }
        s.showSpeedChart = j['show_speed_chart'] != false;
        s.proLicenseCode = j['pro_license_code'] as String? ?? '';
        s.proPlanName = j['pro_plan_name'] as String? ?? '';
        s.proExpiresAt = j['pro_expires_at'] as String? ?? '';
        s.proDaysLeft = j['pro_days_left'] as int? ?? 0;
        s.proIsLifetime = j['pro_is_lifetime'] == true;
        s.deviceId = j['device_id'] as String? ?? '';
        s.autoSwitchDns = j['auto_switch_dns'] == true;
        s.connectionTimerEndMillis = j['conn_timer_end'] as int? ?? 0;
        s.lastKnownServerTime = j['last_known_server_time'] as String? ?? '';
        s.speedLimitEnabled = j['speed_limit_enabled'] == true;
        s.speedLimitKbps = j['speed_limit_kbps'] as int? ?? 0;

        // Security check: proActive requires a non-empty license code and valid expiration.
        var active = j['pro_active'] == true && s.proLicenseCode.trim().isNotEmpty;
        if (active && !s.proIsLifetime && s.proExpiresAt.isNotEmpty) {
          var now = DateTime.now();
          if (s.lastKnownServerTime.isNotEmpty) {
            final lastKnown = DateTime.tryParse(s.lastKnownServerTime);
            if (lastKnown != null && now.isBefore(lastKnown)) {
              now = lastKnown;
            }
          }
          final exp = DateTime.tryParse(s.proExpiresAt);
          if (exp != null && now.isAfter(exp)) {
            active = false;
            s.proDaysLeft = 0;
          }
        }
        s.proActive = active;
        if (j['time_machine_history'] case final List<Object?> h) {
          s.networkTimeMachineHistory = [
            for (final item in h)
              if (item is Map<String, Object?>) item,
          ];
        }
        var generatedDevice = false;
        if (s.deviceId.isEmpty) {
          s.deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}';
          generatedDevice = true;
        }
        if (generatedDevice) {
          unawaited(s._save());
        }
      }
    } on FileSystemException {
      // First run: defaults, and the welcome page.
      s.firstRun = true;
      s.deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}';
      unawaited(s._save());
    } on FormatException {
      // A broken file: defaults, rewritten on the next change.
      s.deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}';
      unawaited(s._save());
    }
    return s;
  }

  Future<void> reload() async {
    final f = file;
    if (f == null) return;
    try {
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString());
      if (j is Map<String, Object?>) {
        if (j['home_connection_mode'] is String) {
          homeConnectionMode = j['home_connection_mode'] as String;
        }
        if (j['home_dns_enabled'] is bool) {
          homeDnsEnabled = j['home_dns_enabled'] as bool;
        }
        if (j['home_dns_name'] case final String name) {
          homeDnsName = name;
        }
        if (j['home_dns_servers'] case final List<Object?> servers) {
          homeDnsServers = servers.whereType<String>().toList();
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void update({
    String? language,
    ThemeMode? themeMode,
    CloseAction? closeAction,
    SignInMethod? signInMethod,
    bool? firstRun,
    bool? showPublicIp,
    DateTime? lowQuotaDismissedAt,
    String? dismissedUpdate,
    DateTime? updateCheckedAt,
    String? updateVersion,
    String? updateUrl,
    Map<String, Object?>? updateDetails,
    List<Map<String, Object?>>? announcementCache,
    Map<String, int>? announcementSeen,
    Map<String, int>? announcementAcknowledged,
    bool? autostart,
    bool? autoConnect,
    bool? udpNotice,
    Set<String>? hiddenConnectionColumns,
    List<String>? favoriteCountries,
    List<Map<String, Object?>>? customDnsProviders,
    String? homeConnectionMode,
    String? dnsTestDay,
    int? dnsTestCount,
    bool? homeDnsEnabled,
    String? homeDnsName,
    List<String>? homeDnsServers,
    bool? showSpeedChart,
    bool? proActive,
    String? proLicenseCode,
    String? proPlanName,
    String? proExpiresAt,
    int? proDaysLeft,
    bool? proIsLifetime,
    String? deviceId,
    bool? autoSwitchDns,
    int? connectionTimerEndMillis,
    String? lastKnownServerTime,
    bool? speedLimitEnabled,
    int? speedLimitKbps,
    List<Map<String, Object?>>? networkTimeMachineHistory,
  }) {
    this.favoriteCountries = favoriteCountries ?? this.favoriteCountries;
    this.customDnsProviders = customDnsProviders ?? this.customDnsProviders;
    this.homeConnectionMode = homeConnectionMode ?? this.homeConnectionMode;
    this.dnsTestDay = dnsTestDay ?? this.dnsTestDay;
    this.dnsTestCount = dnsTestCount ?? this.dnsTestCount;
    this.homeDnsEnabled = homeDnsEnabled ?? this.homeDnsEnabled;
    this.homeDnsName = homeDnsName ?? this.homeDnsName;
    this.homeDnsServers = homeDnsServers ?? this.homeDnsServers;
    this.showSpeedChart = showSpeedChart ?? this.showSpeedChart;
    this.proLicenseCode = proLicenseCode ?? this.proLicenseCode;
    this.proPlanName = proPlanName ?? this.proPlanName;
    this.proExpiresAt = proExpiresAt ?? this.proExpiresAt;
    this.proDaysLeft = proDaysLeft ?? this.proDaysLeft;
    this.proIsLifetime = proIsLifetime ?? this.proIsLifetime;
    this.lastKnownServerTime = lastKnownServerTime ?? this.lastKnownServerTime;
    this.speedLimitEnabled = speedLimitEnabled ?? this.speedLimitEnabled;
    this.speedLimitKbps = speedLimitKbps ?? this.speedLimitKbps;
    if (proActive != null) {
      var effective = proActive;
      final code = this.proLicenseCode.trim();
      if (effective && code.isEmpty) {
        effective = false;
      }
      if (effective && !this.proIsLifetime && this.proExpiresAt.isNotEmpty) {
        var now = DateTime.now();
        if (this.lastKnownServerTime.isNotEmpty) {
          final lastKnown = DateTime.tryParse(this.lastKnownServerTime);
          if (lastKnown != null && now.isBefore(lastKnown)) {
            now = lastKnown;
          }
        }
        final exp = DateTime.tryParse(this.proExpiresAt);
        if (exp != null && now.isAfter(exp)) {
          effective = false;
          this.proDaysLeft = 0;
        }
      }
      this.proActive = effective;
    }
    this.deviceId = deviceId ?? this.deviceId;
    this.autoSwitchDns = autoSwitchDns ?? this.autoSwitchDns;
    this.connectionTimerEndMillis = connectionTimerEndMillis ?? this.connectionTimerEndMillis;
    this.networkTimeMachineHistory = networkTimeMachineHistory ?? this.networkTimeMachineHistory;
    this.hiddenConnectionColumns =
        hiddenConnectionColumns ?? this.hiddenConnectionColumns;
    this.udpNotice = udpNotice ?? this.udpNotice;
    this.autostart = autostart ?? this.autostart;
    this.autoConnect = autoConnect ?? this.autoConnect;
    this.showPublicIp = showPublicIp ?? this.showPublicIp;
    this.lowQuotaDismissedAt = lowQuotaDismissedAt ?? this.lowQuotaDismissedAt;
    this.dismissedUpdate = dismissedUpdate ?? this.dismissedUpdate;
    this.updateCheckedAt = updateCheckedAt ?? this.updateCheckedAt;
    this.updateVersion = updateVersion ?? this.updateVersion;
    this.updateUrl = updateUrl ?? this.updateUrl;
    this.updateDetails = updateDetails ?? this.updateDetails;
    this.announcementCache = announcementCache ?? this.announcementCache;
    this.announcementSeen = announcementSeen ?? this.announcementSeen;
    this.announcementAcknowledged =
        announcementAcknowledged ?? this.announcementAcknowledged;
    this.firstRun = firstRun ?? this.firstRun;
    this.language = language ?? this.language;
    this.themeMode = themeMode ?? this.themeMode;
    this.closeAction = closeAction ?? this.closeAction;
    this.signInMethod = signInMethod ?? this.signInMethod;
    notifyListeners();
    _saveTail = _saveTail.then((_) => _save());
  }

  Future<void> _save() async {
    final f = file;
    if (f == null) return;
    try {
      await f.parent.create(recursive: true);
      await f.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'language': language,
          'theme': themeMode.name,
          'close': closeAction.name,
          'signin_method': signInMethod.name,
          'welcome_done': !firstRun,
          'show_public_ip': showPublicIp,
          'low_quota_dismissed_at': lowQuotaDismissedAt?.toIso8601String(),
          'dismissed_update': dismissedUpdate,
          'update_checked_at': updateCheckedAt?.toIso8601String(),
          'update_version': updateVersion,
          'update_url': updateUrl,
          'update_details': updateDetails,
          'announcement_cache': announcementCache,
          'announcement_seen': announcementSeen,
          'announcement_acknowledged': announcementAcknowledged,
          'autostart': autostart,
          'auto_connect': autoConnect,
          'udp_notice': udpNotice,
          'hidden_connection_columns': hiddenConnectionColumns.toList(),
          'favorite_countries': favoriteCountries,
          'custom_dns_providers': customDnsProviders,
          'home_connection_mode': homeConnectionMode,
          'dns_test_day': dnsTestDay,
          'dns_test_count': dnsTestCount,
          'home_dns_enabled': homeDnsEnabled,
          'home_dns_name': homeDnsName,
          'home_dns_servers': homeDnsServers,
          'show_speed_chart': showSpeedChart,
          'pro_active': proActive,
          'pro_license_code': proLicenseCode,
          'pro_plan_name': proPlanName,
          'pro_expires_at': proExpiresAt,
          'pro_days_left': proDaysLeft,
          'pro_is_lifetime': proIsLifetime,
          'device_id': deviceId,
          'auto_switch_dns': autoSwitchDns,
          'conn_timer_end': connectionTimerEndMillis,
          'last_known_server_time': lastKnownServerTime,
          'speed_limit_enabled': speedLimitEnabled,
          'speed_limit_kbps': speedLimitKbps,
          'time_machine_history': networkTimeMachineHistory,
        }),
      );
    } on FileSystemException {
      // Not fatal: the choice holds until the app quits.
    }
  }

  bool isFavoriteCountry(String code) {
    final upper = code.trim().toUpperCase();
    return upper.isNotEmpty && favoriteCountries.contains(upper);
  }

  void toggleFavoriteCountry(String code) {
    final upper = code.trim().toUpperCase();
    if (upper.isEmpty || upper == 'REC' || upper == 'FASTEST') return;
    final next = [...favoriteCountries];
    if (!next.remove(upper)) {
      next.add(upper);
    }
    update(favoriteCountries: next);
  }
}
