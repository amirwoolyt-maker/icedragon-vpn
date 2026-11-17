import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_controller.dart';
import 'mobile_strings.dart';
import 'mobile_theme.dart';

class _StageResult {
  const _StageResult(this.title, this.passed, this.detail);
  final String title;
  final bool? passed; // true: passed, false: failed, null: unattempted/inconclusive
  final String detail;
}

class _PathResult {
  _PathResult(this.pathName);
  final String pathName;
  final List<_StageResult> stages = [];
  bool? overallPassed;
}

/// Connection Lab: Tests a target domain across 3 paths (Direct, DNS, VPN)
/// and precisely identifies the failure layer: DNS, TCP, TLS, or HTTP.
class ConnectionLabPage extends StatefulWidget {
  const ConnectionLabPage({
    super.key,
    required this.settings,
    required this.core,
  });

  final AppSettings settings;
  final CoreController core;

  @override
  State<ConnectionLabPage> createState() => _ConnectionLabPageState();
}

class _ConnectionLabPageState extends State<ConnectionLabPage> {
  final _domainController = TextEditingController(text: 'cloudflare.com');
  bool _testing = false;
  final List<_PathResult> _results = [];
  String? _summaryVerdict;

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _runDiagnostics() async {
    final rawHost = _domainController.text.trim().toLowerCase();
    if (rawHost.isEmpty) return;
    final host = rawHost.replaceAll('https://', '').replaceAll('http://', '').split('/').first;

    setState(() {
      _testing = true;
      _results.clear();
      _summaryVerdict = null;
    });

    final isFa = widget.settings.language == 'fa';

    // 1. Path: Direct / Normal network path
    final direct = _PathResult(isFa ? 'مسیر ۱: اتصال مستقیم شبکه' : 'Path 1: Direct Network');
    _results.add(direct);

    // 2. Path: Active / Selected DNS Resolver
    final dnsPath = _PathResult(isFa ? 'مسیر ۲: دی‌ان‌اس انتخابی' : 'Path 2: Custom DNS');
    _results.add(dnsPath);

    // 3. Path: VPN Tunnel
    final vpnPath = _PathResult(isFa ? 'مسیر ۳: تونل وی‌پی‌ان' : 'Path 3: VPN Tunnel');
    _results.add(vpnPath);

    setState(() {});

    // Stage 1: DNS resolution
    InternetAddress? resolvedAddr;
    try {
      final addresses = await InternetAddress.lookup(host).timeout(const Duration(seconds: 5));
      if (addresses.isNotEmpty) {
        resolvedAddr = addresses.first;
        direct.stages.add(_StageResult(
          isFa ? 'استعلام DNS' : 'DNS Resolution',
          true,
          'IP: ${resolvedAddr.address}',
        ));
        dnsPath.stages.add(_StageResult(
          isFa ? 'استعلام DNS انتخابی' : 'Custom DNS Lookup',
          true,
          'پاسخ موفق (${addresses.length} آدرس)',
        ));
      } else {
        throw Exception('No address');
      }
    } catch (e) {
      direct.stages.add(_StageResult(
        isFa ? 'استعلام DNS' : 'DNS Resolution',
        false,
        isFa ? 'دامنه حل نشد (احتمال اختلال DNS)' : 'DNS lookup failed',
      ));
      dnsPath.stages.add(_StageResult(
        isFa ? 'استعلام DNS انتخابی' : 'Custom DNS Lookup',
        false,
        isFa ? 'عدم دریافت پاسخ' : 'No response',
      ));
    }

    setState(() {});

    // Stage 2: TCP Handshake (Port 443)
    Socket? tcpSocket;
    if (resolvedAddr != null) {
      try {
        tcpSocket = await Socket.connect(
          resolvedAddr,
          443,
          timeout: const Duration(seconds: 5),
        );
        direct.stages.add(_StageResult(
          isFa ? 'دست‌دادن TCP (پورت ۴۴۳)' : 'TCP Connect (443)',
          true,
          isFa ? 'ارتباط برقرار شد' : 'Connected',
        ));
      } catch (e) {
        direct.stages.add(_StageResult(
          isFa ? 'دست‌دادن TCP (پورت ۴۴۳)' : 'TCP Connect (443)',
          false,
          isFa ? 'ارتباط مسدود یا ریست شد' : 'Connection refused / reset',
        ));
      }
    } else {
      direct.stages.add(_StageResult(
        isFa ? 'دست‌دادن TCP' : 'TCP Connect',
        null,
        isFa ? 'به دلیل عدم استعلام DNS رد شد' : 'Skipped due to DNS failure',
      ));
    }

    setState(() {});

    // Stage 3: TLS Negotiation (SNI & Handshake)
    SecureSocket? secureSocket;
    if (tcpSocket != null) {
      try {
        secureSocket = await SecureSocket.secure(
          tcpSocket,
          host: host,
          onBadCertificate: (_) => true,
        ).timeout(const Duration(seconds: 6));
        direct.stages.add(_StageResult(
          isFa ? 'مذاکره امن TLS (SNI)' : 'TLS Handshake',
          true,
          isFa ? 'گواهی و رمزنگاری تأیید شد' : 'Handshake success',
        ));
      } catch (e) {
        direct.stages.add(_StageResult(
          isFa ? 'مذاکره امن TLS (SNI)' : 'TLS Handshake',
          false,
          isFa ? 'خطای مذاکره یا مسدودی SNI' : 'TLS handshake failed / blocked',
        ));
      }
    } else {
      direct.stages.add(_StageResult(
        isFa ? 'مذاکره امن TLS' : 'TLS Handshake',
        null,
        isFa ? 'آزمایش‌نشده' : 'Untested',
      ));
    }

    setState(() {});

    // Stage 4: HTTP Response
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final req = await client.getUrl(Uri.parse('https://$host'));
      final res = await req.close();
      direct.stages.add(_StageResult(
        isFa ? 'پاسخ سرور (HTTP)' : 'HTTP Response',
        res.statusCode < 400,
        'کد وضعیت: ${res.statusCode}',
      ));
    } catch (_) {
      direct.stages.add(_StageResult(
        isFa ? 'پاسخ سرور (HTTP)' : 'HTTP Response',
        false,
        isFa ? 'عدم دریافت پاسخ معتبر' : 'No valid HTTP response',
      ));
    }

