import 'package:flutter_test/flutter_test.dart';
import 'package:rally_club/models/player.dart';
import 'package:rally_club/session_guest_player_store.dart';

void main() {
  setUp(() {
    SessionGuestPlayerStore.instance.clear();
  });

  test('guest store upserts, updates, and clears session players', () {
    final store = SessionGuestPlayerStore.instance;
    final guest = Player(
      id: store.createGuestId(),
      name: 'Drop-in Dana',
      gender: 'Female',
      skillLevel: 'Beg',
      isAvailable: true,
      isGuest: true,
    );

    store.upsert(guest);
    expect(store.players, hasLength(1));
    expect(store.players.single.isGuest, isTrue);

    store.upsert(guest.copyWith(isAvailable: false));
    expect(store.players.single.isAvailable, isFalse);

    store.clear();
    expect(store.players, isEmpty);
  });
}
