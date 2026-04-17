import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'match_saved_screen.dart';
import 'match_generator.dart';
import 'match_voice_announcer.dart';
import 'models/player.dart';
import 'models/match_record.dart';
import 'firebase_service.dart';
import 'auth_provider.dart';

class MatchResultScreen extends StatefulWidget {
  final GeneratedMatch match;
  final VoidCallback? onMinimize;
  final VoidCallback? onReshuffle;
  final VoidCallback? onCancelMatch;
  final String initialSelectedWinner;
  final bool initialHasExplicitWinner;
  final ValueChanged<String>? onSelectedWinnerChanged;
  final ValueChanged<bool>? onMatchSaved;

  const MatchResultScreen({
    super.key,
    required this.match,
    this.onMinimize,
    this.onReshuffle,
    this.onCancelMatch,
    this.initialSelectedWinner = 'A',
    this.initialHasExplicitWinner = false,
    this.onSelectedWinnerChanged,
    this.onMatchSaved,
  });

  @override
  State<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends State<MatchResultScreen> {
  // 'A' or 'B'
  late String _selectedWinner;
  bool _hasExplicitWinner = false;
  bool _isSaving = false;
  bool _isSpeaking = false;
  bool _autoAnnouncementQueued = false;
  late final MatchVoiceAnnouncer _voiceAnnouncer;

  bool get _includesGuestPlayers =>
      widget.match.allPlayers.any((player) => player.isGuest);

  bool get _isEmbedded =>
      widget.onMinimize != null ||
      widget.onReshuffle != null ||
      widget.onCancelMatch != null ||
      widget.onMatchSaved != null;

  @override
  void initState() {
    super.initState();
    _voiceAnnouncer = MatchVoiceAnnouncer();
    _selectedWinner = _normalizeSelectedWinner(widget.initialSelectedWinner);
    _hasExplicitWinner = widget.initialHasExplicitWinner;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoAnnouncementQueued) {
        return;
      }

      _autoAnnouncementQueued = true;
      unawaited(_speakLineup());
    });
  }

  @override
  void didUpdateWidget(covariant MatchResultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final normalizedWinner = _normalizeSelectedWinner(
      widget.initialSelectedWinner,
    );
    if (oldWidget.initialSelectedWinner != widget.initialSelectedWinner &&
        normalizedWinner != _selectedWinner) {
      _selectedWinner = normalizedWinner;
    }
    if (oldWidget.initialHasExplicitWinner != widget.initialHasExplicitWinner) {
      _hasExplicitWinner = widget.initialHasExplicitWinner;
    }
  }

  @override
  void dispose() {
    unawaited(_voiceAnnouncer.stop());
    super.dispose();
  }

  String _getLogicLabel(String logic) {
    switch (logic) {
      case 'auto':
        return 'Auto-Balanced';
      case 'skill':
        return 'Skill-Separated';
      case 'history':
        return 'Winners & Losers';
      case 'mixed':
        return 'Mixed Doubles';
      case 'random':
        return 'Random';
      default:
        return 'Custom';
    }
  }

  String _getGameModeLabel() {
    return widget.match.gameMode == 'singles' ? 'Singles' : 'Doubles';
  }

  Future<void> _speakLineup({bool showFailureMessage = false}) async {
    if (_isSpeaking) {
      return;
    }

    setState(() {
      _isSpeaking = true;
    });

    final success = await _voiceAnnouncer.speakLineup(
      teamA: widget.match.teamA,
      teamB: widget.match.teamB,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSpeaking = false;
    });

    if (!success && showFailureMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice playback is unavailable on this device or browser.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _stopLineupVoice() async {
    await _voiceAnnouncer.stop();
    if (!mounted) {
      return;
    }

    setState(() {
      _isSpeaking = false;
    });
  }

  String _normalizeSelectedWinner(String winner) {
    return winner == 'B' ? 'B' : 'A';
  }

  void _selectWinner(String winner) {
    final normalizedWinner = _normalizeSelectedWinner(winner);
    if (_selectedWinner == normalizedWinner && _hasExplicitWinner) {
      return;
    }

    setState(() {
      _selectedWinner = normalizedWinner;
      _hasExplicitWinner = true;
    });
    widget.onSelectedWinnerChanged?.call(normalizedWinner);
  }

  void _dismissResultScreen() {
    unawaited(_voiceAnnouncer.stop());

    if (_isEmbedded) {
      widget.onMinimize?.call();
      return;
    }

    Navigator.pop(context);
  }

  void _reshuffleMatch() {
    unawaited(_voiceAnnouncer.stop());

    if (widget.onReshuffle != null) {
      widget.onReshuffle!();
      return;
    }

    Navigator.pop(context);
  }

  Future<void> _confirmCancelMatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Cancel Match?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textMain(context),
          ),
        ),
        content: Text(
          'This will discard the current ongoing match without saving a result. Use this if a player has an emergency or the match will not be played.',
          style: TextStyle(color: AppColors.textMuted(context), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep Match',
              style: TextStyle(color: AppColors.textMuted(context)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Match'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _stopLineupVoice();

    if (widget.onCancelMatch != null) {
      widget.onCancelMatch!();
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  /// Show confirmation dialog, then save match result to the database.
  Future<void> _confirmAndSaveResult() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can save match results.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Confirm Result',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textMain(context),
          ),
        ),
        content: Text(
          _includesGuestPlayers
              ? 'Save result with Team $_selectedWinner as the winner?\n\nPermanent player standings will be updated, and guest players will remain saved on this device only.'
              : 'Save result with Team $_selectedWinner as the winner?\n\nThis will update each player\'s individual standing.',
          style: TextStyle(color: AppColors.textMuted(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted(context)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCAFD00),
              foregroundColor: const Color(0xFF4A5E00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Confirm',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _stopLineupVoice();

    setState(() {
      _isSaving = true;
    });

    final match = MatchRecord(
      gameMode: widget.match.gameMode,
      matchLogic: widget.match.matchLogic,
      teamAPlayerIds: widget.match.teamA.map((p) => p.id.toString()).join(','),
      teamBPlayerIds: widget.match.teamB.map((p) => p.id.toString()).join(','),
      teamANames: widget.match.teamA.map((p) => p.name).join(', '),
      teamBNames: widget.match.teamB.map((p) => p.name).join(', '),
      teamAPlayerRatings: widget.match.teamA
          .map((player) => player.displayDuprRating)
          .join(','),
      teamBPlayerRatings: widget.match.teamB
          .map((player) => player.displayDuprRating)
          .join(','),
      winningSide: _selectedWinner,
      date: DateTime.now().toIso8601String(),
    );

    try {
      await FirebaseService().insertMatch(
        match,
        clubId: auth.appUser!.clubId!,
        createdByUid: auth.firebaseUser!.uid,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save match result: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (widget.onMatchSaved != null) {
      widget.onMatchSaved!(_includesGuestPlayers);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MatchSavedScreen(includedGuestPlayers: _includesGuestPlayers),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDoubles = widget.match.gameMode == 'doubles';
    final isAdmin = context.select<AuthProvider, bool>((auth) => auth.isAdmin);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactLayout = screenWidth < 430;
    final horizontalPadding = isCompactLayout ? 16.0 : 24.0;

    return PopScope(
      canPop: !_isEmbedded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _dismissResultScreen();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: AppColors.background(context).withValues(alpha: 0.7),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              _isEmbedded ? Icons.minimize_rounded : Icons.close,
              color: AppColors.primary(context),
            ),
            onPressed: _dismissResultScreen,
          ),
          title: const AppBrandTitle(),
          actions: [
            if (widget.onCancelMatch != null)
              IconButton(
                tooltip: 'Cancel match',
                onPressed: _isSaving ? null : _confirmCancelMatch,
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.redAccent,
                ),
              ),
            IconButton(
              tooltip: _isSpeaking ? 'Stop voice' : 'Read teams aloud',
              onPressed: _isSpeaking
                  ? _stopLineupVoice
                  : () => _speakLineup(showFailureMessage: true),
              icon: _isSpeaking
                  ? Icon(
                      Icons.stop_circle_outlined,
                      color: AppColors.primary(context),
                    )
                  : Icon(
                      Icons.volume_up_rounded,
                      color: AppColors.primary(context),
                    ),
            ),
            const TopNavbarSyncStatusIndicator(),
          ],
        ),
        body: !isAdmin
            ? _buildAccessDeniedState(context)
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Editorial Header
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -20,
                          left: -20,
                          child: Text(
                            'SCORE',
                            style: TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.w900,
                              color: AppColors.surfaceContainerHigh(
                                context,
                              ).withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GAME SUMMARY',
                              style: TextStyle(
                                color: AppColors.textMuted(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Match Result',
                              style: TextStyle(
                                color: AppColors.textMain(context),
                                fontSize: isCompactLayout ? 28 : 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sports_tennis,
                                    color: AppColors.primary(context),
                                    size: 16,
                                  ),
                                  Text(
                                    '${_getGameModeLabel().toUpperCase()} • ${_getLogicLabel(widget.match.matchLogic).toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: AppColors.textMuted(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Matchup info banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF040E1F),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.bolt,
                            color: Color(0xFFCAFD00),
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'GENERATED MATCH',
                            style: TextStyle(
                              color: Color(0xFFCAFD00),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isDoubles
                                ? '${widget.match.teamA.length + widget.match.teamB.length} players matched into 2 teams'
                                : '1 vs 1 showdown ready',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isCompactLayout ? 20 : 24,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // VS Grid
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          children: [
                            _buildTeamCard('A', 'TEAM A', widget.match.teamA),
                            const SizedBox(height: 16),
                            _buildTeamCard('B', 'TEAM B', widget.match.teamB),
                          ],
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.background(context),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.divider(context),
                              width: 4,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'VS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textMuted(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),

                    // Final Actions
                    if (isCompactLayout)
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: _buildSaveResultButton(context),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: _buildReshuffleButton(context),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildSaveResultButton(context),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildReshuffleButton(context),
                          ),
                        ],
                      ),
                    const SizedBox(height: 110),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAccessDeniedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: AppColors.primary(context),
                ),
                const SizedBox(height: 16),
                Text(
                  'Admin Access Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Only admin accounts can declare and save match results.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCard(String teamId, String teamName, List<Player> players) {
    final bool isWinner = _selectedWinner == teamId;
    final isCompactLayout = MediaQuery.sizeOf(context).width < 430;

    return GestureDetector(
      onTap: () => _selectWinner(teamId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isWinner
              ? const Color(0xFFCAFD00)
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(32),
          boxShadow: isWinner
              ? [
                  BoxShadow(
                    color: const Color(0xFFCAFD00).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamName,
                      style: TextStyle(
                        fontSize: isCompactLayout ? 24 : 28,
                        fontWeight: FontWeight.w900,
                        color: isWinner
                            ? const Color(0xFF242F41)
                            : AppColors.textMain(context),
                      ),
                    ),
                  ],
                ),
                if (isWinner)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCAFD00),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      color: Color(0xFF4A5E00),
                      size: 28,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            // Dynamic Player Rows
            ...players.map((player) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPlayerRow(player, isWinner),
              );
            }),
            // Winner selector footer
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isWinner
                        ? const Color(0xFF4A5E00).withValues(alpha: 0.2)
                        : AppColors.divider(context),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      isWinner ? '🏆 WINNER' : 'TAP TO SELECT WINNER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: isWinner
                            ? const Color(0xFF4A5E00).withValues(alpha: 0.8)
                            : AppColors.textMuted(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isWinner
                          ? AppColors.primary(context)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isWinner
                          ? null
                          : Border.all(
                              color: AppColors.border(context),
                              width: 2,
                            ),
                    ),
                    child: isWinner
                        ? Icon(
                            Icons.check,
                            size: 14,
                            color: AppColors.onPrimary(context),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  MemoryImage? _playerProfileImage(String? profileImageBase64) {
    if (profileImageBase64 == null || profileImageBase64.isEmpty) {
      return null;
    }

    try {
      return MemoryImage(base64Decode(profileImageBase64));
    } catch (_) {
      return null;
    }
  }

  String _playerInitial(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return '?';
    }

    return trimmedName[0].toUpperCase();
  }

  Widget _buildPlayerRow(Player player, bool isWinner) {
    final details =
        '${player.displayDuprLabel.toUpperCase()} • ${player.displaySkillLabel.toUpperCase()}';
    final profileImage = _playerProfileImage(player.profileImageBase64);
    final playerInitial = _playerInitial(player.name);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isWinner
                ? Colors.white.withValues(alpha: 0.5)
                : AppColors.divider(context),
            borderRadius: BorderRadius.circular(16),
            image: profileImage == null
                ? null
                : DecorationImage(image: profileImage, fit: BoxFit.cover),
            border: Border.all(
              color: isWinner
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppColors.divider(context),
              width: 4,
            ),
          ),
          child: profileImage == null
              ? Center(
                  child: Text(
                    playerInitial,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isWinner
                          ? const Color(0xFF4A5E00)
                          : AppColors.textMuted(context),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isWinner
                      ? const Color(0xFF242F41)
                      : AppColors.textMain(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                details,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: isWinner
                      ? const Color(0xFF4A5E00)
                      : AppColors.textMuted(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveResultButton(BuildContext context) {
    final canSave = _hasExplicitWinner && !_isSaving;
    return ElevatedButton(
      onPressed: canSave ? _confirmAndSaveResult : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.textMain(context),
        foregroundColor: AppColors.isDark(context)
            ? Colors.black
            : Colors.white,
        disabledBackgroundColor: AppColors.textMain(
          context,
        ).withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 10,
      ),
      child: _isSaving
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Color(0xFFCAFD00),
                strokeWidth: 3,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _hasExplicitWinner
                        ? 'Save Result'
                        : 'Select a Winner First',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.isDark(context)
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  color: AppColors.isDark(context)
                      ? Colors.black
                      : Colors.white,
                ),
              ],
            ),
    );
  }

  Widget _buildReshuffleButton(BuildContext context) {
    return TextButton(
      onPressed: _reshuffleMatch,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.surfaceContainerHigh(context),
        foregroundColor: AppColors.textMain(context),
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh, color: AppColors.textMain(context)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Reshuffle',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
