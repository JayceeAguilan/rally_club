import 'package:flutter_test/flutter_test.dart';
import 'package:rally_club/models/app_user.dart';

void main() {
  group('AppUser', () {
    final sampleMap = {
      'uid': 'u1',
      'email': 'alice@example.com',
      'playerId': 'p1',
      'clubId': 'c1',
      'role': 'admin',
      'joinedAt': '2025-01-01T00:00:00Z',
    };

    test('fromMap creates instance with all fields', () {
      final user = AppUser.fromMap(sampleMap);

      expect(user.uid, 'u1');
      expect(user.email, 'alice@example.com');
      expect(user.playerId, 'p1');
      expect(user.clubId, 'c1');
      expect(user.role, 'admin');
      expect(user.joinedAt, '2025-01-01T00:00:00Z');
    });

    test('fromMap applies defaults for missing optional fields', () {
      final user = AppUser.fromMap({'uid': 'u2', 'joinedAt': '2025-06-01'});

      expect(user.email, '');
      expect(user.playerId, isNull);
      expect(user.clubId, isNull);
      expect(user.role, 'member');
    });

    test('toMap round-trips through fromMap', () {
      final original = AppUser(
        uid: 'u1',
        email: 'bob@example.com',
        playerId: 'p2',
        clubId: 'c2',
        role: 'member',
        joinedAt: '2025-03-15',
      );

      final restored = AppUser.fromMap(original.toMap());

      expect(restored.uid, original.uid);
      expect(restored.email, original.email);
      expect(restored.playerId, original.playerId);
      expect(restored.clubId, original.clubId);
      expect(restored.role, original.role);
      expect(restored.joinedAt, original.joinedAt);
    });

    test('copyWith overrides only specified fields', () {
      final user = AppUser.fromMap(sampleMap);
      final copy = user.copyWith(email: 'new@example.com', role: 'member');

      expect(copy.uid, user.uid);
      expect(copy.email, 'new@example.com');
      expect(copy.role, 'member');
      expect(copy.playerId, user.playerId);
      expect(copy.clubId, user.clubId);
      expect(copy.joinedAt, user.joinedAt);
    });

    test('copyWith with no args returns identical values', () {
      final user = AppUser.fromMap(sampleMap);
      final copy = user.copyWith();

      expect(copy.uid, user.uid);
      expect(copy.email, user.email);
      expect(copy.playerId, user.playerId);
      expect(copy.clubId, user.clubId);
      expect(copy.role, user.role);
      expect(copy.joinedAt, user.joinedAt);
    });
  });
}
