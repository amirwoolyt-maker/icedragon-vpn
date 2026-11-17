import 'dart:io';

import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../mobile/mobile_theme.dart';
import '../hub_controller.dart';
import '../hub_strings.dart';

/// App Hub preferences page inside Settings (#5, #8, #12, #16).
class HubSettingsPage extends StatefulWidget {
  const HubSettingsPage({
    super.key,
    required this.hub,
    required this.settings,
  });

  final HubController hub;
  final AppSettings settings;

  @override
  State<HubSettingsPage> createState() => _HubSettingsPageState();
}

class _HubSettingsPageState extends State<HubSettingsPage> {
  late final TextEditingController _keyCtrl;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.hub.repo.geminiApiKey);
    Future.microtask(() async {
      await widget.hub.ensureLoaded();
      if (mounted && _keyCtrl.text != widget.hub.repo.geminiApiKey) {
        setState(() {
          _keyCtrl.text = widget.hub.repo.geminiApiKey;
        });
      }
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = HubStrings.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([widget.hub, widget.settings]),
      builder: (context, _) {
        final hub = widget.hub;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              dark: dark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.quickLanguageLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'fa', label: Text('فارسی')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {
                      widget.settings.language == 'fa' ||
                              (widget.settings.language.isEmpty && s.isFa)
                          ? 'fa'
                          : 'en',
                    },
                    onSelectionChanged: (v) =>
                        widget.settings.update(language: v.first),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              dark: dark,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.rocket_launch_rounded),
                    title: Text(s.boostBeforeLaunchLabel),
                    subtitle: Text(
                      s.speedBoostHonestNote,
                      style: theme.textTheme.bodySmall,
                    ),
                    value: hub.repo.boostBeforeLaunch,
                    onChanged: hub.setBoostBeforeLaunch,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.shield_outlined),
                    title: Text(s.useVpnForStoresLabel),
                    value: hub.repo.useVpnProxyForStores,
                    onChanged: hub.setUseVpnProxyForStores,
                  ),
                  if (Platform.isAndroid) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        hub.device.hasUsageAccess
                            ? Icons.verified_user_rounded
                            : Icons.admin_panel_settings_outlined,
                        color: hub.device.hasUsageAccess
                            ? DarkGlassPalette.mint
                            : DarkGlassPalette.amber,
                      ),
                      title: Text(s.freeStorage),
                      subtitle: Text(
                        hub.device.hasUsageAccess
                            ? s.usageAccessGranted
                            : s.usageAccessMissing,
                      ),
                      trailing: hub.device.hasUsageAccess
                          ? Icon(
                              Icons.check_circle_outline_rounded,
                              color: DarkGlassPalette.mint,
                              size: 20,
                            )
                          : TextButton(
                              onPressed: () =>
                                  hub.platform.openUsageAccessSettings(),
                              child: Text(s.grantUsageAccess),
                            ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              dark: dark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.geminiApiKeyLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.geminiApiKeyHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _keyCtrl,
                    obscureText: _obscureKey,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'AIza...',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_keyCtrl.text.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            setState(() => _keyCtrl.clear());
                            await hub.setGeminiApiKey('');
                          },
                          child: Text(s.delete),
                        ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          await hub.setGeminiApiKey(_keyCtrl.text);
                          if (!context.mounted) return;
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(
                              content: Text(s.done),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Text(s.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
