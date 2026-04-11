import 'package:flutter_test/flutter_test.dart';
import 'package:rally_club/models/player.dart';

void main() {
  group('Player', () {
    final fullMap = {
      'id': 'p1',
      'name': 'Alice',
      'gender': 'Female',
      'skillLevel': 'Adv',
      'duprRating': 4.35,
      'duprMatchesPlayed': 9,
      'duprLastUpdatedAt': '2025-06-02T10:00:00.000',
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
      test('creates instance with DUPR fields and legacy values', () {
        final player = Player.fromMap(fullMap);

        expect(player.id, 'p1');
        expect(player.name, 'Alice');
        expect(player.gender, 'Female');
        expect(player.skillLevel, 'Adv');
        expect(player.duprRating, 4.35);
        expect(player.duprMatchesPlayed, 9);
        expect(player.duprLastUpdatedAt, '2025-06-02T10:00:00.000');
        expect(player.displaySkillLabel, 'Intermediate');
        expect(player.displayDuprRating, '4.35');
        expect(player.isAvailable, isTrue);
      });

      test('defaults to unrated baseline when DUPR fields are missing', () {
        final player = Player.fromMap({
          'name': 'Bob',
          'gender': 'Male',
          'isAvailable': 0,
        });

        expect(player.id, isNull);
        expect(player.notes, '');
        expect(player.lastResult, 'none');
        expect(player.isActive, isTrue);
        expect(player.duprRating, 2.0);
        expect(player.duprMatchesPlayed, 0);
        expect(player.displaySkillLabel, 'Unrated');
        expect(player.displayDuprLabel, 'DUPR 2.00 BASELINE');
      });

      test('converts int flags to booleans', () {
        final player = Player.fromMap({
          ...fullMap,
          'isAvailable': 0,
          'isActive': 0,
          'isLegacy': 1,
          'isGuest': 1,
        });

        expect(player.isAvailable, isFalse);
        expect(player.isActive, isFalse);
        expect(player.isLegacy, isTrue);
        expect(player.isGuest, isTrue);
      });
    });

    group('toMap', () {
      test('converts booleans to integers and persists DUPR fields', () {
        final player = Player(
          name: 'Carol',
          gender: 'Female',
          duprRating: 3.75,
          duprMatchesPlayed: 6,
          duprLastUpdatedAt: '2025-06-01T10:00:00.000',
          isAvailable: true,
          isActive: false,
          isLegacy: true,
        );

        final map = player.toMap();

        expect(map['isAvailable'], 1);
        expect(map['isActive'], 0);
        expect(map['isLegacy'], 1);
        expect(map['duprRating'], 3.75);
        expect(map['duprMatchesPlayed'], 6);
        expect(map['duprLastUpdatedAt'], '2025-06-01T10:00:00.000');
        expect(map.containsKey('skillLevel'), isFalse);
      });

      test('sets timestamps when missing', () {
        final player = Player(
          name: 'Dave',
          gender: 'Male',
          isAvailable: false,
        );

        final map = player.toMap();

        expect(map['createdAt'], isNotNull);
        expect(map['updatedAt'], isNotNull);
        expect(map['duprLastUpdatedAt'], isNotNull);
      });

      test('preserves existing createdAt', () {
        final player = Player(
          name: 'Eve',
          gender: 'Female',
          isAvailable: true,
          createdAt: '2025-01-01',
        );

        final map = player.toMap();

        expect(map['createdAt'], '2025-01-01');
      });

      test('profile update map contains only editable profile fields', () {
        final player = Player(
          id: 'p3',
          name: 'Gina',
          gender: 'Female',
          duprRating: 4.8,
          duprMatchesPlayed: 12,
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

        final map = player.toProfileUpdateMap();

        expect(map.keys.toSet(), {
          'name',
          'gender',
          'isAvailable',
          'notes',
          'profileImageBase64',
          'updatedAt',
        });
        expect(map['name'], 'Gina');
        expect(map['isAvailable'], 1);
        expect(map.containsKey('duprRating'), isFalse);
        expect(map.containsKey('skillLevel'), isFalse);
      });
    });

    group('toMap / fromMap round-trip', () {
      test('restores DUPR values after serialization', () {
        final original = Player(
          id: 'p2',
          name: 'Frank',
          gender: 'Male',
          duprRating: 4.62,
          duprMatchesPlayed: 18,
          duprLastUpdatedAt: '2025-06-10T09:00:00.000',
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
        expect(restored.duprRating, original.duprRating);
        expect(restored.duprMatchesPlayed, original.duprMatchesPlayed);
        expect(restored.duprLastUpdatedAt, original.duprLastUpdatedAt);
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
        final player = Player.fromMap(fullMap);
        final copy = player.copyWith(
          name: 'Alicia',
          duprRating: 4.9,
          duprMatchesPlayed: 14,
        );

        expect(copy.name, 'Alicia');
        expect(copy.duprRating, 4.9);
        expect(copy.duprMatchesPlayed, 14);
        expect(copy.id, player.id);
        expect(copy.gender, player.gender);
        expect(copy.isAvailable, player.isAvailable);
        expect(copy.clubId, player.clubId);
      });

      test('with no args returns identical values', () {
        final player = Player.fromMap(fullMap);
        final copy = player.copyWith();

        expect(copy.name, player.name);
        expect(copy.gender, player.gender);
        expect(copy.duprRating, player.duprRating);
        expect(copy.duprMatchesPlayed, player.duprMatchesPlayed);
        expect(copy.isAvailable, player.isAvailable);
        expect(copy.isActive, player.isActive);
        expect(copy.isLegacy, player.isLegacy);
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

    group('derived DUPR labels', () {
      test('returns unrated label until a recorded match exists', () {
        final player = Player(
          name: 'Baseline',
          gender: 'Male',
          isAvailable: true,
        );

        expect(player.displaySkillLabel, 'Unrated');
        expect(player.matchesSkillFilter('Unrated'), isTrue);
      });

      test('maps rating bands to beginner, intermediate, and advanced', () {
        final beginner = Player(
          name: 'Beginner',
          gender: 'Female',
          duprRating: 2.8,
          duprMatchesPlayed: 2,
          isAvailable: true,
        );
        final intermediate = Player(
          name: 'Intermediate',
          gender: 'Female',
          duprRating: 3.7,
          duprMatchesPlayed: 4,
          isAvailable: true,
        );
        final advanced = Player(
          name: 'Advanced',
          gender: 'Female',
          duprRating: 4.8,
          duprMatchesPlayed: 7,
          isAvailable: true,
        );

        expect(beginner.displaySkillLabel, 'Beginner');
        expect(intermediate.displaySkillLabel, 'Intermediate');
        expect(advanced.displaySkillLabel, 'Advanced');
      });

      test('matches filters against derived labels', () {
        final player = Player(
          name: 'Jordan',
          gender: 'Male',
          duprRating: 3.9,
          duprMatchesPlayed: 5,
          isAvailable: true,
        );

        expect(player.matchesSkillFilter('All'), isTrue);
        expect(player.matchesSkillFilter('Intermediate'), isTrue);
        expect(player.matchesSkillFilter('Advanced'), isFalse);
      });
    });
  });
}