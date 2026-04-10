import 'package:flutter_test/flutter_test.dart';
import 'package:rally_club/models/match_record.dart';
import 'package:rally_club/models/player.dart';
import 'package:rally_club/player_standings_utils.dart';

void main() {
  test('guest ids do not create standalone standings entries', () {
    final alice = Player(
      id: 'p-alice',
      name: 'Alice',
      gender: 'Female',
      skillLevel: 'Int',
      isAvailable: true,
    );
    final ben = Player(
      id: 'p-ben',
      name: 'Ben',
      gender: 'Male',
      skillLevel: 'Int',
      isAvailable: true,
    );

    final match = MatchRecord(
      gameMode: 'doubles',
      matchLogic: 'auto',
      teamAPlayerIds: 'p-alice,guest:one',
      teamBPlayerIds: 'p-ben,guest:two',
      teamANames: 'Alice, Guest One',
      teamBNames: 'Ben, Guest Two',
      winningSide: 'A',
      date: '2026-04-10T10:00:00.000Z',
    );

    final standings = buildPlayerStandings(
      players: [alice, ben],
      matches: [match],
    );

    expect(standings, hasLength(2));

    final aliceStanding = standings.firstWhere(
      (entry) => (entry['player'] as Player).id == 'p-alice',
    );
    final benStanding = standings.firstWhere(
      (entry) => (entry['player'] as Player).id == 'p-ben',
    );

    expect(aliceStanding['wins'], 1);
    expect(aliceStanding['matchesPlayed'], 1);
    expect(benStanding['losses'], 1);
    expect(benStanding['matchesPlayed'], 1);
  });
}
