import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_controller.dart';
import 'mobile_strings.dart';
import 'mobile_theme.dart';

/// Network Time Machine: records, compares, and restores verified working
/// connection combinations per network (Wi-Fi / Cellular).
class NetworkTimeMachinePage extends StatefulWidget {
  const NetworkTimeMachinePage({
    super.key,
    required this.settings,
    required this.core,
  });

  final AppSettings settings;
  final CoreController core;

  @override
  State<NetworkTimeMachinePage> createState() => _NetworkTimeMachinePageState();
}

class _NetworkTimeMachinePageState extends State<NetworkTimeMachinePage> {
  // Pre-test backup snapshot for safe rollback
  String? _preTestDnsName;
  List<String>? _preTestDnsServers;

  void _saveCurrentAsSuccessful() {
    final now = DateTime.now();
    final timeStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final entry = <String, Object?>{
      'network': 'شبکه فعلی (Active Network)',
      'dns_name': widget.settings.homeDnsName.isNotEmpty ? widget.settings.homeDnsName : 'Automatic',
      'dns_servers': widget.settings.homeDnsServers,
      'time': timeStr,
      'status': 'تأییدشده و پایدار',
    };

    final list = [entry, ...widget.settings.networkTimeMachineHistory];
    if (list.length > 20) list.removeLast();
    widget.settings.update(networkTimeMachineHistory: list);
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.settings.language == 'fa'
              ? 'ترکیب اتصال فعلی با موفقیت در ماشین زمان ذخیره شد.'
              : 'Current network profile saved in Time Machine.',
        ),
      ),
    );
  }

  void _restoreProfile(Map<String, Object?> item) {
    // Save snapshot for rollback
    _preTestDnsName = widget.settings.homeDnsName;
    _preTestDnsServers = widget.settings.homeDnsServers;

    final dnsName = item['dns_name'] as String? ?? 'Automatic';
    final dnsServers = (item['dns_servers'] as List<Object?>?)?.whereType<String>().toList() ?? const <String>[];

    widget.settings.update(
      homeDnsName: dnsName,
      homeDnsServers: dnsServers,
    );
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.settings.language == 'fa'
              ? 'تنظیمات موفق پیشین اعمال شد: $dnsName'
              : 'Restored previous profile: $dnsName',
        ),
        action: SnackBarAction(
          label: widget.settings.language == 'fa' ? 'بازگشت (Rollback)' : 'Rollback',
          onPressed: _rollback,
        ),
      ),
    );
  }

  void _rollback() {
    if (_preTestDnsName != null) {
      widget.settings.update(
        homeDnsName: _preTestDnsName,
        homeDnsServers: _preTestDnsServers,
      );
      setState(() {});
    }
  }

  void _clearHistory() {
    widget.settings.update(networkTimeMachineHistory: const []);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = MobileStrings.of(context);
    final isFa = widget.settings.language == 'fa';
    final history = widget.settings.networkTimeMachineHistory;

    if (!widget.settings.proActive) {
      return Scaffold(
        backgroundColor: DarkGlassPalette.bgTop,
        appBar: AppBar(
          title: Text(strings.timeMachineTitle),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_rounded, size: 64, color: Color(0xFFFFB547)),
                const SizedBox(height: 16),
                Text(
                  isFa ? 'این قابلیت مختص کاربران VIP است' : 'VIP Feature Only',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  isFa
                      ? 'برای استفاده از ماشین زمان اینترنت، اشتراک VIP را فعال کنید.'
                      : 'An active VIP license is required to use Network Time Machine.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(isFa ? 'بازگشت' : 'Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DarkGlassPalette.bgTop,
      appBar: AppBar(
        title: Text(strings.timeMachineTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: isFa ? 'پاکسازی تاریخچه' : 'Clear History',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: DarkGlassPalette.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DarkGlassPalette.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DarkGlassPalette.purple.withValues(alpha: 0.16),
                    ),
                    child: const Icon(Icons.history_rounded, color: DarkGlassPalette.purple),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFa ? 'ثبت و بازگشت به تنظیمات موفق' : 'Smart Network Rollback',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isFa
                              ? 'هر زمان اتصال روی شبکه‌ای پایدار بود، مشخصات آن ذخیره می‌شود تا در زمان اختلال دوباره امتحان شود.'
                              : 'Stores proven network combinations to re-test whenever restricted.',
                          style: theme.textTheme.bodySmall?.copyWith(color: DarkGlassPalette.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: _saveCurrentAsSuccessful,
              icon: const Icon(Icons.bookmark_add_rounded),
              label: Text(isFa ? 'ثبت تنظیمات فعلی به عنوان موفق' : 'Bookmark Current Setup'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: DarkGlassPalette.purple,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              isFa ? 'تاریخچه اتصالات موفق ذخیره‌شده:' : 'Saved Verified Profiles:',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            if (history.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: DarkGlassPalette.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DarkGlassPalette.cardBorder),
                ),
                child: Center(
                  child: Text(
                    isFa
                        ? 'هنوز هیچ سابقه‌ای ثبت نشده است. هنگام پایداری اینترنت، دکمه بالا را بزنید.'
                        : 'No profiles saved yet. Tap button above when connected stably.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: DarkGlassPalette.muted),
                  ),
                ),
              )
            else
              for (final item in history) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DarkGlassPalette.cardSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DarkGlassPalette.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wifi_tethering_rounded, size: 18, color: DarkGlassPalette.cyan),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'DNS: ${item['dns_name'] ?? 'Automatic'}',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: DarkGlassPalette.mint.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'VERIFIED',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: DarkGlassPalette.mint,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ثبت شده در: ${item['time'] ?? ''}',
                        style: theme.textTheme.bodySmall?.copyWith(color: DarkGlassPalette.muted),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _restoreProfile(item),
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: Text(isFa ? 'امتحان این تنظیمات موفق' : 'Test This Setup'),
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
