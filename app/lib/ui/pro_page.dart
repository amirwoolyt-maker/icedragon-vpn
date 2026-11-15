import 'package:flutter/material.dart';

import '../app_info.dart' show proPurchaseUrl;
import '../mobile/mobile_strings.dart';
import '../platform.dart';
import 'widgets.dart';

/// Pro overview and purchase entry point. License verification is intentionally
/// not simulated locally; it requires a trusted licensing service.
class ProPage extends StatefulWidget {
  const ProPage({super.key});

  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  int? _expandedPlan;
  bool _animatingPlan = false;

  Future<void> _togglePlan(int index) async {
    if (_animatingPlan) return;
    setState(() => _animatingPlan = true);
    setState(() => _expandedPlan = _expandedPlan == index ? null : index);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (mounted) setState(() => _animatingPlan = false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = MobileStrings.of(context);
    final theme = Theme.of(context);
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
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x99FFB300)),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x553D2E13), Color(0x33201912), Color(0x44221609)],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33FF9800), blurRadius: 22),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      size: 42,
                      color: Color(0xFFFFC247),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.proTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFFFFD16A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(strings.proSubtitle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(strings.proAvailable, style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              for (final (icon, title) in features)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(icon, color: const Color(0xFFFFC247)),
                    title: Text(title),
                    trailing: const _ProBadge(),
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
                  Widget details(int index) => ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _expandedPlan == index ? 1 : 0,
                        child: _expandedPlan == index
                            ? Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC171B28),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0x445E9BC4),
                                  ),
                                ),
                                child: Text(
                                  plans[index].$4,
                                  style: theme.textTheme.bodySmall,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  );
                  Widget card(int index) => _PlanCard(
                    title: plans[index].$1,
                    badge: plans[index].$2,
                    price: plans[index].$3,
                    expanded: _expandedPlan == index,
                    enabled: !_animatingPlan,
                    onTap: () => _togglePlan(index),
                  );

                  if (constraints.maxWidth < 520) {
                    return Column(
                      children: [
                        for (var i = 0; i < plans.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          SizedBox(width: double.infinity, child: card(i)),
                          details(i),
                        ],
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
              _GlassActionSurface(
                child: TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: strings.proRedeem,
                    prefixIcon: const Icon(Icons.key_rounded),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _GlassActionSurface(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(strings.proRestore),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: Color(0x4469D7FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.proBackendUnavailable,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _ProBuyButton(
                label: strings.proBuy,
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

class _ProBadge extends StatelessWidget {
  const _ProBadge({this.label = 'PRO'});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0x22FFB300),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0x88FFB300)),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: const Color(0xFFFFC247),
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
