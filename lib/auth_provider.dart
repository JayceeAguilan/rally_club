import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/app_user.dart';
import 'models/club.dart';
import 'models/player.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class AuthProvider extends ChangeNotifier {
  static const rememberMePreferenceKey = 'auth.rememberMe';

  late final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Future<SharedPreferences> Function() _loadPreferences;
  final Completer<void> _sessionPreferenceReady = Completer<void>();

  User? _firebaseUser;
  AppUser? _appUser;
  Club? _club;
  bool _isLoading = true;
  bool _rememberMe = true;
  bool? _isAuthenticatedOverride;
  bool? _isEmailVerifiedOverride;
  StreamSubscription<User?>? _authSub;

  AuthProvider({Future<SharedPreferences> Function()? loadPreferences})
    : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance {
    _authSub = _auth.authStateChanges().listen(_onAuthStateChanged);
    unawaited(_initializeSessionPreference());
  }

  /// Test-only constructor: pre-sets auth state without Firebase access.
  @visibleForTesting
  AuthProvider.test({
    AppUser? appUser,
    Club? club,
    bool isLoading = false,
    bool rememberMe = true,
    bool? isAuthenticated,
    bool? isEmailVerified,
  }) : _loadPreferences = SharedPreferences.getInstance {
    _appUser = appUser;
    _club = club;
    _isLoading = isLoading;
    _rememberMe = rememberMe;
    _isAuthenticatedOverride = isAuthenticated ?? appUser != null;
    _isEmailVerifiedOverride = isEmailVerified ?? appUser != null;
    _sessionPreferenceReady.complete();
  }

  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  Club? get club => _club;
  bool get isLoading => _isLoading;
  bool get rememberMe => _rememberMe;
  bool get isAuthenticated =>
      (_firebaseUser != null || (_isAuthenticatedOverride ?? false)) &&
      _appUser != null;
  bool get isEmailVerified =>
      _firebaseUser?.emailVerified ?? (_isEmailVerifiedOverride ?? false);
  bool get isAdmin => _appUser?.role == 'admin';

  Club _fallbackClub(String clubId) {
    return Club(id: clubId, name: 'Rally Club', createdAt: '');
  }

  @visibleForTesting
  static Map<String, dynamic> buildPlayerParticipationPatch({
    required String role,
    required Map<String, dynamic> playerData,
    required DateTime now,
  }) {
    final shouldCountAsPlayer = role != 'admin';
    final currentCountsAsPlayer = (playerData['countsAsPlayer'] ?? 1) == 1;
    final currentAvailability = (playerData['isAvailable'] ?? 1) == 1;
    final updates = <String, dynamic>{};

    if (currentCountsAsPlayer != shouldCountAsPlayer) {
      updates['countsAsPlayer'] = shouldCountAsPlayer ? 1 : 0;
    }

    if (!shouldCountAsPlayer && currentAvailability) {
      updates['isAvailable'] = 0;
    }

    if (updates.isNotEmpty) {
      updates['updatedAt'] = now.toIso8601String();
    }

    return updates;
  }

  Future<void> _syncLinkedPlayerParticipationState() async {
    final appUser = _appUser;
    final playerId = appUser?.playerId;
    if (appUser == null || playerId == null || playerId.isEmpty) {
      return;
    }

    final playerRef = _db.collection('players').doc(playerId);
    final playerDoc = await playerRef.get();
    if (!playerDoc.exists) {
      return;
    }

    final updates = buildPlayerParticipationPatch(
      role: appUser.role,
      playerData: playerDoc.data()!,
      now: DateTime.now(),
    );
    if (updates.isNotEmpty) {
      await playerRef.update(updates);
    }
  }

  Future<void> _createUserProfileDocuments({
    required String uid,
    required String email,
    required String playerName,
    required String gender,
    required String skillLevel,
  }) async {
    final now = DateTime.now().toIso8601String();
    const clubId = Club.defaultClubId;

    final playerRef = _db.collection('players').doc();
    final playerData = {
      'name': playerName,
      'gender': gender,
      'skillLevel': Player.normalizeSkillLevelCode(skillLevel),
      'countsAsPlayer': 1,
      'isAvailable': 1,
      'notes': '',
      'lastResult': 'none',
      'isActive': 1,
      'createdAt': now,
      'updatedAt': now,
      'profileImageBase64': null,
      'clubId': clubId,
      'ownerUid': uid,
      'isLegacy': 0,
    };

    final appUser = AppUser(
      uid: uid,
      email: email,
      playerId: playerRef.id,
      clubId: clubId,
      role: 'member',
      joinedAt: now,
    );

    final batch = _db.batch();
    batch.set(playerRef, playerData);
    batch.set(_db.collection('users').doc(uid), appUser.toMap());
    await batch.commit();
  }

  Future<void> _syncAnnouncementNotifications() async {
    try {
      await NotificationService.instance.syncAnnouncementSubscription(
        clubId: _appUser?.clubId,
      );
    } catch (e) {
      debugPrint('AuthProvider: failed to sync announcement notifications: $e');
    }
  }

  Future<void> _clearAnnouncementNotifications() async {
    try {
      await NotificationService.instance.clearAnnouncementSubscription();
    } catch (e) {
      debugPrint(
        'AuthProvider: failed to clear announcement notifications: $e',
      );
    }
  }

  Future<UserCredential?> _repairOrphanedRegistration({
    required String email,
    required String password,
    required String playerName,
    required String gender,
    required String skillLevel,
  }) async {
    final existingCred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = existingCred.user!.uid;
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      await _auth.signOut();
      return null;
    }

    try {
      await _createUserProfileDocuments(
        uid: uid,
        email: email,
        playerName: playerName,
        gender: gender,
        skillLevel: skillLevel,
      );
      await existingCred.user?.sendEmailVerification();
      return existingCred;
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  }

  Future<void> _initializeSessionPreference() async {
    try {
      final prefs = await _loadPreferences();
      _rememberMe = prefs.getBool(rememberMePreferenceKey) ?? true;

      if (_auth.currentUser != null && !_rememberMe) {
        await _auth.signOut();
      }
    } catch (e) {
      debugPrint('AuthProvider: failed to initialize remember me: $e');
      _rememberMe = true;
    } finally {
      if (!_sessionPreferenceReady.isCompleted) {
        _sessionPreferenceReady.complete();
      }
    }
  }

  Future<void> _persistRememberMePreference(bool rememberMe) async {
    _rememberMe = rememberMe;

    try {
      final prefs = await _loadPreferences();
      await prefs.setBool(rememberMePreferenceKey, rememberMe);
    } catch (e) {
      debugPrint('AuthProvider: failed to save remember me: $e');
    }
  }

  Future<void> _onAuthStateChanged(User? _) async {
    await _sessionPreferenceReady.future;

    final user = _auth.currentUser;
    _firebaseUser = user;
    if (user == null) {
      await _clearAnnouncementNotifications();
      _appUser = null;
      _club = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        _appUser = AppUser.fromMap(userDoc.data()!);
        if (_appUser!.clubId != null) {
          final clubDoc = await _db
              .collection('clubs')
              .doc(_appUser!.clubId)
              .get();
          _club = clubDoc.exists
              ? Club.fromMap(clubDoc.data()!)
              : _fallbackClub(_appUser!.clubId!);
        }

        // One-time legacy data migration
        await _runLegacyMigrationIfNeeded();
        await _syncLinkedPlayerParticipationState();
        await _syncAnnouncementNotifications();
      } else {
        await _clearAnnouncementNotifications();
        _appUser = null;
        _club = null;
      }
    } catch (e) {
      debugPrint('AuthProvider: failed to load user data: $e');
      await _clearAnnouncementNotifications();
      _appUser = null;
      _club = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _runLegacyMigrationIfNeeded() async {
    try {
      final migrationDoc = await _db
          .collection('_migrations')
          .doc('legacy_v1')
          .get();
      if (migrationDoc.exists) return;

      final count = await FirebaseService().migrateLegacyData(
        defaultClubId: Club.defaultClubId,
      );
      await _db.collection('_migrations').doc('legacy_v1').set({
        'completedAt': DateTime.now().toIso8601String(),
        'documentsUpdated': count,
      });
      debugPrint('Legacy migration complete: $count documents updated');
    } catch (e) {
      debugPrint('Legacy migration skipped or failed: $e');
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    await _persistRememberMePreference(rememberMe);

    if (kIsWeb) {
      await _auth.setPersistence(
        rememberMe ? Persistence.LOCAL : Persistence.SESSION,
      );
    }

    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String playerName,
    required String gender,
    required String skillLevel,
  }) async {
    UserCredential? cred;

    await _persistRememberMePreference(true);

    if (kIsWeb) {
      await _auth.setPersistence(Persistence.LOCAL);
    }

    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _createUserProfileDocuments(
        uid: cred.user!.uid,
        email: email,
        playerName: playerName,
        gender: gender,
        skillLevel: skillLevel,
      );
      await cred.user?.sendEmailVerification();

      return cred;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          final repairedCred = await _repairOrphanedRegistration(
            email: email,
            password: password,
            playerName: playerName,
            gender: gender,
            skillLevel: skillLevel,
          );
          if (repairedCred != null) {
            return repairedCred;
          }
        } on FirebaseAuthException {
          throw e;
        } catch (_) {
          rethrow;
        }
      }

      rethrow;
    } catch (_) {
      if (cred?.user != null) {
        try {
          await cred!.user!.delete();
        } catch (_) {
          await _auth.signOut();
        }
      }

      rethrow;
    }
  }

  Future<void> signOut() async {
    await _clearAnnouncementNotifications();
    await _auth.signOut();
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user available for verification.');
    }

    await user.sendEmailVerification();
  }

  Future<void> refreshCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      _firebaseUser = null;
      _isAuthenticatedOverride = false;
      _isEmailVerifiedOverride = false;
      notifyListeners();
      return;
    }

    await user.reload();
    _firebaseUser = _auth.currentUser;
    _isAuthenticatedOverride = true;
    _isEmailVerifiedOverride = _firebaseUser?.emailVerified ?? false;
    notifyListeners();
  }

  Future<void> applyEmailVerificationCode(String rawInput) async {
    final code = _extractEmailVerificationCode(rawInput);
    if (code == null || code.isEmpty) {
      throw ArgumentError(
        'Please enter the verification code or full link from your email.',
      );
    }

    await _auth.checkActionCode(code);
    await _auth.applyActionCode(code);
    await refreshCurrentUser();
  }

  String? _extractEmailVerificationCode(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parsedUri = Uri.tryParse(trimmed);
    final queryCode = parsedUri?.queryParameters['oobCode'];
    if (queryCode != null && queryCode.isNotEmpty) {
      return queryCode;
    }

    return trimmed;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
