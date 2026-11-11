import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arman_vpn/core/android_core.dart';
import 'package:arman_vpn/core/core_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app/android');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late bool running;
  late String coreError;
  Object? startCoreResult;

  setUp(() {
    running = false;
    coreError = '';
    startCoreResult = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'isRunning' => running,
        'coreError' => coreError,
        'startCore' => startCoreResult,
        _ => null,
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('connect reports coreError instead of hanging in starting forever', () async {
    coreError = 'open config.json: permission denied';
    startCoreResult = coreError;
    final core = AndroidCore('/nonexistent');
    await expectLater(
      core.connect(),
      throwsA(
        isA<CoreUnavailable>()
            .having((e) => e.problem, 'problem', CoreProblem.exited)
            .having((e) => e.detail, 'detail', contains('permission denied')),
      ),
    );
  });

  test('connect maps already-in-use coreError to portInUse', () async {
    coreError =
        'starting the dashboard: the dashboard address 127.0.0.1:10820 is already in use by another program';
    startCoreResult = coreError;
    final core = AndroidCore('/nonexistent');
    await expectLater(
      core.connect(),
      throwsA(
        isA<CoreUnavailable>()
            .having((e) => e.problem, 'problem', CoreProblem.portInUse)
            .having((e) => e.detail, 'detail', '127.0.0.1:10820'),
      ),
    );
  });

  test('connect exposes notAnswering once startupGrace elapses', () async {
    final dir = await Directory.systemTemp.createTemp('icedragon_android_core');
    addTearDown(() => dir.delete(recursive: true));
    running = true;
    var now = DateTime(2026, 1, 1, 12, 0, 0);
    final core = AndroidCore(
      dir.path,
      startupGrace: const Duration(seconds: 5),
      now: () => now,
    );

    await expectLater(
      core.connect(),
      throwsA(
        isA<CoreUnavailable>().having(
          (e) => e.problem,
          'problem',
          CoreProblem.starting,
        ),
      ),
    );

    now = now.add(const Duration(seconds: 6));
    await expectLater(
      core.connect(),
      throwsA(
        isA<CoreUnavailable>().having(
          (e) => e.problem,
          'problem',
          CoreProblem.notAnswering,
        ),
      ),
    );
  });

  test('connect translates PlatformException into CoreProblem.exited', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'native_error', message: 'libgojni missing');
    });
    final core = AndroidCore('/nonexistent');
    await expectLater(
      core.connect(),
      throwsA(
        isA<CoreUnavailable>()
            .having((e) => e.problem, 'problem', CoreProblem.exited)
            .having((e) => e.detail, 'detail', 'libgojni missing'),
      ),
    );
  });
}
