import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/announcement.dart';
import 'models/announcement_comment.dart';
import 'models/announcement_inbox_status.dart';
import 'models/player.dart';
import 'models/match_record.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> _getUserData(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      throw StateError('User profile not found.');
    }
    return userDoc.data()!;
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

    final playerDoc = await _db.collection('players').doc(playerId).get();
    if (!playerDoc.exists) {
      throw StateError('Player profile not found.');
    }

    final data = playerDoc.data()!;
    final ownerUid = data['ownerUid'] as String?;
    final playerClubId = data['clubId'] as String?;

    if (ownerUid != uid || playerClubId != clubId) {
      throw StateError('You can only manage your own player profile.');
    }
  }

  // --- PLAYERS ---

  Future<void> insertPlayer(
    Player player, {
    required String clubId,
    required String ownerUid,
    required String actingUid,
  }) async {
    await _requireAdmin(uid: actingUid, clubId: clubId);

    final doc = _db.collection('players').doc();
    final Map<String, dynamic> data = player.toMap();
    data['id'] = doc.id;
    data['clubId'] = clubId;
    data['ownerUid'] = ownerUid;
    await doc.set(data);
  }

  Future<List<Player>> getPlayers({required String clubId}) async {
    final snapshot = await _db
        .collection('players')
        .where('isActive', isEqualTo: 1)
        .where('clubId', isEqualTo: clubId)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Player.fromMap(data);
        })
        .where((p) => p.isActive && p.countsAsPlayer)
        .toList();
  }

  Future<void> updatePlayer(
    Player player, {
    required String actingUid,
    required String clubId,
  }) async {
    if (player.id == null) return;

    await _requireAdminOrOwnPlayer(
      uid: actingUid,
      playerId: player.id!,
      clubId: clubId,
    );

    final existingDoc = await _db.collection('players').doc(player.id).get();
    if (!existingDoc.exists) {
      throw StateError('Player profile not found.');
    }

    final existingData = existingDoc.data()!;
    existingData['id'] = existingDoc.id;
    final data = player.toProfileUpdateMap();
    await _db.collection('players').doc(player.id).update(data);
  }

  Future<void> deletePlayer(
    String id, {
    required String actingUid,
    required String clubId,
  }) async {
    await _requireAdmin(uid: actingUid, clubId: clubId);
    await _db.collection('players').doc(id).update({'isActive': 0});
  }

  Future<void> togglePlayerAvailability(
    String id,
    bool isAvailable, {
    required String actingUid,
    required String clubId,
  }) async {
    await _requireAdminOrOwnPlayer(
      uid: actingUid,
      playerId: id,
      clubId: clubId,
    );
    await _db.collection('players').doc(id).update({
      'isAvailable': isAvailable ? 1 : 0,
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
  }

  Future<List<Announcement>> getAnnouncements({required String clubId}) async {
    final snapshot = await _db
        .collection('announcements')
        .where('clubId', isEqualTo: clubId)
        .orderBy('scheduledAt')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Announcement.fromMap(data);
    }).toList();
  }

  Future<void> addAnnouncementComment({
    required String announcementId,
    required String text,
    required String actingUid,
  }) async {
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

    return AnnouncementInboxStatus(
      unreadCount: unreadAnnouncements.length,
      latestUnreadAnnouncement: unreadAnnouncements.isEmpty
          ? null
          : unreadAnnouncements.first,
    );
  }

  Future<void> markAnnouncementsSeen({
    required String actingUid,
    required String clubId,
  }) async {
    final userRef = _db.collection('users').doc(actingUid);
    final userDoc = await userRef.get();
    if (!userDoc.exists) {
      throw StateError('User profile not found.');
    }

    final userData = userDoc.data()!;
    if ((userData['clubId'] as String?) != clubId) {
      throw StateError('You can only update your own club announcement state.');
    }

    await userRef.set({
      'announcementLastSeenAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<List<AnnouncementComment>> getAnnouncementComments({
    required String announcementId,
    required String clubId,
  }) async {
    final snapshot = await _db
        .collection('announcement_comments')
        .where('clubId', isEqualTo: clubId)
        .where('announcementId', isEqualTo: announcementId)
        .orderBy('createdAt')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return AnnouncementComment.fromMap(data);
    }).toList();
  }

  Future<void> updateAnnouncementComment({
    required String commentId,
    required String text,
    required String actingUid,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw StateError('Comment cannot be empty.');
    }

    final commentRef = _db.collection('announcement_comments').doc(commentId);
    final commentDoc = await commentRef.get();
    if (!commentDoc.exists) {
      throw StateError('Comment not found.');
    }

    final data = commentDoc.data()!;
    if ((data['authorUid'] as String?) != actingUid) {
      throw StateError('You can only edit your own comments.');
    }

    await commentRef.update({
      'text': trimmedText,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteAnnouncementComment({
    required String commentId,
    required String actingUid,
  }) async {
    final commentRef = _db.collection('announcement_comments').doc(commentId);
    final commentDoc = await commentRef.get();
    if (!commentDoc.exists) {
      throw StateError('Comment not found.');
    }

    final data = commentDoc.data()!;
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
  }

  // --- MATCHES ---

  Future<void> insertMatch(
    MatchRecord match, {
    required String clubId,
    required String createdByUid,
  }) async {
    await _requireAdmin(uid: createdByUid, clubId: clubId);

    final batch = _db.batch();

    final matchRef = _db.collection('matches').doc();
    final data = match.toMap();
    data['id'] = matchRef.id;
    data['clubId'] = clubId;
    data['createdByUid'] = createdByUid;
    batch.set(matchRef, data);

    final teamAIds = match.teamAPlayerIds.split(',');
    final teamBIds = match.teamBPlayerIds.split(',');

    for (final id in teamAIds) {
      if (id.isEmpty) continue;
      final playerRef = _db.collection('players').doc(id.trim());
      batch.update(playerRef, {
        'lastResult': match.winningSide == 'A' ? 'win' : 'loss',
      });
    }

    for (final id in teamBIds) {
      if (id.isEmpty) continue;
      final playerRef = _db.collection('players').doc(id.trim());
      batch.update(playerRef, {
        'lastResult': match.winningSide == 'B' ? 'win' : 'loss',
      });
    }

    await batch.commit();
  }

  Future<List<MatchRecord>> getMatches({required String clubId}) async {
    final snapshot = await _db
        .collection('matches')
        .where('clubId', isEqualTo: clubId)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return MatchRecord.fromMap(data);
    }).toList();
  }

  // --- STANDINGS ---

  Future<List<Map<String, dynamic>>> getPlayerStandings({
    required String clubId,
  }) async {
    final players = await getPlayers(clubId: clubId);
    final matches = await getMatches(clubId: clubId);

    final Map<String, Map<String, dynamic>> stats = {};
    for (var p in players) {
      if (p.id != null) {
        stats[p.id!] = {
          'player': p,
          'wins': 0,
          'losses': 0,
          'matchesPlayed': 0,
          'winPercent': 0.0,
        };
      }
    }

    for (var match in matches) {
      final winTeamIds = match.winningSide == 'A'
          ? match.teamAPlayerIds
          : match.teamBPlayerIds;
      final loseTeamIds = match.winningSide == 'A'
          ? match.teamBPlayerIds
          : match.teamAPlayerIds;

      for (var id in winTeamIds.split(',')) {
        id = id.trim();
        if (stats.containsKey(id)) {
          stats[id]!['wins'] = (stats[id]!['wins'] as int) + 1;
          stats[id]!['matchesPlayed'] =
              (stats[id]!['matchesPlayed'] as int) + 1;
        }
      }

      for (var id in loseTeamIds.split(',')) {
        id = id.trim();
        if (stats.containsKey(id)) {
          stats[id]!['losses'] = (stats[id]!['losses'] as int) + 1;
          stats[id]!['matchesPlayed'] =
              (stats[id]!['matchesPlayed'] as int) + 1;
        }
      }
    }

    // Calculate win %
    final results = stats.values.toList();
    for (var r in results) {
      final w = r['wins'] as int;
      final total = r['matchesPlayed'] as int;
      r['winPercent'] = total > 0 ? (w / total * 100.0) : 0.0;
    }

    // Default sort by win% descending, then wins descending
    results.sort((a, b) {
      int cmp = (b['winPercent'] as double).compareTo(
        a['winPercent'] as double,
      );
      if (cmp != 0) return cmp;
      return (b['wins'] as int).compareTo(a['wins'] as int);
    });

    return results;
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