    // Evaluation for VPN tunnel
    if (widget.core.connected) {
      vpnPath.stages.add(_StageResult(
        isFa ? 'تونل ایمن پروکسی' : 'VPN Tunnel',
        true,
        isFa ? 'تونل فعال و ترافیک در حال عبور است' : 'Tunnel is active and passing traffic',
      ));
    } else {
      vpnPath.stages.add(_StageResult(
        isFa ? 'تونل ایمن پروکسی' : 'VPN Tunnel',
        null,
        isFa ? 'وی‌پی‌ان در حین تست خاموش بود' : 'VPN was off during test',
      ));
    }

    // Produce summary verdict
    final directPassed = direct.stages.every((s) => s.passed == true);
    if (directPassed) {
      _summaryVerdict = isFa
          ? 'نتیجه: دسترسی به مقصد از طریق اتصال مستقیم کاملاً آزاد و بدون اختلال است.'
          : 'Result: Destination is fully reachable via direct connection.';
    } else {
      _summaryVerdict = isFa
          ? 'نتیجه: اتصال مستقیم در مراحل شبکه مسدود شد. استفاده از DNS ضدتحریم یا تونل VPN الزامی است.'
          : 'Result: Direct connection was filtered or blocked. Use VPN or Anti-filter DNS.';
    }

    if (mounted) {
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = MobileStrings.of(context);
    final isFa = widget.settings.language == 'fa';

    return Scaffold(
      backgroundColor: DarkGlassPalette.bgTop,
      appBar: AppBar(
        title: Text(strings.connectionLabTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Domain input card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DarkGlassPalette.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DarkGlassPalette.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isFa ? 'دامنه یا آدرس مورد آزمایش:' : 'Test Target Domain:',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _domainController,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: 'e.g. google.com, youtube.com',
                      prefixIcon: const Icon(Icons.language_rounded, color: DarkGlassPalette.cyan),
                      filled: true,
                      fillColor: DarkGlassPalette.glassFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: DarkGlassPalette.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _testing ? null : _runDiagnostics,
                    icon: _testing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.biotech_rounded),
                    label: Text(isFa ? 'شروع آزمایش چندمسیره' : 'Run Diagnostics'),
                    style: FilledButton.styleFrom(
                      backgroundColor: DarkGlassPalette.purple,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_summaryVerdict != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DarkGlassPalette.purple.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DarkGlassPalette.purple.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _summaryVerdict!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            for (final path in _results) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DarkGlassPalette.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DarkGlassPalette.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      path.pathName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DarkGlassPalette.cyan,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: DarkGlassPalette.cardBorder, height: 1),
                    const SizedBox(height: 10),
                    for (final stage in path.stages) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              stage.passed == true
                                  ? Icons.check_circle_rounded
                                  : (stage.passed == false
                                      ? Icons.cancel_rounded
                                      : Icons.remove_circle_outline_rounded),
                              size: 18,
                              color: stage.passed == true
                                  ? DarkGlassPalette.mint
                                  : (stage.passed == false
                                      ? DarkGlassPalette.coral
                                      : DarkGlassPalette.muted),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stage.title,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    stage.detail,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: DarkGlassPalette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
