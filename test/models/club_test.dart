import 'package:flutter_test/flutter_test.dart';
import 'package:rally_club/models/club.dart';

void main() {
  group('Club', () {
    test('defaultClubId is rally_club_default', () {
      expect(Club.defaultClubId, 'rally_club_default');
    });

    test('fromMap creates instance with all fields', () {
      final club = Club.fromMap({
        'id': 'c1',
        'name': 'Rally Club',
        'createdAt': '2025-01-01',
      });

      expect(club.id, 'c1');
      expect(club.name, 'Rally Club');
      expect(club.createdAt, '2025-01-01');
    });

    test('fromMap defaults missing values to empty strings', () {
      final club = Club.fromMap({});

      expect(club.id, '');
      expect(club.name, '');
      expect(club.createdAt, '');
    });

    test('toMap round-trips through fromMap', () {
      final original = Club(
        id: 'c2',
        name: 'Court Kings',
        createdAt: '2025-06-15T12:00:00Z',
      );

      final restored = Club.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
