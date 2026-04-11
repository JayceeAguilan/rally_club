import 'package:flutter_test/flutter_test.dart';
import 'package:rally_club/active_match_controller.dart';
import 'package:rally_club/match_generator.dart';
import 'package:rally_club/models/player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'restores persisted active match state across controller instances',
    () async {
      final controller = ActiveMatchController();
      await controller.restoreComplete;

      controller.startMatch(
        _sampleMatch(),
        isExpanded: false,
        selectedWinner: 'B',
      );
      await Future<void>.delayed(Duration.zero);

      final restoredController = ActiveMatchController();
      await restoredController.restoreComplete;

      expect(restoredController.hasActiveMatch, isTrue);
      expect(restoredController.activeMatch?.gameMode, 'doubles');
      expect(restoredController.activeMatch?.teamA.first.name, 'Alice');
      expect(restoredController.activeMatch?.teamB.first.name, 'Carlos');
      expect(restoredController.isExpanded, isFalse);
      expect(restoredController.selectedWinner, 'B');
    },
  );

  test('clear removes the persisted active match state', () async {
    final controller = ActiveMatchController();
    await controller.restoreComplete;

    controller.startMatch(_sampleMatch());
    await Future<void>.delayed(Duration.zero);
    controller.clear();
    await Future<void>.delayed(Duration.zero);

    final restoredController = ActiveMatchController();
    await restoredController.restoreComplete;

    expect(restoredController.hasActiveMatch, isFalse);
    expect(restoredController.activeMatch, isNull);
  });

  test('hasExplicitWinner is false on startMatch and true after setSelectedWinner', () async {
    final controller = ActiveMatchController();
    await controller.restoreComplete;

    controller.startMatch(_sampleMatch());
    expect(controller.hasExplicitWinner, isFalse);

    controller.setSelectedWinner('B');
    expect(controller.hasExplicitWinner, isTrue);
    expect(controller.selectedWinner, 'B');
  });

  test('hasExplicitWinner persists and restores across instances', () async {
    final controller = ActiveMatchController();
    await controller.restoreComplete;

    controller.startMatch(_sampleMatch());
    controller.setSelectedWinner('A');
    await Future<void>.delayed(Duration.zero);

    final restored = ActiveMatchController();
    await restored.restoreComplete;

    expect(restored.hasExplicitWinner, isTrue);
    expect(restored.selectedWinner, 'A');
  });

  test('clear resets hasExplicitWinner to false', () async {
    final controller = ActiveMatchController();
    await controller.restoreComplete;

    controller.startMatch(_sampleMatch());
    controller.setSelectedWinner('B');
    expect(controller.hasExplicitWinner, isTrue);

    controller.clear();
    expect(controller.hasExplicitWinner, isFalse);
  });
}

GeneratedMatch _sampleMatch() {
  return GeneratedMatch(
    teamA: [
      _player(id: 'a1', name: 'Alice', gender: 'Female'),
      _player(id: 'a2', name: 'Ben', gender: 'Male'),
    ],
    teamB: [
      _player(id: 'b1', name: 'Carlos', gender: 'Male'),
      _player(id: 'b2', name: 'Dina', gender: 'Female'),
    ],
    gameMode: 'doubles',
    matchLogic: 'auto',
  );
}

Player _player({
  required String id,
  required String name,
  required String gender,
}) {
  return Player(
    id: id,
    name: name,
    gender: gender,
    skillLevel: 'Intermediate',
    duprRating: 3.25,
    duprMatchesPlayed: 12,
    isAvailable: true,
  );
}
