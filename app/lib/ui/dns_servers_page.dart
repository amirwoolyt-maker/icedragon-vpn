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
          _delays[_id(provider)] = timings.isEmpty
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
    return Scaffold(
      appBar: AppBar(title: Text(strings.dnsQuickSelect)),
      body: Center(
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
              for (final provider in widget.providers)
                if (provider.name.toLowerCase().contains(_query))
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.16),
                        child: const Icon(Icons.dns_rounded),
                      ),
                      title: Text(
                        provider.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        provider.servers.join('\n'),
                        textDirection: TextDirection.ltr,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_delays.containsKey(_id(provider)))
                            Text(_delays[_id(provider)] == null
                                ? '—'
                                : '${_delays[_id(provider)]} ms'),
                          if (_id(provider) == widget.settings.homeDnsServers.join(','))
                            const Icon(Icons.check_circle_rounded),
                        ],
                      ),
                      onTap: busy ? null : () => _choose(provider),
                    ),
                  ),
              const SizedBox(height: 96),
            ],
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
