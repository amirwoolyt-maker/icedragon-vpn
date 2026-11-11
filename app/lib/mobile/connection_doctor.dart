import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../core/relay_test.dart';
import '../ui/format.dart';
import 'mobile_strings.dart';
import 'mobile_theme.dart';

/// Opens the Smart Connection Doctor modal sheet that safely tests DNS,
/// relay fallback, TLS Fragment modes, and H2/H3/H1 transports to find a
/// working route to Mozilla for restricted networks.
Future<void> showConnectionDoctorSheet(
  BuildContext context,
  CoreController core,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ConnectionDoctorSheet(core: core),
);

enum _StepStatus { running, passed, failed, info }

class _DoctorStep {
  _DoctorStep(this.title, this.status);

  final String title;
  _StepStatus status;
  String detail = '';
}

class _ProfileCandidate {
  const _ProfileCandidate({
    required this.label,
    required this.transport,
    required this.helloSplit,
    required this.sharedRelay,
  });

  final String label;
  final String transport;
  final String helloSplit;
  final bool sharedRelay;
}

const _doctorProfiles = <_ProfileCandidate>[
  _ProfileCandidate(
    label: 'HTTP/2 + TLS Fragment (SNI)',
    transport: 'h2',
    helloSplit: 'sni',
    sharedRelay: true,
  ),
  _ProfileCandidate(
    label: 'HTTP/3 (QUIC)',
    transport: 'h3',
    helloSplit: 'off',
    sharedRelay: true,
  ),
  _ProfileCandidate(
    label: 'HTTP/2 + TLS Fragment (Record)',
    transport: 'h2',
    helloSplit: 'record',
    sharedRelay: true,
  ),
  _ProfileCandidate(
    label: 'HTTP/1.1 + Fragment (First-Byte)',
    transport: 'h1',
    helloSplit: 'first-byte',
    sharedRelay: true,
  ),
];

const _autoDohServers = <String>[
  'https://1.1.1.1/dns-query',
  'https://8.8.8.8/dns-query',
  'https://9.9.9.9/dns-query',
];

class _ConnectionDoctorSheet extends StatefulWidget {
  const _ConnectionDoctorSheet({required this.core});

  final CoreController core;

  @override
  State<_ConnectionDoctorSheet> createState() => _ConnectionDoctorSheetState();
}

class _ConnectionDoctorSheetState extends State<_ConnectionDoctorSheet> {
  final List<_DoctorStep> _steps = <_DoctorStep>[];
  Map<String, Object?>? _originalConfig;
  bool _wasProxyOn = false;
  bool _running = false;
  bool _solved = false;
  bool _cancelled = false;
  String _summary = '';

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  void _addOrUpdate(_DoctorStep step) {
    if (!mounted || _cancelled) return;
    setState(() {
      if (!_steps.contains(step)) _steps.add(step);
    });
  }

  Map<String, Object?> _deepCopy(Map<String, Object?> src) =>
      jsonDecode(jsonEncode(src)) as Map<String, Object?>;

  Map<String, Object?> _obj(Map<String, Object?> root, String key) {
    final existing = root[key];
    if (existing is Map<String, Object?>) return existing;
    return root[key] = <String, Object?>{};
  }

  Future<void> _restoreOriginal() async {
    final orig = _originalConfig;
    if (orig == null) return;
    try {
      await widget.core.call((api) async {
        await api.saveSettings(_deepCopy(orig));
        await api.setPower(_wasProxyOn);
      });
    } on Exception {
      // Best-effort restore.
    }
  }

