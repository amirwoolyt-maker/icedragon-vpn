import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_info.dart' show proLicensingApi, proPurchaseUrl;
import '../app_settings.dart';
import '../mobile/mobile_strings.dart';
import '../platform.dart';
import 'widgets.dart';

/// Pro overview and purchase entry point connected to Cloudflare Licensing API.
class ProPage extends StatefulWidget {
  const ProPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  final _codeController = TextEditingController();
  int? _expandedPlan;
  bool _animatingPlan = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _checkStatusSilently();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkStatusSilently() async {
    final code = widget.settings.proLicenseCode.trim();
    if (code.isEmpty) return;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final uri = Uri.parse('$proLicensingApi/status?code=${Uri.encodeComponent(code)}');
      final req = await client.getUrl(uri);
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, Object?>?;
        if (json != null && json['ok'] == true && json['active'] == true && mounted) {
          widget.settings.update(
            proActive: true,
            proPlanName: json['plan'] as String? ?? widget.settings.proPlanName,
            proExpiresAt: json['expires_at'] as String? ?? widget.settings.proExpiresAt,
            proDaysLeft: json['days_left'] as int? ?? widget.settings.proDaysLeft,
            proIsLifetime: json['is_lifetime'] == true,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _togglePlan(int index) async {
    if (_animatingPlan) return;
    setState(() => _animatingPlan = true);
    setState(() => _expandedPlan = _expandedPlan == index ? null : index);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (mounted) setState(() => _animatingPlan = false);
  }

  Future<void> _redeemCode() async {
    final strings = MobileStrings.of(context);
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.proCodeEmpty)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse('$proLicensingApi/redeem');
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.write(jsonEncode({
        'code': code,
        'device_id': widget.settings.deviceId,
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, Object?>?;

      if (!mounted) return;

      if (res.statusCode == 200 && json != null && json['ok'] == true) {
        final plan = json['plan'] as String? ?? 'VIP';
        final expiresAt = json['expires_at'] as String? ?? '';
        final daysLeft = json['days_left'] as int? ?? 30;
        final isLifetime = json['is_lifetime'] == true;

        widget.settings.update(
          proActive: true,
          proLicenseCode: code,
          proPlanName: plan,
          proExpiresAt: expiresAt,
          proDaysLeft: daysLeft,
          proIsLifetime: isLifetime,
        );

        _codeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00E676),
            content: Text(
              strings.proActivatedSuccess,
              style: const TextStyle(color: Color(0xFF051C0F), fontWeight: FontWeight.w700),
            ),
          ),
        );
      } else {
        final err = json?['error'] as String? ?? 'خطا در فعال‌سازی لایسنس';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD32F2F),
            content: Text(err),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFD32F2F),
            content: Text('خطا در برقراری ارتباط با سرور اعتبارسنجی'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = MobileStrings.of(context);
    final theme = Theme.of(context);
    final isPro = widget.settings.proActive;

    final features = [
      (Icons.call_split_rounded, strings.proFeatureSplitDns),
      (Icons.speed_rounded, strings.proFeatureUnlimitedTests),
      (Icons.dns_rounded, strings.proFeatureCustomDns),
      (Icons.swap_vert_rounded, strings.proFeatureAutoSwitch),
      (Icons.fingerprint_rounded, strings.proFeatureAppLock),
      (Icons.cloud_sync_rounded, strings.proFeatureBackup),
      (Icons.widgets_rounded, strings.proFeatureTile),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPro ? const Color(0x9900E676) : const Color(0x99FFB300),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isPro
                        ? const [Color(0x550C3820), Color(0x33081E12), Color(0x44061F13)]
                        : const [Color(0x553D2E13), Color(0x33201912), Color(0x44221609)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isPro ? const Color(0x3300E676) : const Color(0x33FF9800),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      isPro ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                      size: 42,
                      color: isPro ? const Color(0xFF00E676) : const Color(0xFFFFC247),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPro ? 'IceDragon VIP' : strings.proTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: isPro ? const Color(0xFF69F0AE) : const Color(0xFFFFD16A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPro ? strings.proActiveStatus : strings.proSubtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isPro ? const Color(0xFFC8E6C9) : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Active Subscription Card
              if (isPro) ...[
                _ActiveProGlassCard(
                  settings: widget.settings,
                  strings: strings,
                ),
                const SizedBox(height: 20),
              ],

              Text(strings.proAvailable, style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              for (final (icon, title) in features)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      icon,
                      color: isPro ? const Color(0xFF00E676) : const Color(0xFFFFC247),
                    ),
                    title: Text(title),
                    trailing: _ProBadge(
                      label: isPro ? 'ACTIVE' : 'PRO',
                      color: isPro ? const Color(0xFF00E676) : const Color(0xFFFFC247),
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              LayoutBuilder(
                builder: (context, constraints) {
                  final plans = [
                    (
                      strings.proMonthly,
                      '',
                      r'$0.50',
                      strings.proPlanMonthlyDetail,
                    ),
                    (
                      strings.proYearly,
                      strings.proMostPopular,
                      r'$2.00',
                      strings.proPlanYearlyDetail,
                    ),
                    (
                      strings.proLifetime,
                      strings.proBestValue,
                      r'$4.00',
                      strings.proPlanLifetimeDetail,
                    ),
                  ];
                  Widget card(int i) => _PlanCard(
                    title: plans[i].$1,
                    badge: plans[i].$2,
                    price: plans[i].$3,
                    expanded: _expandedPlan == i,
                    enabled: !_animatingPlan,
                    onTap: () => _togglePlan(i),
                  );
                  Widget details(int i) => AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: _expandedPlan == i
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox.shrink(),
                    secondChild: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x332B3245),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x4475CFFF)),
                      ),
                      child: Text(
                        plans[i].$4,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  );

                  return Column(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < plans.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: card(i)),
                          ],
                        ],
                      ),
                      for (var i = 0; i < plans.length; i++) details(i),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // Code Redemption Section (Hidden if already Pro)
              if (!isPro) ...[
                _GlassActionSurface(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                    ],
                    decoration: InputDecoration(
                      labelText: strings.proRedeem,
                      hintText: strings.proCodeHint,
                      prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFFFFD16A)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _GlassActionSurface(
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _redeemCode,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.verified_rounded),
                    label: Text(strings.proActivateButton),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: const Color(0x33816BFF),
                      foregroundColor: const Color(0xFF00D2FF),
                      side: const BorderSide(color: Color(0x6600D2FF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              const Divider(),
              const SizedBox(height: 8),

              _ProBuyButton(
                label: isPro ? strings.proSupportTelegram : strings.proBuy,
                onPressed: () => runShowingErrors(
                  context,
                  () async {
                    await openUrl(proPurchaseUrl);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveProGlassCard extends StatelessWidget {
  const _ActiveProGlassCard({
    required this.settings,
    required this.strings,
  });

  final AppSettings settings;
  final MobileStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = settings.proDaysLeft;
    final isLifetime = settings.proIsLifetime;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x3312172D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x4D816BFF), width: 1.2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x33816BFF),
            Color(0x1F12172D),
            Color(0x2800D2FF),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 16,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color(0x1A816BFF),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x26FFD56A),
                  border: Border.all(color: const Color(0x66FFD56A)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22FFD56A),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFFD56A),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.proActiveStatus,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      settings.proPlanName.isNotEmpty ? settings.proPlanName : 'IceDragon VIP',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFFFD56A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: ShapeDecoration(
                  color: const Color(0x2600E5A3),
                  shape: const StadiumBorder(
                    side: BorderSide(color: Color(0x5500E5A3)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF00E5A3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'VIP ACTIVE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF00E5A3),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0x2E816BFF), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF00D2FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isLifetime
                      ? strings.proLifetimeActive
                      : '  روز باقی مانده است',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (settings.proLicenseCode.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x22000000),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_rounded, size: 15, color: Color(0xFFFFD56A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'کد لایسنس: ',
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xCCFFFFFF),
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: settings.proLicenseCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('کد لایسنس کپی شد'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.copy_rounded, size: 15, color: Color(0xAAFFFFFF)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge({
    this.label = 'PRO',
    this.color = const Color(0xFFFFC247),
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.badge,
    required this.price,
    required this.expanded,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String badge;
  final String price;
  final bool expanded;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = expanded
        ? const Color(0xCCFFC247)
        : const Color(0x6675CFFF);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 164,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: expanded
              ? const [Color(0x442C281E), Color(0x33202131)]
              : const [Color(0x332B3245), Color(0x22161924)],
        ),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: expanded ? 0.2 : 0.08),
            blurRadius: expanded ? 16 : 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  height: 25,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: badge.isEmpty
                        ? const SizedBox.shrink()
                        : _ProBadge(label: badge),
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  price,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFFFFD16A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: expanded ? const Color(0xFFFFD16A) : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassActionSurface extends StatelessWidget {
  const _GlassActionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x223B4962),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0x4475CFFF)),
      boxShadow: const [BoxShadow(color: Color(0x1175CFFF), blurRadius: 12)],
    ),
    child: child,
  );
}

class _ProBuyButton extends StatelessWidget {
  const _ProBuyButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFD56A), Color(0xFFFF9F43)],
      ),
      boxShadow: const [BoxShadow(color: Color(0x55FF9F43), blurRadius: 16)],
    ),
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.open_in_new_rounded),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF24170A),
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
