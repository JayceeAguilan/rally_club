import 'package:flutter_test/flutter_test.dart';

import 'package:rally_club/auth_provider.dart';

void main() {
  group('AuthProvider.buildPlayerParticipationPatch', () {
    final now = DateTime.parse('2026-04-04T12:00:00Z');

    test('disables admin-linked player participation and availability', () {
      final patch = AuthProvider.buildPlayerParticipationPatch(
        role: 'admin',
        playerData: {'countsAsPlayer': 1, 'isAvailable': 1},
        now: now,
      );

      expect(
        patch,
        equals({
          'countsAsPlayer': 0,
          'isAvailable': 0,
          'updatedAt': now.toIso8601String(),
        }),
      );
    });

    test('re-enables member participation without forcing availability on', () {
      final patch = AuthProvider.buildPlayerParticipationPatch(
        role: 'member',
        playerData: {'countsAsPlayer': 0, 'isAvailable': 0},
        now: now,
      );

      expect(
        patch,
        equals({'countsAsPlayer': 1, 'updatedAt': now.toIso8601String()}),
      );
    });

    test('returns no patch when member player already counts normally', () {
      final patch = AuthProvider.buildPlayerParticipationPatch(
        role: 'member',
        playerData: {'countsAsPlayer': 1, 'isAvailable': 1},
        now: now,
      );

      expect(patch, isEmpty);
    });
  });
}
