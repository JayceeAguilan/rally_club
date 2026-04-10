import 'models/player.dart';

class SessionGuestPlayerStore {
  SessionGuestPlayerStore._();

  static final SessionGuestPlayerStore instance = SessionGuestPlayerStore._();

  final List<Player> _guestPlayers = <Player>[];
  int _sequence = 0;

  List<Player> get players => List<Player>.unmodifiable(_guestPlayers);

  String createGuestId() {
    _sequence += 1;
    return '${Player.guestIdPrefix}${DateTime.now().microsecondsSinceEpoch}_$_sequence';
  }

  void upsert(Player player) {
    final guestPlayer = player.isGuest
        ? player
        : player.copyWith(isGuest: true);
    final existingIndex = _guestPlayers.indexWhere(
      (existing) => existing.id == guestPlayer.id,
    );

    if (existingIndex == -1) {
      _guestPlayers.add(guestPlayer);
      return;
    }

    _guestPlayers[existingIndex] = guestPlayer;
  }

  void remove(String playerId) {
    _guestPlayers.removeWhere((player) => player.id == playerId);
  }

  void clear() {
    _guestPlayers.clear();
  }
}
