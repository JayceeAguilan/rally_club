import 'package:flutter_test/flutter_test.dart';
import 'package:rally_club/models/match_record.dart';
import 'package:rally_club/models/player.dart';
import 'package:rally_club/player_standings_utils.dart';

void main() {
  List<Player> buildPlayers() {
    return [
      Player(
        id: 'p1',
        name: 'Jaycee',
        gender: 'Male',
        isAvailable: true,
      ),
      Player(
        id: 'p2',
        name: 'Jamie',
        gender: 'Female',
        isAvailable: true,
      ),
      Player(
        id: 'p3',
        name: 'Alex',
        gender: 'Male',
        isAvailable: true,
      ),
      Player(
        id: 'p4',
        name: 'Sam',
        gender: 'Female',
        isAvailable: true,
      ),
    ];
  }

  List<MatchRecord> buildMatches() {
    return [
      MatchRecord(
        id: 'm3',
        gameMode: 'doubles',
        matchLogic: 'auto',
        teamAPlayerIds: 'p1,p2',
        teamBPlayerIds: 'p3,p4',
        teamANames: 'Jaycee, Jamie',
        teamBNames: 'Alex, Sam',
        winningSide: 'A',
        date: '2026-04-10T09:00:00.000',
      ),
      MatchRecord(
        id: 'm2',
        gameMode: 'doubles',
        matchLogic: 'auto',
        teamAPlayerIds: 'p1,p2',
        teamBPlayerIds: 'p3,p4',
        teamANames: 'Jaycee, Jamie',
        teamBNames: 'Alex, Sam',
        winningSide: 'A',
        date: '2026-04-09T09:00:00.000',
      ),
      MatchRecord(
        id: 'm1',
        gameMode: 'singles',
        matchLogic: 'history',
        teamAPlayerIds: 'p1',
        teamBPlayerIds: 'p3',
        teamANames: 'Jaycee',
        teamBNames: 'Alex',
        winningSide: 'B',
        date: '2026-04-08T09:00:00.000',
      ),
    ];
  }

  test('buildPlayerStandings calculates trend metrics and chemistry', () {
    final standings = buildPlayerStandings(
      players: buildPlayers(),
      matches: buildMatches(),
    );

    final jaycee = standings.firstWhere(
      (entry) => (entry['player'] as Player).id == 'p1',
    );

    expect(jaycee['wins'], 2);
    expect(jaycee['losses'], 1);
    expect(jaycee['matchesPlayed'], 3);
    expect(jaycee['winPercent'], closeTo(66.666, 0.01));
    expect(jaycee['streakLabel'], 'W2');
    expect(jaycee['currentStreak'], 2);
    expect(jaycee['recentResults'], ['W', 'W', 'L']);
    expect(jaycee['recentFormScore'], closeTo(66.666, 0.01));
    expect(jaycee['bestPartnerName'], 'Jamie');
    expect(jaycee['bestPartnerGames'], 2);
    expect(jaycee['bestPartnerWins'], 2);
    expect(jaycee['bestPartnerWinPercent'], 100.0);

    final jayceePlayer = jaycee['player'] as Player;
    expect(jayceePlayer.duprMatchesPlayed, 3);
    expect(jayceePlayer.duprRating, greaterThan(2.0));
    expect(jayceePlayer.displaySkillLabel, isNot('Unrated'));
  });

  test('players without doubles partners still get standings metrics', () {
    final standings = buildPlayerStandings(
      players: buildPlayers(),
      matches: [
        MatchRecord(
          id: 'm1',
          gameMode: 'singles',
          matchLogic: 'history',
          teamAPlayerIds: 'p4',
          teamBPlayerIds: 'p3',
          teamANames: 'Sam',
          teamBNames: 'Alex',
          winningSide: 'A',
          date: '2026-04-08T09:00:00.000',
        ),
      ],
    );

    final sam = standings.firstWhere(
      (entry) => (entry['player'] as Player).id == 'p4',
    );

    expect(sam['wins'], 1);
    expect(sam['matchesPlayed'], 1);
    expect(sam['streakLabel'], 'W1');
    expect(sam['bestPartnerName'], isNull);
    expect(sam['bestPartnerGames'], 0);

    final samPlayer = sam['player'] as Player;
    expect(samPlayer.duprMatchesPlayed, 1);
    expect(samPlayer.duprRating, greaterThan(2.0));
  });
}
