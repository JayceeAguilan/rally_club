import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/player.dart';

class SessionGuestPlayerStore {
  SessionGuestPlayerStore._();

  static final SessionGuestPlayerStore instance = SessionGuestPlayerStore._();
  static const String _storageKey = 'session_guest_players_v1';

  final List<Player> _guestPlayers = <Player>[];
  int _sequence = 0;
  bool _hasLoadedPersistedGuests = false;
  Future<void>? _loadOperation;

  List<Player> get players => List<Player>.unmodifiable(_guestPlayers);

  static String normalizedPlayerName(Player player) {
    return player.name.trim().toLowerCase();
  }

  static List<Player> mergeSessionPlayers({
    required List<Player> permanentPlayers,
    required List<Player> guestPlayers,
  }) {
    final mergedPlayers = <Player>[];
    final seenPermanentNames = <String>{};
    final seenGuestNames = <String>{};

    for (final player in permanentPlayers) {
      mergedPlayers.add(player);
      final normalizedName = normalizedPlayerName(player);
      if (normalizedName.isNotEmpty) {
        seenPermanentNames.add(normalizedName);
      }
    }

    for (final guestPlayer in guestPlayers) {
      final normalizedName = normalizedPlayerName(guestPlayer);
      if (normalizedName.isEmpty) {
        continue;
      }
      if (seenPermanentNames.contains(normalizedName) ||
          seenGuestNames.contains(normalizedName)) {
        continue;
      }

      mergedPlayers.add(guestPlayer);
      seenGuestNames.add(normalizedName);
    }

    return mergedPlayers;
  }

  String createGuestId() {
    _sequence += 1;
    return '${Player.guestIdPrefix}${DateTime.now().microsecondsSinceEpoch}_$_sequence';
  }

  Future<void> loadPersistedGuests({bool forceRefresh = false}) async {
    if (_hasLoadedPersistedGuests && !forceRefresh) {
      return;
    }

    if (!forceRefresh && _loadOperation != null) {
      return _loadOperation!;
    }

    final future = _loadPersistedGuestsInternal();
    _loadOperation = future;
    try {
      await future;
    } finally {
      if (identical(_loadOperation, future)) {
        _loadOperation = null;
      }
    }
  }

  Future<void> _loadPersistedGuestsInternal() async {
    final prefs = await SharedPreferences.getInstance();
    final storedGuests = prefs.getString(_storageKey);

    _guestPlayers.clear();

    if (storedGuests == null || storedGuests.trim().isEmpty) {
      _hasLoadedPersistedGuests = true;
      return;
    }

    try {
      final decoded = jsonDecode(storedGuests);
      if (decoded is! List) {
        await prefs.remove(_storageKey);
        _hasLoadedPersistedGuests = true;
        return;
      }

      final restoredGuests = decoded
          .whereType<Object?>()
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .map(
            (entry) => Player.fromMap(
              entry,
            ).copyWith(isGuest: true, countsAsPlayer: true),
          )
          .where(
            (player) =>
                (player.id?.trim().isNotEmpty ?? false) &&
                player.name.trim().isNotEmpty,
          )
          .toList();

      _guestPlayers.addAll(restoredGuests);
    } catch (_) {
      _guestPlayers.clear();
      await prefs.remove(_storageKey);
    }

    _hasLoadedPersistedGuests = true;
  }

  Future<void> _persistGuests() async {
    final prefs = await SharedPreferences.getInstance();

    if (_guestPlayers.isEmpty) {
      await prefs.remove(_storageKey);
      return;
    }

    final serializedGuests = jsonEncode(
      _guestPlayers
          .map(
            (player) =>
                player.copyWith(isGuest: true, countsAsPlayer: true).toMap(),
          )
          .toList(),
    );

    await prefs.setString(_storageKey, serializedGuests);
  }

  Future<void> upsert(Player player) async {
    final guestPlayer = player.isGuest
        ? player
        : player.copyWith(isGuest: true);
    final existingIndex = _guestPlayers.indexWhere(
      (existing) => existing.id == guestPlayer.id,
    );

    if (existingIndex == -1) {
      _guestPlayers.add(guestPlayer);
      await _persistGuests();
      return;
    }

    _guestPlayers[existingIndex] = guestPlayer;
    await _persistGuests();
  }

  Future<void> remove(String playerId) async {
    _guestPlayers.removeWhere((player) => player.id == playerId);
    await _persistGuests();
  }

  Future<void> clear() async {
    _guestPlayers.clear();
    await _persistGuests();
  }
}
