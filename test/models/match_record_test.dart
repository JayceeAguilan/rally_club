import 'package:flutter_test/flutter_test.dart';
import 'package:rally_club/models/match_record.dart';

void main() {
  MatchRecord buildDoublesMatch() {
    return MatchRecord(
      id: 'm1',
      gameMode: 'doubles',
      matchLogic: 'auto',
      teamAPlayerIds: 'p1,p2',
      teamBPlayerIds: 'p3,p4',
      teamANames: 'Jaycee, Jamie',
      teamBNames: 'Alex, Sam',
      teamAPlayerRatings: '3.25,3.4',
      teamBPlayerRatings: '3.1,2.95',
      winningSide: 'A',
      date: '2026-04-10T09:00:00.000',
    );
  }

  test('player helpers expose partners, opponents, and result', () {
    final match = buildDoublesMatch();

    expect(match.includesPlayer('p1'), isTrue);
    expect(match.sideForPlayer('p1'), 'A');
    expect(match.didPlayerWin('p1'), isTrue);
    expect(match.partnerNamesFor('p1'), ['Jamie']);
    expect(match.opponentNamesFor('p1'), ['Alex', 'Sam']);
  });

  test('rating snapshot helpers parse stored DUPR values', () {
    final match = buildDoublesMatch();

    expect(match.teamAPlayerRatingList, [3.25, 3.4]);
    expect(match.teamBPlayerRatingList, [3.1, 2.95]);
  });

  test('singles players have no partners and the other side as opponents', () {
    final match = MatchRecord(
      id: 'm2',
      gameMode: 'singles',
      matchLogic: 'history',
      teamAPlayerIds: 'p1',
      teamBPlayerIds: 'p5',
      teamANames: 'Jaycee',
      teamBNames: 'Taylor',
      winningSide: 'B',
      date: '2026-04-11T11:00:00.000',
    );

    expect(match.didPlayerWin('p1'), isFalse);
    expect(match.partnerNamesFor('p1'), isEmpty);
    expect(match.opponentNamesFor('p1'), ['Taylor']);
  });
}
