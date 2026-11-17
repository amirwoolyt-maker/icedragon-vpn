import 'dart:async';
import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_controller.dart';
import 'mobile_strings.dart';
import 'mobile_theme.dart';

/// Manages and displays the temporary connection timer.
class ConnectionTimerManager {
  static Timer? _activeTimer;

  static void schedule(AppSettings settings, CoreController core) {
    _activeTimer?.cancel();
    if (settings.connectionTimerEndMillis <= 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = settings.connectionTimerEndMillis - now;

    if (diff <= 0) {
      // Already expired: turn off connection cleanly
      settings.update(connectionTimerEndMillis: 0);
      core.setOn(false);
      return;
    }

    _activeTimer = Timer(Duration(milliseconds: diff), () {
      settings.update(connectionTimerEndMillis: 0);
      core.setOn(false);
    });
  }

  static void cancel(AppSettings settings) {
    _activeTimer?.cancel();
    _activeTimer = null;
    if (settings.connectionTimerEndMillis != 0) {
      settings.update(connectionTimerEndMillis: 0);
    }
  }

  static String remainingFormatted(int endMillis) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = (endMillis - now) ~/ 1000;
    if (diff <= 0) return '00:00';
    final m = (diff ~/ 60).toString().padLeft(2, '0');
    final s = (diff % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Modal bottom sheet to pick a temporary connection timer.
Future<void> showConnectionTimerSheet({
  required BuildContext context,
  required AppSettings settings,
  required CoreController core,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 540),
  backgroundColor: DarkGlassPalette.cardSurface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    side: BorderSide(color: DarkGlassPalette.cardBorder),
  ),
  builder: (_) => _ConnectionTimerSheet(settings: settings, core: core),
);

class _ConnectionTimerSheet extends StatefulWidget {
  const _ConnectionTimerSheet({required this.settings, required this.core});

  final AppSettings settings;
  final CoreController core;

  @override
  State<_ConnectionTimerSheet> createState() => _ConnectionTimerSheetState();
}

class _ConnectionTimerSheetState extends State<_ConnectionTimerSheet> {
  int _selectedMinutes = 30;

  void _apply(int minutes) {
    final endMillis = DateTime.now().millisecondsSinceEpoch + (minutes * 60 * 1000);
    widget.settings.update(connectionTimerEndMillis: endMillis);
    ConnectionTimerManager.schedule(widget.settings, widget.core);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.settings.language == 'fa'
              ? 'تایمر اتصال موقت برای $minutes دقیقه تنظیم شد.'
              : 'Connection timer set for $minutes minutes.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = MobileStrings.of(context);
    final isFa = widget.settings.language == 'fa';
    final hasActiveTimer = widget.settings.connectionTimerEndMillis > DateTime.now().millisecondsSinceEpoch;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DarkGlassPalette.purple.withValues(alpha: 0.16),
                  border: Border.all(color: DarkGlassPalette.purple.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.timer_outlined, color: DarkGlassPalette.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.connectionTimerTitle,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      isFa
                          ? 'قطع خودکار اتصال پس از زمان دلخواه'
                          : 'Automatically disconnect after chosen duration',
                      style: theme.textTheme.bodySmall?.copyWith(color: DarkGlassPalette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (hasActiveTimer) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DarkGlassPalette.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DarkGlassPalette.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: DarkGlassPalette.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isFa
                          ? 'تایمر فعال: ${ConnectionTimerManager.remainingFormatted(widget.settings.connectionTimerEndMillis)} باقی‌مانده'
                          : 'Active timer: ${ConnectionTimerManager.remainingFormatted(widget.settings.connectionTimerEndMillis)} remaining',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DarkGlassPalette.amber,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ConnectionTimerManager.cancel(widget.settings);
                      setState(() {});
                    },
                    child: Text(isFa ? 'لغو تایمر' : 'Cancel'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            isFa ? 'مدت زمان اتصال:' : 'Duration:',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final mins in [15, 30, 60, 120])
                ChoiceChip(
                  label: Text(isFa ? '$mins دقیقه' : '$mins min'),
                  selected: _selectedMinutes == mins,
                  onSelected: (sel) {
                    if (sel) setState(() => _selectedMinutes = mins);
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _apply(_selectedMinutes),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(isFa ? 'فعال‌سازی تایمر' : 'Start Timer'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: DarkGlassPalette.purple,
            ),
          ),
        ],
      ),
    );
  }
}
