import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_controller.dart';
import '../l10n/app_localizations.dart';
import '../mobile/mobile_strings.dart';
import 'widgets.dart';

typedef DnsProvider = ({String name, List<String> servers});

/// Session measurements, shared with Home without generating extra requests.
final dnsProviderDelays = <String, int?>{};

class DnsServersPage extends StatefulWidget {
  const DnsServersPage({
    super.key,
    required this.core,
    required this.settings,
    required this.providers,
    required this.onChoose,
    this.findFastest = false,
  });

  final CoreController core;
  final AppSettings settings;
  final List<DnsProvider> providers;
  final Future<void> Function(DnsProvider) onChoose;
  final bool findFastest;

  @override
  State<DnsServersPage> createState() => _DnsServersPageState();
}

class _DnsServersPageState extends State<DnsServersPage> {
  final Map<String, int?> _delays = {};
  bool _testing = false;
  bool _saving = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _delays.addAll(dnsProviderDelays);
    if (widget.findFastest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _test(chooseFastest: true);
      });
    }
  }

  String _id(DnsProvider provider) => provider.servers.join(',');

  Future<void> _choose(DnsProvider provider) async {
    if (_saving || _testing) return;
    setState(() => _saving = true);
    final ok = await runShowingErrors(context, () => widget.onChoose(provider));
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _test({bool chooseFastest = false}) async {
    if (_testing || _saving) return;
    final settings = widget.settings;
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final used = settings.dnsTestDay == day ? settings.dnsTestCount : 0;
    if (used >= 3) {
      showError(context, MobileStrings.of(context).dnsTestUnavailableToday);
      return;
    }
    // Persist before requests, including failed batches. Paid entitlements must
    // be verified by the licensing backend before bypassing this local quota.
    settings.update(dnsTestDay: day, dnsTestCount: used + 1);
    setState(() {
      _testing = true;
      _delays.clear();
    });
    final ok = await runShowingErrors(context, () async {
      for (final provider in widget.providers) {
        if (!mounted) return;
        final results = await widget.core.call((api) => api.testDns(provider.servers));
        final timings = [
          for (final result in results)
            if (result.error.isEmpty && result.ms > 0) result.ms,
        ];
        if (!mounted) return;
        setState(() {
          _delays[_id(provider)] = timings.isEmpty || timings.length != results.length
              ? null
              : timings.reduce((a, b) => a + b) ~/ timings.length;
          dnsProviderDelays[_id(provider)] = _delays[_id(provider)];
        });
      }
    });
    if (!mounted) return;
    setState(() => _testing = false);
    if (ok && chooseFastest) {
      final measured = widget.providers
          .where((provider) => _delays[_id(provider)] != null)
          .toList()
        ..sort((a, b) => _delays[_id(a)]!.compareTo(_delays[_id(b)]!));
      if (measured.isNotEmpty) await _choose(measured.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = MobileStrings.of(context);
    final l = AppLocalizations.of(context);
    final busy = _testing || _saving;
    final providers = widget.providers.where((provider) {
      return provider.name.toLowerCase().contains(_query) ||
          provider.servers.any((server) => server.toLowerCase().contains(_query));
    }).toList();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(strings.dnsQuickSelect)),
      body: SafeArea(
        top: false,
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  labelText: strings.dnsQuickSelect,
                ),
                onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DnsActionButton(
                    onPressed: busy ? null : () => _choose(widget.providers.first),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(strings.quickAuto),
                  ),
                  _DnsActionButton(
                    onPressed: busy ? null : () => _test(chooseFastest: true),
                    icon: const Icon(Icons.bolt_rounded),
                    label: Text(strings.quickFastest),
                  ),
                  _DnsActionButton(
                    onPressed: busy ? null : () => _test(),
                    icon: const Icon(Icons.speed_rounded),
                    label: Text(l.testDns),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(strings.dnsProviderHint),
              if (_testing) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < providers.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                      selected: _id(providers[i]) ==
                          widget.settings.homeDnsServers.join(','),
                      selectedTileColor: scheme.primary.withValues(alpha: 0.08),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 36,
                        height: 27,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.dns_rounded, size: 20, color: scheme.primary),
                      ),
                      title: Text(
                        providers[i].name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        providers[i].servers.join(' · '),
                        textDirection: TextDirection.ltr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_delays.containsKey(_id(providers[i])))
                            Text(_delays[_id(providers[i])] == null
                                ? '—'
                                : '${_delays[_id(providers[i])]} ms'),
                          const SizedBox(width: 6),
                          Icon(
                            _id(providers[i]) == widget.settings.homeDnsServers.join(',')
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 24,
                          ),
                        ],
                      ),
                      onTap: busy ? null : () => _choose(providers[i]),
                    ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _DnsActionButton extends StatelessWidget {
  const _DnsActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: icon,
    label: label,
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF171B2E),
      foregroundColor: const Color(0xFFB7B9FF),
      disabledBackgroundColor: const Color(0xFF111522),
      disabledForegroundColor: const Color(0xFF626A86),
      side: const BorderSide(color: Color(0x664A5071)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
