import 'package:flutter/foundation.dart';

import '../core/models.dart';

/// Shared in-memory cache of last measured country latencies (in milliseconds),
/// populated from [ServersPage] and queried by Home's quick-pick chips.
abstract final class LocationPingCache {
  static final latencies = ValueNotifier<Map<String, int>>(const {});

  static void recordAll(Iterable<Location> locations) {
    final next = Map<String, int>.from(latencies.value);
    var changed = false;
    for (final loc in locations) {
      final code = loc.code.trim().toUpperCase();
      if (code.isEmpty) continue;
      if (loc.answered) {
        if (next[code] != loc.pingMs) {
          next[code] = loc.pingMs;
          changed = true;
        }
      } else if (next.remove(code) != null) {
        changed = true;
      }
    }
    if (changed) latencies.value = Map.unmodifiable(next);
  }

  @visibleForTesting
  static void clear() => latencies.value = const {};
}
