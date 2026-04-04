import 'package:flutter_test/flutter_test.dart';
import 'package:rally_club/models/player.dart';

void main() {
  group('Player', () {
    final fullMap = {
      'id': 'p1',
      'name': 'Alice',
      'gender': 'Female',
      'skillLevel': 'Adv',
      'isAvailable': 1,
      'notes': 'Left-handed',
      'lastResult': 'win',
      'isActive': 1,
      'createdAt': '2025-01-01',
      'updatedAt': '2025-06-01',
      'profileImageBase64': 'abc123',
      'clubId': 'c1',
      'ownerUid': 'u1',
      'isLegacy': 0,
    };

    group('fromMap', () {
      test('creates instance with all fields', () {
        final p = Player.fromMap(fullMap);

        expect(p.id, 'p1');
        expect(p.name, 'Alice');
        expect(p.gender, 'Female');
        expect(p.skillLevel, 'Adv');
        expect(p.isAvailable, true);
        expect(p.notes, 'Left-handed');
        expect(p.lastResult, 'win');
        expect(p.isActive, true);
        expect(p.clubId, 'c1');
        expect(p.ownerUid, 'u1');
        expect(p.isLegacy, false);
      });

      test('converts int 0 to false for boolean fields', () {
        final p = Player.fromMap({
          ...fullMap,
          'isAvailable': 0,
          'isActive': 0,
          'isLegacy': 1,
        });

        expect(p.isAvailable, false);
        expect(p.isActive, false);
        expect(p.isLegacy, true);
      });

      test('defaults missing optional fields', () {
        final p = Player.fromMap({
          'name': 'Bob',
          'gender': 'Male',
          'skillLevel': 'Beg',
          'isAvailable': 0,
        });

        expect(p.id, isNull);
        expect(p.notes, '');
        expect(p.lastResult, 'none');
        expect(p.isActive, true);
        expect(p.isLegacy, false);
        expect(p.clubId, isNull);
        expect(p.ownerUid, isNull);
      });
    });

    group('toMap', () {
      test('converts booleans to integers', () {
        final p = Player(
          name: 'Carol',
          gender: 'Female',
          skillLevel: 'Int',
          isAvailable: true,
          isActive: false,
          isLegacy: true,
        );

        final map = p.toMap();

        expect(map['isAvailable'], 1);
        expect(map['isActive'], 0);
        expect(map['isLegacy'], 1);
      });

      test('sets createdAt and updatedAt timestamps', () {
        final p = Player(
          name: 'Dave',
          gender: 'Male',
          skillLevel: 'Pro',
          isAvailable: false,
        );

        final map = p.toMap();

        expect(map['createdAt'], isNotNull);
        expect(map['updatedAt'], isNotNull);
      });

      test('preserves existing createdAt', () {
        final p = Player(
          name: 'Eve',
          gender: 'Female',
          skillLevel: 'Beg',
          isAvailable: true,
          createdAt: '2025-01-01',
        );

        final map = p.toMap();

        expect(map['createdAt'], '2025-01-01');
      });

      test('profile update map contains only editable fields', () {
        final p = Player(
          id: 'p3',
          name: 'Gina',
          gender: 'Female',
          skillLevel: 'Adv',
          isAvailable: true,
          notes: 'Ready to play',
          lastResult: 'win',
          isActive: false,
          createdAt: '2025-01-01',
          profileImageBase64: 'abc123',
          clubId: 'club-1',
          ownerUid: 'user-1',
          isLegacy: true,
        );

        final map = p.toProfileUpdateMap();

        expect(
          map.keys.toSet(),
          {
            'name',
            'gender',
            'skillLevel',
            'isAvailable',
            'notes',
            'profileImageBase64',
            'updatedAt',
          },
        );
        expect(map['name'], 'Gina');
        expect(map['isAvailable'], 1);
        expect(map.containsKey('clubId'), isFalse);
        expect(map.containsKey('ownerUid'), isFalse);
        expect(map.containsKey('countsAsPlayer'), isFalse);
      });
    });

    group('toMap / fromMap round-trip', () {
      test('restores all fields after serialization', () {
        final original = Player(
          id: 'p2',
          name: 'Frank',
          gender: 'Male',
          skillLevel: 'Pro',
          isAvailable: false,
          notes: 'Prefers morning sessions',
          lastResult: 'loss',
          isActive: true,
          createdAt: '2025-02-01',
          clubId: 'c2',
          ownerUid: 'u2',
          isLegacy: true,
        );

        final restored = Player.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.gender, original.gender);
        expect(restored.skillLevel, original.skillLevel);
        expect(restored.isAvailable, original.isAvailable);
        expect(restored.notes, original.notes);
        expect(restored.lastResult, original.lastResult);
        expect(restored.isActive, original.isActive);
        expect(restored.createdAt, original.createdAt);
        expect(restored.clubId, original.clubId);
        expect(restored.ownerUid, original.ownerUid);
        expect(restored.isLegacy, original.isLegacy);
      });
    });

    group('copyWith', () {
      test('overrides only specified fields', () {
        final p = Player.fromMap(fullMap);
        final copy = p.copyWith(name: 'Alicia', skillLevel: 'Pro');

        expect(copy.name, 'Alicia');
        expect(copy.skillLevel, 'Pro');
        expect(copy.id, p.id);
        expect(copy.gender, p.gender);
        expect(copy.isAvailable, p.isAvailable);
        expect(copy.clubId, p.clubId);
      });

      test('can toggle boolean fields', () {
        final p = Player.fromMap(fullMap);
        final copy = p.copyWith(isAvailable: false, isActive: false, isLegacy: true);

        expect(copy.isAvailable, false);
        expect(copy.isActive, false);
        expect(copy.isLegacy, true);
      });

      test('with no args returns identical values', () {
        final p = Player.fromMap(fullMap);
        final copy = p.copyWith();

        expect(copy.name, p.name);
        expect(copy.gender, p.gender);
        expect(copy.skillLevel, p.skillLevel);
        expect(copy.isAvailable, p.isAvailable);
        expect(copy.isActive, p.isActive);
        expect(copy.isLegacy, p.isLegacy);
        expect(copy.clubId, p.clubId);
        expect(copy.ownerUid, p.ownerUid);
      });
    });

    group('isOwnedByUser', () {
      test('matches when linked player id is current', () {
        final player = Player.fromMap(fullMap);

        final ownsProfile = player.isOwnedByUser(
          linkedPlayerId: 'p1',
          userUid: 'different-user',
        );

        expect(ownsProfile, isTrue);
      });

      test('falls back to owner uid when player link is missing', () {
        final player = Player.fromMap(fullMap);

        final ownsProfile = player.isOwnedByUser(
          linkedPlayerId: null,
          userUid: 'u1',
        );

        expect(ownsProfile, isTrue);
      });

      test('returns false when neither link matches', () {
        final player = Player.fromMap(fullMap);

        final ownsProfile = player.isOwnedByUser(
          linkedPlayerId: 'p2',
          userUid: 'u2',
        );

        expect(ownsProfile, isFalse);
      });
    });
  });
}
