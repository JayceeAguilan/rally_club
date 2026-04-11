import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

enum SyncStatusPhase { live, syncing, offline }

/// Tracks whether the app is offline or still syncing queued Firestore work.
class SyncStatusController extends ChangeNotifier {
  SyncStatusController._() {
    unawaited(_initialize());
  }

  static final SyncStatusController instance = SyncStatusController._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<void>? _snapshotsInSyncSubscription;

  SyncStatusPhase _phase = SyncStatusPhase.live;
  bool _hasConnectivity = true;
  bool _hasPendingWrites = false;
  bool _isSettlingPendingWrites = false;
  int _activeWriteOperations = 0;

  SyncStatusPhase get phase => _phase;

  String get label {
    switch (_phase) {
      case SyncStatusPhase.offline:
        return 'Offline';
      case SyncStatusPhase.syncing:
        return 'Syncing changes';
      case SyncStatusPhase.live:
        return 'Live';
    }
  }

  bool get isVisible => _phase != SyncStatusPhase.live;

  Future<T> runTrackedRefresh<T>(Future<T> Function() action) async {
    return action();
  }

  Future<T> runTrackedWrite<T>(Future<T> Function() action) async {
    _activeWriteOperations += 1;
    _hasPendingWrites = true;
    _recomputePhase();

    var completed = false;
    try {
      final result = await action();
      completed = true;
      return result;
    } finally {
      if (_activeWriteOperations > 0) {
        _activeWriteOperations -= 1;
      }
      if (!completed && _activeWriteOperations == 0) {
        _hasPendingWrites = false;
      }
      _recomputePhase();
      if (completed) {
        unawaited(_settlePendingWrites());
      }
    }
  }

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_snapshotsInSyncSubscription?.cancel());
    _connectivitySubscription = null;
    _snapshotsInSyncSubscription = null;
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadInitialConnectivity();

    try {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _handleConnectivityChanged,
        onError: (_) {},
      );
    } catch (_) {
      _connectivitySubscription = null;
    }

    final firestore = _safeFirestore;
    if (firestore != null) {
      _snapshotsInSyncSubscription = firestore.snapshotsInSync().listen((_) {
        if (!_hasConnectivity || _activeWriteOperations > 0) {
          return;
        }
        if (_hasPendingWrites || _isSettlingPendingWrites) {
          _hasPendingWrites = false;
          _isSettlingPendingWrites = false;
          _recomputePhase();
        }
      });
    }

    _recomputePhase();
  }

  Future<void> _loadInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _hasConnectivity = _hasOnlineTransport(results);
    } catch (_) {
      _hasConnectivity = true;
    }
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    final wasOffline = !_hasConnectivity;
    _hasConnectivity = _hasOnlineTransport(results);

    if (wasOffline && _hasConnectivity) {
      _hasPendingWrites = true;
      unawaited(_settlePendingWrites());
    }

    _recomputePhase();
  }

  bool _hasOnlineTransport(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  FirebaseFirestore? get _safeFirestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> _settlePendingWrites() async {
    if (_isSettlingPendingWrites || !_hasPendingWrites || !_hasConnectivity) {
      _recomputePhase();
      return;
    }

    final firestore = _safeFirestore;
    if (firestore == null) {
      _hasPendingWrites = false;
      _recomputePhase();
      return;
    }

    _isSettlingPendingWrites = true;
    _recomputePhase();

    try {
      await firestore.waitForPendingWrites();
      _hasPendingWrites = false;
    } catch (_) {
      _hasPendingWrites = true;
    } finally {
      _isSettlingPendingWrites = false;
      _recomputePhase();
    }
  }

  void _recomputePhase() {
    final nextPhase = !_hasConnectivity
        ? SyncStatusPhase.offline
        : (_activeWriteOperations > 0 ||
              _hasPendingWrites ||
              _isSettlingPendingWrites)
        ? SyncStatusPhase.syncing
        : SyncStatusPhase.live;

    if (nextPhase == _phase) {
      return;
    }

    _phase = nextPhase;
    notifyListeners();
  }
}

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SyncStatusController.instance,
      builder: (context, _) {
        final controller = SyncStatusController.instance;
        if (!controller.isVisible) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isOffline = controller.phase == SyncStatusPhase.offline;
        final backgroundColor = isOffline
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer;
        final foregroundColor = isOffline
            ? colorScheme.onErrorContainer
            : colorScheme.onPrimaryContainer;

        final label = compact && controller.phase == SyncStatusPhase.syncing
            ? 'Syncing'
            : controller.label;
        final horizontalPadding = compact ? 10.0 : 14.0;
        final verticalPadding = compact ? 6.0 : 10.0;
        final indicatorSize = compact ? 12.0 : 14.0;
        final iconSize = compact ? 14.0 : 16.0;
        final labelStyle =
            (compact ? theme.textTheme.labelMedium : theme.textTheme.labelLarge)
                ?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                );

        final badge = Container(
          key: ValueKey('${controller.phase}-$compact'),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            boxShadow: compact
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              controller.phase == SyncStatusPhase.syncing
                  ? SizedBox(
                      width: indicatorSize,
                      height: indicatorSize,
                      child: CircularProgressIndicator(
                        strokeWidth: compact ? 2 : 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          foregroundColor,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.cloud_off_rounded,
                      size: iconSize,
                      color: foregroundColor,
                    ),
              SizedBox(width: compact ? 6 : 8),
              Text(label, style: labelStyle),
            ],
          ),
        );

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: compact
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(child: badge),
                )
              : badge,
        );
      },
    );
  }
}