  Future<void> _runDoctor() async {
    final ms = MobileStrings.of(context);
    final api = widget.core.api;
    if (api == null) return;

    if ((widget.core.status?.totalAccounts ?? 0) == 0) {
      setState(() {
        _solved = false;
        _summary = ms.doctorNeedAccount;
      });
      return;
    }

    setState(() {
      _running = true;
      _solved = false;
      _summary = '';
      _steps.clear();
    });

    try {
      _originalConfig = _deepCopy(await api.settings());
      _wasProxyOn = widget.core.status?.proxyOn ?? false;
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _summary = '$e';
      });
      return;
    }

    var workingDns = List<String>.from(
      (_originalConfig?['dns'] as Map<String, Object?>?)?['servers']
              as List<Object?>? ??
          const [],
    );

    // Step 1: Test DoH DNS filtering on the current network.
    final dnsStep = _DoctorStep(ms.doctorStepDns, _StepStatus.running);
    _addOrUpdate(dnsStep);
    try {
      final dnsResults = await api.testDns(_autoDohServers);
      final anyFiltered = dnsResults.any((r) => r.filtered);
      final dohWorks = dnsResults.any(
        (r) => r.error.isEmpty && r.addrs.isNotEmpty,
      );
      if (dohWorks && (workingDns.isEmpty || anyFiltered)) {
        workingDns = List<String>.from(_autoDohServers);
        dnsStep.status = _StepStatus.passed;
        dnsStep.detail = anyFiltered ? ms.doctorDnsCleaned : 'DoH OK';
      } else if (dohWorks) {
        dnsStep.status = _StepStatus.passed;
        dnsStep.detail = 'OK';
      } else {
        dnsStep.status = _StepStatus.info;
        dnsStep.detail = 'DoH slow/filtered; keeping fallback';
      }
    } on Exception catch (e) {
      dnsStep.status = _StepStatus.info;
      dnsStep.detail = '$e';
    }
    _addOrUpdate(dnsStep);

    // Step 2: Check personal API relay if configured, else rely on shared pool.
    final origNet = _originalConfig?['network'] as Map<String, Object?>?;
    final relayUrl = (origNet?['api_relay'] as String? ?? '').trim();
    final relayEnabled = origNet?['api_relay_enabled'] == true;
    if (relayUrl.isNotEmpty && relayEnabled) {
      final relayStep = _DoctorStep(ms.doctorStepRelay, _StepStatus.running);
      _addOrUpdate(relayStep);
      try {
        RelayTestResult? res;
        await for (final ev in api.testRelay(relayUrl)) {
          if (_cancelled) break;
          if (ev.result != null) res = ev.result;
        }
        if (res != null && res.ok) {
          relayStep.status = _StepStatus.passed;
          relayStep.detail = '${res.totalMs} ms';
        } else {
          relayStep.status = _StepStatus.failed;
          relayStep.detail = 'HTTP / TLS failed';
        }
      } on Exception catch (e) {
        relayStep.status = _StepStatus.failed;
        relayStep.detail = '$e';
      }
      _addOrUpdate(relayStep);
    }

    // Step 3: Probe connection profiles and verify real tunnel throughput.
    var winnerFound = false;
    for (final profile in _doctorProfiles) {
      if (_cancelled) break;
      final step = _DoctorStep(
        ms.doctorTryingProfile(profile.label),
        _StepStatus.running,
      );
      _addOrUpdate(step);

      try {
        final cfg = _deepCopy(_originalConfig!);
        final proxy = _obj(cfg, 'proxy');
        proxy['transport'] = profile.transport;
        final net = _obj(cfg, 'network');
        net['hello_split'] = profile.helloSplit;
        net['shared_relay_enabled'] = profile.sharedRelay;
        final dns = _obj(cfg, 'dns');
        if (workingDns.isNotEmpty) {
          dns['servers'] = workingDns;
        }
        dns['fallback_to_system'] = true;

        await api.saveSettings(cfg);
        await widget.core.setOn(true);
        if (_cancelled) break;

        final test = await _testWhenReady(api);
        if (test.ok) {
          step.status = _StepStatus.passed;
          step.detail = '${test.responseMs} ms';
          _addOrUpdate(step);
          winnerFound = true;
          if (mounted) {
            setState(() {
              _running = false;
              _solved = true;
              _summary = ms.doctorSuccess(profile.label, test.responseMs);
            });
          }
          break;
        }
        step.status = _StepStatus.failed;
        step.detail = test.error.isNotEmpty ? test.error : test.errorCode;
      } on Exception catch (e) {
        step.status = _StepStatus.failed;
        step.detail = '$e';
      }
      _addOrUpdate(step);
    }

    if (!winnerFound && !_cancelled) {
      await _restoreOriginal();
      await widget.core.refresh();
      if (mounted) {
        setState(() {
          _running = false;
          _solved = false;
          _summary = ms.doctorNoProfileWorked;
        });
      }
    }
  }

  Future<ConnectionTest> _testWhenReady(CoreApi api) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        return await api.test();
      } on CoreApiException catch (e) {
        if (e.statusCode != 409 || attempt == 5 || _cancelled) rethrow;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    return api.test();
  }

  @override
  Widget build(BuildContext context) {
    final ms = MobileStrings.of(context);
    final l = Theme.of(context);
    final isDark = l.brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: l.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DarkGlassPalette.purple.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_fix_high_rounded,
                  color: DarkGlassPalette.cyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ms.smartDoctor,
                  style: l.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!_running)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ms.smartDoctorIntro,
            style: l.textTheme.bodySmall?.copyWith(
              color: l.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (_steps.isNotEmpty) ...[
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _steps.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final step = _steps[i];
                  final (icon, color) = switch (step.status) {
                    _StepStatus.running => (null, DarkGlassPalette.cyan),
                    _StepStatus.passed => (
                      Icons.check_circle_rounded,
                      DarkGlassPalette.mint,
                    ),
                    _StepStatus.failed => (
                      Icons.cancel_rounded,
                      DarkGlassPalette.coral,
                    ),
                    _StepStatus.info => (
                      Icons.info_rounded,
                      DarkGlassPalette.amber,
                    ),
                  };
                  return GlassCard(
                    dark: isDark,
                    radius: 14,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 18,
                          child: icon == null
                              ? CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: color,
                                )
                              : Icon(icon, size: 18, color: color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: l.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (step.detail.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  ltr(step.detail),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: l.textTheme.bodySmall?.copyWith(
                                    color: l.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          if (_summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_solved
                        ? DarkGlassPalette.mint
                        : DarkGlassPalette.coral)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (_solved
                          ? DarkGlassPalette.mint
                          : DarkGlassPalette.coral)
                      .withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                _summary,
                style: l.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (_solved && _originalConfig != null && !_running) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await _restoreOriginal();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(ms.doctorRestore),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: _running
                      ? null
                      : _solved
                      ? () => Navigator.of(context).pop()
                      : _runDoctor,
                  icon: Icon(
                    _running
                        ? Icons.hourglass_top_rounded
                        : _solved
                        ? Icons.check_rounded
                        : Icons.auto_fix_high_rounded,
                  ),
                  label: Text(
                    _running
                        ? ms.doctorRunning
                        : _solved
                        ? MaterialLocalizations.of(context).okButtonLabel
                        : ms.doctorStart,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
