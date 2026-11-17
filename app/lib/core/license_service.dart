import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app_info.dart' show proLicensingApi;
import '../app_settings.dart';
import 'android_core.dart';

/// Server-authoritative license synchronization service.
///
/// Validates subscription status directly against Cloudflare KV / Telegram bot,
/// extracts trusted atomic server time from HTTP Date headers to prevent
/// device clock tampering (rollback attacks), and keeps Android native QS tiles in sync.
class LicenseService {
  static bool _syncing = false;

  /// Synchronizes subscription status with the remote licensing authority.
  /// If the code expired or was revoked in Telegram, [settings.proActive] is revoked immediately.
  static Future<void> syncStatus(AppSettings settings) async {
    final code = settings.proLicenseCode.trim().toUpperCase();
    if (code.isEmpty) {
      if (settings.proActive) {
        settings.update(proActive: false, proDaysLeft: 0);
      }
      return;
    }

    if (_syncing) return;
    _syncing = true;

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final uri = Uri.parse('$proLicensingApi/status?code=${Uri.encodeComponent(code)}&device_id=${Uri.encodeComponent(settings.deviceId)}');
      final req = await client.getUrl(uri);
      final res = await req.close();

      // Extract trusted network time from server Date header
      final dateHeader = res.headers.value(HttpHeaders.dateHeader);
      DateTime? serverDate;
      if (dateHeader != null && dateHeader.isNotEmpty) {
        try {
          serverDate = HttpDate.parse(dateHeader);
        } catch (_) {}
      }

      if (serverDate != null) {
        // Enforce anti-rollback: monotonic time progression
        final lastKnown = DateTime.tryParse(settings.lastKnownServerTime);
        if (lastKnown == null || serverDate.isAfter(lastKnown)) {
          settings.update(lastKnownServerTime: serverDate.toIso8601String());
        }
      }

      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, Object?>?;

        if (json != null && json['ok'] == true && json['active'] == true) {
          final plan = json['plan'] as String? ?? settings.proPlanName;
          final expiresAt = json['expires_at'] as String? ?? settings.proExpiresAt;
          final daysLeft = json['days_left'] as int? ?? settings.proDaysLeft;
          final isLifetime = json['is_lifetime'] == true;

          settings.update(
            proActive: true,
            proPlanName: plan,
            proExpiresAt: expiresAt,
            proDaysLeft: daysLeft,
            proIsLifetime: isLifetime,
          );

          if (Platform.isAndroid) {
            unawaited(AndroidCore.setProActive(
              true,
              expiresAt: expiresAt,
              isLifetime: isLifetime,
              lastKnownServerTimeMillis: serverDate?.millisecondsSinceEpoch ?? 0,
            ));
          }
        } else if (json != null && (json['ok'] == false || json['active'] == false)) {
          // Subscription revoked or expired on server / Telegram bot
          settings.update(
            proActive: false,
            proDaysLeft: 0,
          );

          if (Platform.isAndroid) {
            unawaited(AndroidCore.setProActive(
              false,
              expiresAt: '',
              isLifetime: false,
              lastKnownServerTimeMillis: serverDate?.millisecondsSinceEpoch ?? 0,
            ));
          }
        }
      }
    } catch (_) {
      // Offline fallback: enforce anti-rollback local expiry
      _enforceLocalAntiRollback(settings);
    } finally {
      _syncing = false;
    }
  }

  /// Evaluates local expiry using the highest observed server time to detect clock rollbacks.
  static void _enforceLocalAntiRollback(AppSettings settings) {
    if (!settings.proActive || settings.proIsLifetime || settings.proExpiresAt.isEmpty) {
      return;
    }

    var now = DateTime.now();
    if (settings.lastKnownServerTime.isNotEmpty) {
      final lastKnown = DateTime.tryParse(settings.lastKnownServerTime);
      if (lastKnown != null && now.isBefore(lastKnown)) {
        // Clock tampering detected: device clock is before last verified internet time!
        now = lastKnown;
      }
    }

    final exp = DateTime.tryParse(settings.proExpiresAt);
    if (exp != null && now.isAfter(exp)) {
      settings.update(proActive: false, proDaysLeft: 0);
      if (Platform.isAndroid) {
        unawaited(AndroidCore.setProActive(
          false,
          expiresAt: settings.proExpiresAt,
          isLifetime: false,
        ));
      }
    }
  }
}
