import 'package:flutter_test/flutter_test.dart';
import 'package:rally_club/models/player.dart';
import 'package:rally_club/session_guest_player_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SessionGuestPlayerStore.instance.clear();
    await SessionGuestPlayerStore.instance.loadPersistedGuests(
      forceRefresh: true,
    );
  });

  test(
    'guest store upserts, persists, updates, and clears session players',
    () async {
      final store = SessionGuestPlayerStore.instance;
      final guest = Player(
        id: store.createGuestId(),
        name: 'Drop-in Dana',
        gender: 'Female',
        skillLevel: 'Beg',
        isAvailable: true,
        isGuest: true,
      );

      await store.upsert(guest);
      await store.loadPersistedGuests(forceRefresh: true);
      expect(store.players, hasLength(1));
      expect(store.players.single.isGuest, isTrue);

      await store.upsert(guest.copyWith(isAvailable: false));
      await store.loadPersistedGuests(forceRefresh: true);
      expect(store.players.single.isAvailable, isFalse);

      await store.clear();
      await store.loadPersistedGuests(forceRefresh: true);
      expect(store.players, isEmpty);
    },
  );

  test(
    'mergeSessionPlayers excludes guests that duplicate permanent names',
    () {
      final mergedPlayers = SessionGuestPlayerStore.mergeSessionPlayers(
        permanentPlayers: [
          Player(
            id: 'permanent-mj',
            name: 'MJ',
            gender: 'Male',
            skillLevel: 'Beg',
            isAvailable: true,
          ),
        ],
        guestPlayers: [
          Player(
            id: 'guest-mj',
            name: ' mj ',
            gender: 'Male',
            skillLevel: 'Beg',
            isAvailable: true,
            isGuest: true,
          ),
        ],
      );

      expect(mergedPlayers, hasLength(1));
      expect(mergedPlayers.single.id, 'permanent-mj');
    },
  );
}
