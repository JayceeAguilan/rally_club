import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/announcement.dart';
import 'models/announcement_comment.dart';
import 'models/announcement_inbox_status.dart';
import 'models/player.dart';
import 'models/match_record.dart';
import 'dupr_rating_engine.dart';
import 'offline_cache_store.dart';
import 'player_standings_utils.dart';
import 'sync_status.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SyncStatusController _syncStatus = SyncStatusController.instance;

  String _cachedUserKey(String uid) => 'offline.firebase.user.$uid';
  String _cachedPlayersKey(String clubId) => 'offline.firebase.players.$clubId';
  String _cachedMatchesKey(String clubId) => 'offline.firebase.matches.$clubId';
  String _cachedAnnouncementsKey(String clubId) =>
      'offline.firebase.announcements.$clubId';
  String _cachedAnnouncementInboxStatusKey(String uid, String clubId) =>
      'offline.firebase.announcement_inbox.$clubId.$uid';
  String _cachedCommentsKey(String clubId, String announcementId) =>
      'offline.firebase.comments.$clubId.$announcementId';
  String _cachedCommentKey(String commentId) =>
      'offline.firebase.comment.$commentId';

  Future<void> _cacheUserData(String uid, Map<String, dynamic> data) {
    return OfflineCacheStore.instance.writeMap(_cachedUserKey(uid), data);
  }

  Future<Map<String, dynamic>?> _readCachedUserData(String uid) {
    return OfflineCacheStore.instance.readMap(_cachedUserKey(uid));
  }

  Future<void> _cacheAnnouncementInboxStatus({
    required String actingUid,
    required String clubId,
    required AnnouncementInboxStatus status,
  }) {
    return OfflineCacheStore.instance.writeMap(
      _cachedAnnouncementInboxStatusKey(actingUid, clubId),
      status.toMap(),
    );
  }

  Future<AnnouncementInboxStatus?> getCachedAnnouncementInboxStatus({
    required String actingUid,
    required String clubId,
  }) async {
    final cached = await OfflineCacheStore.instance.readMap(
      _cachedAnnouncementInboxStatusKey(actingUid, clubId),
    );
    if (cached == null) {
      return null;
    }

    return AnnouncementInboxStatus.fromMap(cached);
  }

  Future<List<Map<String, dynamic>>> _loadCollectionWithOfflineFallback({
    required Future<QuerySnapshot<Map<String, dynamic>>> Function() loader,
    required String cacheKey,
  }) async {
    try {
      final snapshot = await loader();
      final rows = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
      await OfflineCacheStore.instance.writeList(cacheKey, rows);
      return rows;
    } catch (error) {
      final cached = await OfflineCacheStore.instance.readList(cacheKey);
      if (cached != null) {
        debugPrint(
          'FirebaseService: using offline snapshot for $cacheKey after read failure: $error',
        );
        return cached;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _readCachedComment(String commentId) {
    return OfflineCacheStore.instance.readMap(_cachedCommentKey(commentId));
  }

  Future<void> _cacheCommentRows(List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      final commentId = row['id'] as String?;
      if (commentId == null || commentId.isEmpty) {
        continue;
      }
      await OfflineCacheStore.instance.writeMap(
        _cachedCommentKey(commentId),
        row,
      );
    }
  }

  Future<Map<String, dynamic>> _getUserData(String uid) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        final cached = await _readCachedUserData(uid);
        if (cached != null) {
          return cached;
        }
        throw StateError('User profile not found.');
      }

      final data = Map<String, dynamic>.from(userDoc.data()!);
      await _cacheUserData(uid, data);
      return data;
    } catch (error) {
      final cached = await _readCachedUserData(uid);
      if (cached != null) {
        debugPrint(
          'FirebaseService: using offline user snapshot for $uid after read failure: $error',
        );
        return cached;
      }
      rethrow;
    }
  }

  Future<String> _resolveDisplayName(Map<String, dynamic> userData) async {
    final playerId = userData['playerId'] as String?;
    if (playerId != null && playerId.isNotEmpty) {
      final playerDoc = await _db.collection('players').doc(playerId).get();
      final name = playerDoc.data()?['name'] as String?;
      if (name != null && name.trim().isNotEmpty) {
        return name.trim();
      }
    }

    final email = userData['email'] as String? ?? '';
    if (email.trim().isNotEmpty) {
      return email.split('@').first;
    }

    return 'Rally Club Member';
  }

  Future<bool> _isAdminForClub({
    required String uid,
    required String clubId,
  }) async {
    final data = await _getUserData(uid);
    final role = data['role'] as String? ?? 'member';
    final userClubId = data['clubId'] as String?;
    return role == 'admin' && userClubId == clubId;
  }

  Future<void> _requireAdmin({
    required String uid,
    required String clubId,
  }) async {
    if (!await _isAdminForClub(uid: uid, clubId: clubId)) {
      throw StateError('Only admins can generate and save matches.');
    }
  }

  Future<void> _requireAdminOrOwnPlayer({
    required String uid,
    required String playerId,
    required String clubId,
  }) async {
    if (await _isAdminForClub(uid: uid, clubId: clubId)) {
      return;
    }

    final userData = await _getUserData(uid);
    final linkedPlayerId = userData['playerId'] as String?;
    final userClubId = userData['clubId'] as String?;

    if (linkedPlayerId == playerId && userClubId == clubId) {
      return;
    }

    Map<String, dynamic>? data;
    try {
      final playerDoc = await _db.collection('players').doc(playerId).get();
      if (playerDoc.exists) {
        data = Map<String, dynamic>.from(playerDoc.data()!)
          ..['id'] = playerDoc.id;
      }
    } catch (_) {
      data = null;
    }

    data ??= (await _readCachedPlayerById(
      clubId: clubId,
      playerId: playerId,
    ))?.toMap();
    if (data == null) {
      throw StateError('Player profile not found.');
    }

    final ownerUid = data['ownerUid'] as String?;
    final playerClubId = data['clubId'] as String?;

    if (ownerUid != uid || playerClubId != clubId) {
      throw StateError('You can only manage your own player profile.');
    }
  }

  Future<List<Player>> _readCachedPlayersSnapshot({
    required String clubId,
  }) async {
    final rows = await OfflineCacheStore.instance.readList(
      _cachedPlayersKey(clubId),
    );
    if (rows == null) {
      return const <Player>[];
    }

    return rows.map(Player.fromMap).where((player) => player.isActive).toList();
  }

  Future<Player?> _readCachedPlayerById({
    required String clubId,
    required String playerId,
  }) async {
    final players = await _readCachedPlayersSnapshot(clubId: clubId);
    for (final player in players) {
      if (player.id == playerId) {
        return player;
      }
    }
    return null;
  }

  Future<void> _cachePlayersSnapshot({
    required String clubId,
    required List<Player> players,
  }) {
    final rows = players.where((player) => player.isActive).map((player) {
      final data = player.toMap();
      if (player.id != null && player.id!.isNotEmpty) {
        data['id'] = player.id;
      }
      data['clubId'] = player.clubId ?? clubId;
      return data;
    }).toList();

    return OfflineCacheStore.instance.writeList(
      _cachedPlayersKey(clubId),
      rows,
    );
  }

  Future<List<MatchRecord>> _readCachedMatchesSnapshot({
    required String clubId,
  }) async {
    final rows = await OfflineCacheStore.instance.readList(
      _cachedMatchesKey(clubId),
    );
    if (rows == null) {
      return const <MatchRecord>[];
    }

    final matches = rows.map(MatchRecord.fromMap).toList();
    matches.sort((a, b) => b.date.compareTo(a.date));
    return matches;
  }

  Future<void> _cacheMatchesSnapshot({
    required String clubId,
    required List<MatchRecord> matches,
  }) {
    final rows = matches.map((match) {
      final data = match.toMap();
      if (match.id != null && match.id!.isNotEmpty) {
        data['id'] = match.id;
      }
      data['clubId'] = match.clubId ?? clubId;
      return data;
    }).toList();

    return OfflineCacheStore.instance.writeList(
      _cachedMatchesKey(clubId),
      rows,
    );
  }

  Future<List<Player>> _fetchRemotePlayersSnapshot({
    required String clubId,
  }) async {
    final snapshot = await _db
        .collection('players')
        .where('isActive', isEqualTo: 1)
        .where('clubId', isEqualTo: clubId)
        .get();

    final players = snapshot.docs
        .map((doc) => Player.fromMap({...doc.data(), 'id': doc.id}))
        .where((player) => player.isActive)
        .toList();
    await _cachePlayersSnapshot(clubId: clubId, players: players);
    return players;
  }

  Future<List<MatchRecord>> _fetchRemoteMatchesSnapshot({
    required String clubId,
  }) async {
    final snapshot = await _db
        .collection('matches')
        .where('clubId', isEqualTo: clubId)
        .orderBy('date', descending: true)
        .get();

    final matches = snapshot.docs
        .map((doc) => MatchRecord.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
    matches.sort((a, b) => b.date.compareTo(a.date));
    await _cacheMatchesSnapshot(clubId: clubId, matches: matches);
    return matches;
  }

  List<Player> _replacePlayerInSnapshot(List<Player> players, Player updated) {
    final nextPlayers = players
        .where((player) => player.id != updated.id)
        .toList();
    if (updated.isActive) {
      nextPlayers.add(updated);
    }
    nextPlayers.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    return nextPlayers;
  }

  List<MatchRecord> _replaceMatchInSnapshot(
    List<MatchRecord> matches,
    MatchRecord updated,
  ) {
    final nextMatches = matches
        .where((match) => match.id != updated.id)
        .toList();
    nextMatches.add(updated);
    nextMatches.sort((left, right) => right.date.compareTo(left.date));
    return nextMatches;
  }

  Future<List<Player>> _loadPlayersForWrite({required String clubId}) async {
    try {
      return await _fetchRemotePlayersSnapshot(clubId: clubId);
    } catch (error) {
      final cachedPlayers = await _readCachedPlayersSnapshot(clubId: clubId);
      if (cachedPlayers.isNotEmpty) {
        debugPrint(
          'FirebaseService: using cached players for write computation after remote read failure: $error',
        );
        return cachedPlayers;
      }
      rethrow;
    }
  }

  Future<List<MatchRecord>> _loadMatchesForWrite({
    required String clubId,
  }) async {
    try {
      return await _fetchRemoteMatchesSnapshot(clubId: clubId);
    } catch (error) {
      final cachedMatches = await _readCachedMatchesSnapshot(clubId: clubId);
      if (cachedMatches.isNotEmpty) {
        debugPrint(
          'FirebaseService: using cached matches for write computation after remote read failure: $error',
        );
        return cachedMatches;
      }
      return const <MatchRecord>[];
    }
  }

  // --- PLAYERS ---

  Future<void> insertPlayer(
    Player player, {
    required String clubId,
    required String ownerUid,
    required String actingUid,
  }) async {
    await _syncStatus.runTrackedWrite(() async {
      await _requireAdmin(uid: actingUid, clubId: clubId);

      final doc = _db.collection('players').doc();
      final insertedPlayer = player.copyWith(
        id: doc.id,
        clubId: clubId,
        ownerUid: ownerUid,
        isActive: true,
        isGuest: false,
      );
      final Map<String, dynamic> data = insertedPlayer.toMap();
      data['id'] = doc.id;
      data['clubId'] = clubId;
      data['ownerUid'] = ownerUid;
      await doc.set(data);

      final cachedPlayers = await _readCachedPlayersSnapshot(clubId: clubId);
      await _cachePlayersSnapshot(
        clubId: clubId,
        players: _replacePlayerInSnapshot(cachedPlayers, insertedPlayer),
      );
    });
  }

  Future<List<Player>> getPlayers({required String clubId}) async {
    var players = await _readCachedPlayersSnapshot(clubId: clubId);
    if (players.isEmpty) {
      players = await _fetchRemotePlayersSnapshot(clubId: clubId);
    }

    List<MatchRecord> matches;
    try {
      matches = await getMatches(clubId: clubId);
    } catch (error) {
      debugPrint(
        'FirebaseService: unable to load matches for player rating replay, using cached-free baseline: $error',
      );
      matches = const <MatchRecord>[];
    }

    final eligiblePlayers = players
        .where((player) => player.isActive && player.countsAsPlayer)
        .toList();
    return applyDerivedDuprRatingsToPlayers(
      players: eligiblePlayers,
      matches: matches,
    );
  }

  Future<void> updatePlayer(
    Player player, {
    required String actingUid,
    required String clubId,
  }) async {
    if (player.id == null) return;

    await _syncStatus.runTrackedWrite(() async {
      await _requireAdminOrOwnPlayer(
        uid: actingUid,
        playerId: player.id!,
        clubId: clubId,
      );

      final data = player.toProfileUpdateMap();
      await _db.collection('players').doc(player.id).update(data);

      final cachedPlayers = await _readCachedPlayersSnapshot(clubId: clubId);
      final updatedPlayer = player.copyWith(clubId: player.clubId ?? clubId);
      await _cachePlayersSnapshot(
        clubId: clubId,
        players: _replacePlayerInSnapshot(cachedPlayers, updatedPlayer),
      );
    });
  }

  Future<void> deletePlayer(
    String id, {
    required String actingUid,
    required String clubId,
  }) async {
    await _syncStatus.runTrackedWrite(() async {
      await _requireAdmin(uid: actingUid, clubId: clubId);
      await _db.collection('players').doc(id).update({'isActive': 0});

      final cachedPlayers = await _readCachedPlayersSnapshot(clubId: clubId);
      await _cachePlayersSnapshot(
        clubId: clubId,
        players: cachedPlayers.where((player) => player.id != id).toList(),
      );
    });
  }

  Future<void> togglePlayerAvailability(
    String id,
    bool isAvailable, {
    required String actingUid,
    required String clubId,
  }) async {
    await _syncStatus.runTrackedWrite(() async {
      await _requireAdminOrOwnPlayer(
        uid: actingUid,
        playerId: id,
        clubId: clubId,
      );
      await _db.collection('players').doc(id).update({
        'isAvailable': isAvailable ? 1 : 0,
      });

      final cachedPlayers = await _readCachedPlayersSnapshot(clubId: clubId);
      final updatedPlayers = cachedPlayers.map((player) {
        if (player.id != id) {
          return player;
        }

        return player.copyWith(isAvailable: isAvailable);
      }).toList();
      await _cachePlayersSnapshot(clubId: clubId, players: updatedPlayers);
    });
  }

  // --- ANNOUNCEMENTS ---

  Future<String> createAnnouncement({
    required String title,
    required DateTime scheduledAt,
    required String location,
    required String actingUid,
    required String clubId,
  }) async {
    return _syncStatus.runTrackedWrite(() async {
      await _requireAdmin(uid: actingUid, clubId: clubId);

      final userData = await _getUserData(actingUid);
      final createdByName = await _resolveDisplayName(userData);
      final doc = _db.collection('announcements').doc();
      final now = DateTime.now().toIso8601String();
      final announcement = Announcement(
        id: doc.id,
        title: title.trim(),
        scheduledAt: scheduledAt.toIso8601String(),
        location: location.trim(),
        createdByUid: actingUid,
        createdByName: createdByName,
        clubId: clubId,
        createdAt: now,
        updatedAt: now,
      );

      await doc.set(announcement.toMap());
      return doc.id;
    });
  }

  Future<List<Announcement>> getAnnouncements({required String clubId}) async {
    final rows = await _loadCollectionWithOfflineFallback(
      loader: () => _db
          .collection('announcements')
          .where('clubId', isEqualTo: clubId)
          .get(),
      cacheKey: _cachedAnnouncementsKey(clubId),
    );

    final announcements = rows.map(Announcement.fromMap).toList();

    announcements.sort((a, b) {
      final aCreatedAt =
          a.createdDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bCreatedAt =
          b.createdDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bCreatedAt.compareTo(aCreatedAt);
    });

    return announcements;
  }

  Future<void> addAnnouncementComment({
    required String announcementId,
    required String text,
    required String actingUid,
  }) async {
    await _syncStatus.runTrackedWrite(() async {
      final trimmedText = text.trim();
      if (trimmedText.isEmpty) {
        throw StateError('Comment cannot be empty.');
      }

      final announcementDoc = await _db
          .collection('announcements')
          .doc(announcementId)
          .get();
      if (!announcementDoc.exists) {
        throw StateError('Announcement not found.');
      }

      final announcementData = announcementDoc.data()!;
      final clubId = announcementData['clubId'] as String?;
      if (clubId == null || clubId.isEmpty) {
        throw StateError('Announcement club is missing.');
      }

      final userData = await _getUserData(actingUid);
      final userClubId = userData['clubId'] as String?;
      if (userClubId != clubId) {
        throw StateError('You can only comment on your club announcements.');
      }

      final authorName = await _resolveDisplayName(userData);
      final doc = _db.collection('announcement_comments').doc();
      final now = DateTime.now().toIso8601String();
      final comment = AnnouncementComment(
        id: doc.id,
        announcementId: announcementId,
        clubId: clubId,
        authorUid: actingUid,
        authorName: authorName,
        text: trimmedText,
        createdAt: now,
        updatedAt: now,
      );

      await doc.set(comment.toMap());
    });
  }

  Future<AnnouncementInboxStatus> getAnnouncementInboxStatus({
    required String actingUid,
    required String clubId,
  }) async {
    final userData = await _getUserData(actingUid);
    final userClubId = userData['clubId'] as String?;
    if (userClubId != clubId) {
      throw StateError('You can only view your own club announcements.');
    }

    final lastSeenAtRaw = userData['announcementLastSeenAt'] as String?;
    final lastSeenAt = DateTime.tryParse(lastSeenAtRaw ?? '');
    final announcements = await getAnnouncements(clubId: clubId);
    final unreadAnnouncements =
        announcements.where((announcement) {
          final createdAt = announcement.createdDateTime;
          if (lastSeenAt == null) {
            return true;
          }
          if (createdAt == null) {
            return false;
          }
          return createdAt.isAfter(lastSeenAt);
        }).toList()..sort((a, b) {
          final left =
              a.createdDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right =
              b.createdDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });

    final status = AnnouncementInboxStatus(
      unreadCount: unreadAnnouncements.length,
      latestUnreadAnnouncement: unreadAnnouncements.isEmpty
          ? null
          : unreadAnnouncements.first,
    );

    await _cacheAnnouncementInboxStatus(
      actingUid: actingUid,
      clubId: clubId,
      status: status,
    );

    return status;
  }

  Future<void> markAnnouncementsSeen({
    required String actingUid,
    required String clubId,
  }) async {
    await _syncStatus.runTrackedWrite(() async {
      final userData = await _getUserData(actingUid);
      if ((userData['clubId'] as String?) != clubId) {
        throw StateError(
          'You can only update your own club announcement state.',
        );
      }

      final userRef = _db.collection('users').doc(actingUid);
      final seenAt = DateTime.now().toIso8601String();

      await userRef.set({
        'announcementLastSeenAt': seenAt,
      }, SetOptions(merge: true));

      final cached = Map<String, dynamic>.from(userData)
        ..['announcementLastSeenAt'] = seenAt;
      await _cacheUserData(actingUid, cached);
      await _cacheAnnouncementInboxStatus(
        actingUid: actingUid,
        clubId: clubId,
        status: const AnnouncementInboxStatus(),
      );
    });
  }

  Future<List<AnnouncementComment>> getAnnouncementComments({
    required String announcementId,
    required String clubId,
  }) async {
    final rows = await _loadCollectionWithOfflineFallback(
      loader: () => _db
          .collection('announcement_comments')
          .where('clubId', isEqualTo: clubId)
          .where('announcementId', isEqualTo: announcementId)
          .orderBy('createdAt')
          .get(),
      cacheKey: _cachedCommentsKey(clubId, announcementId),
    );

    await _cacheCommentRows(rows);
    final comments = rows.map(AnnouncementComment.fromMap).toList();
    comments.sort(
      (a, b) => (a.createdDateTime ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(
            b.createdDateTime ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
    );
    return comments;
  }

  Future<void> updateAnnouncementComment({
    required String commentId,
    required String text,
    required String actingUid,
  }) async {
    await _syncStatus.runTrackedWrite(() async {
      final trimmedText = text.trim();
      if (trimmedText.isEmpty) {
        throw StateError('Comment cannot be empty.');
      }

      final commentRef = _db.collection('announcement_comments').doc(commentId);
      Map<String, dynamic>? data;
      try {
        final commentDoc = await commentRef.get();
        if (commentDoc.exists) {
          data = Map<String, dynamic>.from(commentDoc.data()!)
            ..['id'] = commentDoc.id;
          await OfflineCacheStore.instance.writeMap(
            _cachedCommentKey(commentId),
            data,
          );
        }
      } catch (_) {
        data = await _readCachedComment(commentId);
      }

      data ??= await _readCachedComment(commentId);
      if (data == null) {
        throw StateError('Comment not found.');
      }
      if ((data['authorUid'] as String?) != actingUid) {
        throw StateError('You can only edit your own comments.');
      }

      final updatedAt = DateTime.now().toIso8601String();

      await commentRef.update({'text': trimmedText, 'updatedAt': updatedAt});

      final cached = Map<String, dynamic>.from(data)
        ..['text'] = trimmedText
        ..['updatedAt'] = updatedAt;
      await OfflineCacheStore.instance.writeMap(
        _cachedCommentKey(commentId),
        cached,
      );
    });
  }

  Future<void> deleteAnnouncementComment({
    required String commentId,
    required String actingUid,
  }) async {
    await _syncStatus.runTrackedWrite(() async {
      final commentRef = _db.collection('announcement_comments').doc(commentId);
      Map<String, dynamic>? data;
      try {
        final commentDoc = await commentRef.get();
        if (commentDoc.exists) {
          data = Map<String, dynamic>.from(commentDoc.data()!)
            ..['id'] = commentDoc.id;
          await OfflineCacheStore.instance.writeMap(
            _cachedCommentKey(commentId),
            data,
          );
        }
      } catch (_) {
        data = await _readCachedComment(commentId);
      }

      data ??= await _readCachedComment(commentId);
      if (data == null) {
        throw StateError('Comment not found.');
      }

      final authorUid = data['authorUid'] as String?;
      final clubId = data['clubId'] as String?;
      if (clubId == null || clubId.isEmpty) {
        throw StateError('Comment club is missing.');
      }

      final isAdmin = await _isAdminForClub(uid: actingUid, clubId: clubId);
      if (authorUid != actingUid && !isAdmin) {
        throw StateError('You can only delete your own comments.');
      }

      await commentRef.delete();
      await OfflineCacheStore.instance.remove(_cachedCommentKey(commentId));
    });
  }

  // --- MATCHES ---

  Future<void> insertMatch(
    MatchRecord match, {
    required String clubId,
    required String createdByUid,
  }) async {
    await _syncStatus.runTrackedWrite(() async {
      await _requireAdmin(uid: createdByUid, clubId: clubId);

      final players = await _loadPlayersForWrite(clubId: clubId);
      final matches = await _loadMatchesForWrite(clubId: clubId);
      final matchRef = match.id != null && match.id!.isNotEmpty
          ? _db.collection('matches').doc(match.id)
          : _db.collection('matches').doc();
      final storedMatch = MatchRecord(
        id: matchRef.id,
        gameMode: match.gameMode,
        matchLogic: match.matchLogic,
        teamAPlayerIds: match.teamAPlayerIds,
        teamBPlayerIds: match.teamBPlayerIds,
        teamANames: match.teamANames,
        teamBNames: match.teamBNames,
        teamAPlayerRatings: match.teamAPlayerRatings,
        teamBPlayerRatings: match.teamBPlayerRatings,
        winningSide: match.winningSide,
        date: match.date,
        clubId: clubId,
        createdByUid: createdByUid,
      );
      final recalculatedPlayers = applyDerivedDuprRatingsToPlayers(
        players: players,
        matches: [...matches, storedMatch],
      );
      final recalculatedPlayersById = {
        for (final player in recalculatedPlayers)
          if (player.id != null && player.id!.isNotEmpty) player.id!: player,
      };

      final batch = _db.batch();

      final data = storedMatch.toMap();
      data['id'] = matchRef.id;
      data['clubId'] = clubId;
      data['createdByUid'] = createdByUid;
      batch.set(matchRef, data);

      final teamAIds = storedMatch.teamAPlayerIdList;
      final teamBIds = storedMatch.teamBPlayerIdList;

      for (final id in teamAIds) {
        if (id.isEmpty || Player.isGuestId(id)) continue;
        final playerRef = _db.collection('players').doc(id.trim());
        batch.update(playerRef, {
          'lastResult': storedMatch.winningSide == 'A' ? 'win' : 'loss',
        });
      }

      for (final id in teamBIds) {
        if (id.isEmpty || Player.isGuestId(id)) continue;
        final playerRef = _db.collection('players').doc(id.trim());
        batch.update(playerRef, {
          'lastResult': storedMatch.winningSide == 'B' ? 'win' : 'loss',
        });
      }

      for (final player in recalculatedPlayers) {
        if (player.id == null || player.isGuest) {
          continue;
        }

        final playerRef = _db.collection('players').doc(player.id);
        batch.update(playerRef, {
          'duprRating': player.effectiveDuprRating,
          'duprMatchesPlayed': player.duprMatchesPlayed,
          'duprLastUpdatedAt': player.duprLastUpdatedAt ?? storedMatch.date,
        });
      }

      await batch.commit();

      final cachedMatches = await _readCachedMatchesSnapshot(clubId: clubId);
      await _cacheMatchesSnapshot(
        clubId: clubId,
        matches: _replaceMatchInSnapshot(cachedMatches, storedMatch),
      );

      final teamAIdsSet = teamAIds.toSet();
      final teamBIdsSet = teamBIds.toSet();
      final updatedPlayers = players.map((player) {
        if (player.id == null || player.id!.isEmpty) {
          return player;
        }

        var mergedPlayer = recalculatedPlayersById[player.id!] ?? player;
        if (teamAIdsSet.contains(player.id!)) {
          mergedPlayer = mergedPlayer.copyWith(
            lastResult: storedMatch.winningSide == 'A' ? 'win' : 'loss',
          );
        } else if (teamBIdsSet.contains(player.id!)) {
          mergedPlayer = mergedPlayer.copyWith(
            lastResult: storedMatch.winningSide == 'B' ? 'win' : 'loss',
          );
        }

        return mergedPlayer.copyWith(clubId: mergedPlayer.clubId ?? clubId);
      }).toList();
      await _cachePlayersSnapshot(clubId: clubId, players: updatedPlayers);
    });
  }

  Future<List<MatchRecord>> getMatches({required String clubId}) async {
    final cachedMatches = await _readCachedMatchesSnapshot(clubId: clubId);
    if (cachedMatches.isNotEmpty) {
      return cachedMatches;
    }

    return _fetchRemoteMatchesSnapshot(clubId: clubId);
  }

  // --- STANDINGS ---

  Future<List<Map<String, dynamic>>> getPlayerStandings({
    required String clubId,
  }) async {
    final players = await getPlayers(clubId: clubId);
    final matches = await getMatches(clubId: clubId);
    return buildPlayerStandings(players: players, matches: matches);
  }

  Future<void> preloadCoreClubData({
    required String clubId,
    String? actingUid,
  }) async {
    await _syncStatus.runTrackedRefresh(() async {
      try {
        await _fetchRemoteMatchesSnapshot(clubId: clubId);
      } catch (error) {
        debugPrint('FirebaseService: preload matches failed: $error');
      }

      try {
        await _fetchRemotePlayersSnapshot(clubId: clubId);
      } catch (error) {
        debugPrint('FirebaseService: preload players failed: $error');
      }

      try {
        await getAnnouncements(clubId: clubId);
      } catch (error) {
        debugPrint('FirebaseService: preload announcements failed: $error');
      }

      if (actingUid != null && actingUid.isNotEmpty) {
        try {
          await getAnnouncementInboxStatus(
            actingUid: actingUid,
            clubId: clubId,
          );
        } catch (error) {
          debugPrint(
            'FirebaseService: preload announcement inbox failed: $error',
          );
        }
      }
    });
  }

  // --- LEGACY DATA MIGRATION ---

  /// One-time migration: backfill clubId on all players/matches missing it,
  /// mark unowned players as legacy, and set them unavailable.
  /// Returns the number of documents updated.
  Future<int> migrateLegacyData({required String defaultClubId}) async {
    int updated = 0;

    // Migrate players without clubId
    final playersSnap = await _db.collection('players').get();
    for (final doc in playersSnap.docs) {
      final data = doc.data();
      final Map<String, dynamic> patch = {};

      if (data['clubId'] == null || (data['clubId'] as String).isEmpty) {
        patch['clubId'] = defaultClubId;
      }
      if (data['ownerUid'] == null || (data['ownerUid'] as String).isEmpty) {
        patch['isLegacy'] = 1;
        patch['isAvailable'] = 0;
      }
      if (data['isLegacy'] == null) {
        patch['isLegacy'] =
            (data['ownerUid'] == null || (data['ownerUid'] as String).isEmpty)
            ? 1
            : 0;
      }
      if (data['countsAsPlayer'] == null) {
        patch['countsAsPlayer'] = 1;
      }

      if (patch.isNotEmpty) {
        await doc.reference.update(patch);
        updated++;
      }
    }

    // Migrate matches without clubId
    final matchesSnap = await _db.collection('matches').get();
    for (final doc in matchesSnap.docs) {
      final data = doc.data();
      final Map<String, dynamic> patch = {};

      if (data['clubId'] == null || (data['clubId'] as String).isEmpty) {
        patch['clubId'] = defaultClubId;
      }
      if (data['createdByUid'] == null ||
          (data['createdByUid'] as String).isEmpty) {
        patch['createdByUid'] = 'legacy';
      }

      if (patch.isNotEmpty) {
        await doc.reference.update(patch);
        updated++;
      }
    }

    return updated;
  }
}
