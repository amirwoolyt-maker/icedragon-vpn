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
                  color: const Color(0x18FFB300),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x66FFB300)),
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
                          Text(strings.proTitle, style: theme.textTheme.headlineSmall),
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
                    (strings.proMonthly, '', r'$0.50'),
                    (strings.proYearly, strings.proMostPopular, r'$2.00'),
                    (strings.proLifetime, strings.proBestValue, r'$4.00'),
                  ];
                  final cards = [
                    for (final (name, badge, price) in plans)
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              if (badge.isNotEmpty) _ProBadge(label: badge),
                              if (badge.isNotEmpty) const SizedBox(height: 8),
                              Text(name, textAlign: TextAlign.center),
                              const SizedBox(height: 10),
                              Text(
                                price,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ];
                  return constraints.maxWidth < 520
                      ? Column(
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(height: 8),
                              SizedBox(width: double.infinity, child: cards[i]),
                            ],
                          ],
                        )
                      : Row(
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(child: cards[i]),
                            ],
                          ],
                        );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                enabled: false,
                decoration: InputDecoration(
                  labelText: strings.proRedeem,
                  prefixIcon: const Icon(Icons.key_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(strings.proRestore),
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
              FilledButton.icon(
                onPressed: () => runShowingErrors(
                  context,
                  () async {
                    await openUrl(proPurchaseUrl);
                  },
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(strings.proBuy),
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
