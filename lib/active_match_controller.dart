import 'dart:async';

import 'package:flutter/foundation.dart';

import 'match_generator.dart';
import 'models/player.dart';
import 'offline_cache_store.dart';

class ActiveMatchController extends ChangeNotifier {
  ActiveMatchController({OfflineCacheStore? cacheStore})
    : _cacheStore = cacheStore ?? OfflineCacheStore.instance {
    _restoreFuture = _restorePersistedState();
  }

  static const String _cacheKey = 'active_match_state_v1';

  final OfflineCacheStore _cacheStore;
  late final Future<void> _restoreFuture;

  GeneratedMatch? _activeMatch;
  bool _isExpanded = false;
  int _sessionId = 0;
  bool _isRestoring = true;
  String _selectedWinner = 'A';
  bool _hasExplicitWinner = false;

  GeneratedMatch? get activeMatch => _activeMatch;
  bool get hasActiveMatch => _activeMatch != null;
  bool get isExpanded => _activeMatch != null && _isExpanded;
  int get sessionId => _sessionId;
  bool get isRestoring => _isRestoring;
  String get selectedWinner => _selectedWinner;
  bool get hasExplicitWinner => _hasExplicitWinner;
  Future<void> get restoreComplete => _restoreFuture;

  void startMatch(
    GeneratedMatch match, {
    bool isExpanded = true,
    String selectedWinner = 'A',
  }) {
    _activeMatch = match;
    _isExpanded = isExpanded;
    _selectedWinner = _normalizeSelectedWinner(selectedWinner);
    _hasExplicitWinner = false;
    _sessionId += 1;
    notifyListeners();
    unawaited(_persistState());
  }

  void setSelectedWinner(String winner) {
    if (_activeMatch == null) {
      return;
    }

    final normalizedWinner = _normalizeSelectedWinner(winner);
    if (_selectedWinner == normalizedWinner && _hasExplicitWinner) {
      return;
    }

    _selectedWinner = normalizedWinner;
    _hasExplicitWinner = true;
    notifyListeners();
    unawaited(_persistState());
  }

  void expand() {
    if (_activeMatch == null || _isExpanded) {
      return;
    }

    _isExpanded = true;
    notifyListeners();
    unawaited(_persistState());
  }

  void minimize() {
    if (_activeMatch == null || !_isExpanded) {
      return;
    }

    _isExpanded = false;
    notifyListeners();
    unawaited(_persistState());
  }

  void clear() {
    if (_activeMatch == null &&
        !_isExpanded &&
        _selectedWinner == 'A' &&
        !_hasExplicitWinner) {
      return;
    }

    _activeMatch = null;
    _isExpanded = false;
    _selectedWinner = 'A';
    _hasExplicitWinner = false;
    notifyListeners();
    unawaited(_cacheStore.remove(_cacheKey));
  }

  Future<void> _restorePersistedState() async {
    try {
      final cachedState = await _cacheStore.readMap(_cacheKey);
      if (cachedState == null || _activeMatch != null) {
        return;
      }

      final restoredMatch = _matchFromCache(cachedState['match']);
      if (restoredMatch == null) {
        await _cacheStore.remove(_cacheKey);
        return;
      }

      _activeMatch = restoredMatch;
      _isExpanded = cachedState['isExpanded'] == true;
      _selectedWinner = _normalizeSelectedWinner(
        cachedState['selectedWinner'] as String?,
      );
      _hasExplicitWinner = cachedState['hasExplicitWinner'] == true;
      _sessionId += 1;
    } catch (_) {
      await _cacheStore.remove(_cacheKey);
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> _persistState() async {
    if (_activeMatch == null) {
      await _cacheStore.remove(_cacheKey);
      return;
    }

    await _cacheStore.writeMap(_cacheKey, {
      'selectedWinner': _selectedWinner,
      'hasExplicitWinner': _hasExplicitWinner,
      'isExpanded': _isExpanded,
      'match': _matchToCache(_activeMatch!),
    });
  }

  String _normalizeSelectedWinner(String? winner) {
    return winner == 'B' ? 'B' : 'A';
  }

  Map<String, dynamic> _matchToCache(GeneratedMatch match) {
    return {
      'gameMode': match.gameMode,
      'matchLogic': match.matchLogic,
      'teamA': match.teamA.map(_playerToCache).toList(),
      'teamB': match.teamB.map(_playerToCache).toList(),
    };
  }

  GeneratedMatch? _matchFromCache(Object? rawMatch) {
    if (rawMatch is! Map) {
      return null;
    }

    final matchMap = Map<String, dynamic>.from(rawMatch);
    final gameMode = matchMap['gameMode']?.toString();
    final matchLogic = matchMap['matchLogic']?.toString();
    final teamA = _playersFromCache(matchMap['teamA']);
    final teamB = _playersFromCache(matchMap['teamB']);

    if (gameMode == null ||
        matchLogic == null ||
        teamA == null ||
        teamB == null ||
        teamA.isEmpty ||
        teamB.isEmpty) {
      return null;
    }

    return GeneratedMatch(
      teamA: teamA,
      teamB: teamB,
      gameMode: gameMode,
      matchLogic: matchLogic,
    );
  }

  List<Player>? _playersFromCache(Object? rawPlayers) {
    if (rawPlayers is! List) {
      return null;
    }

    try {
      return rawPlayers
          .map(
            (entry) => Player.fromMap(Map<String, dynamic>.from(entry as Map)),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _playerToCache(Player player) {
    return {
      'id': player.id,
      'name': player.name,
      'gender': player.gender,
      'skillLevel': player.skillLevel,
      'duprRating': player.duprRating,
      'duprMatchesPlayed': player.duprMatchesPlayed,
      'duprLastUpdatedAt': player.duprLastUpdatedAt,
      'countsAsPlayer': player.countsAsPlayer ? 1 : 0,
      'isAvailable': player.isAvailable ? 1 : 0,
      'notes': player.notes,
      'lastResult': player.lastResult,
      'isActive': player.isActive ? 1 : 0,
      'createdAt': player.createdAt,
      'updatedAt': player.updatedAt,
      'profileImageBase64': player.profileImageBase64,
      'clubId': player.clubId,
      'ownerUid': player.ownerUid,
      'isLegacy': player.isLegacy ? 1 : 0,
      'isGuest': player.isGuest ? 1 : 0,
    };
  }
}
