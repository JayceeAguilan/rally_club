import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';
import 'firebase_service.dart';
import 'main.dart';
import 'models/match_record.dart';
import 'models/player.dart';
import 'responsive.dart';

class PlayerMatchHistoryScreen extends StatefulWidget {
  const PlayerMatchHistoryScreen({
    super.key,
    required this.player,
    this.loadMatches,
  });

  final Player player;
  final Future<List<MatchRecord>> Function(String clubId)? loadMatches;

  @override
  State<PlayerMatchHistoryScreen> createState() =>
      _PlayerMatchHistoryScreenState();
}

class _PlayerMatchHistoryStats {
  const _PlayerMatchHistoryStats({
    required this.matchesPlayed,
    required this.wins,
    required this.losses,
    required this.recentResults,
  });

  final int matchesPlayed;
  final int wins;
  final int losses;
  final List<String> recentResults;
}

class _PlayerMatchHistoryScreenState extends State<PlayerMatchHistoryScreen> {
  late Future<List<MatchRecord>> _matchesFuture;
  List<MatchRecord>? _cachedMatches;

  @override
  void initState() {
    super.initState();
    _refreshMatches();
  }

  void _refreshMatches() {
    final auth = context.read<AuthProvider>();
    final loadMatches =
        widget.loadMatches ??
        ((clubId) => FirebaseService().getMatches(clubId: clubId));

    setState(() {
      _matchesFuture = loadMatches(auth.appUser!.clubId!);
    });
  }

  _PlayerMatchHistoryStats _buildStats(List<MatchRecord> matches) {
    if (widget.player.id == null) {
      return const _PlayerMatchHistoryStats(
        matchesPlayed: 0,
        wins: 0,
        losses: 0,
        recentResults: [],
      );
    }

    var wins = 0;
    var losses = 0;
    final recentResults = <String>[];

    for (final match in matches) {
      final didWin = match.didPlayerWin(widget.player.id!);
      if (didWin) {
        wins += 1;
      } else {
        losses += 1;
      }

      if (recentResults.length < 5) {
        recentResults.add(didWin ? 'W' : 'L');
      }
    }

    return _PlayerMatchHistoryStats(
      matchesPlayed: matches.length,
      wins: wins,
      losses: losses,
      recentResults: recentResults,
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  String _formatTime(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return '';
    }
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
      default:
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isOwnProfile = widget.player.isOwnedByUser(
      linkedPlayerId: auth.appUser?.playerId,
      userUid: auth.firebaseUser?.uid,
    );

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context).withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const AppBrandTitle(),
        actions: [
          IconButton(
            onPressed: _refreshMatches,
            icon: Icon(Icons.refresh, color: AppColors.primary(context)),
            tooltip: 'Refresh player history',
          ),
        ],
      ),
      body: FutureBuilder<List<MatchRecord>>(
        future: _matchesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _cachedMatches = snapshot.data;
          }

          final matches = _cachedMatches;

          if (matches == null) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primary(context),
              ),
            );
          }

          final playerId = widget.player.id;
          final playerMatches = playerId == null
              ? <MatchRecord>[]
              : matches
                    .where((match) => match.includesPlayer(playerId))
                    .toList();
          final stats = _buildStats(playerMatches);

          return LayoutBuilder(
            builder: (context, constraints) {
              final r = Responsive(context);
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: r.pagePadding,
                  vertical: 16,
                ),
                child: r.constrainWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROFILE TIMELINE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMuted(context),
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOwnProfile
                            ? 'MY MATCH HISTORY'
                            : '${widget.player.name.toUpperCase()} HISTORY',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMain(context),
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sessions played, partners, opponents, wins, losses, and recent results.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildPlayerHeader(context, stats),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              label: 'SESSIONS',
                              value: stats.matchesPlayed.toString(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              label: 'WINS',
                              value: stats.wins.toString(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              label: 'LOSSES',
                              value: stats.losses.toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRecentResults(context, stats),
                      const SizedBox(height: 24),
                      if (playerMatches.isEmpty)
                        _buildEmptyState(context, isOwnProfile)
                      else ...[
                        Text(
                          'SESSION TIMELINE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textMuted(context),
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...playerMatches.map(
                          (match) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildTimelineCard(context, match),
                          ),
                        ),
                      ],
                      SizedBox(height: r.bottomNavPadding),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlayerHeader(
    BuildContext context,
    _PlayerMatchHistoryStats stats,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.border(context),
              borderRadius: BorderRadius.circular(18),
              image: widget.player.profileImageBase64 != null
                  ? DecorationImage(
                      image: MemoryImage(
                        base64Decode(widget.player.profileImageBase64!),
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.player.profileImageBase64 == null
                ? const Icon(Icons.person, color: Colors.white, size: 34)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.player.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.player.displaySkillLabel} • ${widget.player.gender}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${stats.matchesPlayed} session${stats.matchesPlayed == 1 ? '' : 's'} played',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.textMuted(context),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textMain(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentResults(
    BuildContext context,
    _PlayerMatchHistoryStats stats,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECENT RESULTS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.textMuted(context),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          if (stats.recentResults.isEmpty)
            Text(
              'No recent results yet.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted(context),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stats.recentResults.map((result) {
                final isWin = result == 'W';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isWin
                        ? const Color(0xFFCAFD00).withValues(alpha: 0.25)
                        : AppColors.surfaceContainerHigh(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    result,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isWin
                          ? const Color(0xFF4A5E00)
                          : AppColors.textMuted(context),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isOwnProfile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 56,
              color: AppColors.textMuted(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 18),
            Text(
              'No Match Timeline Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textMain(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOwnProfile
                  ? 'Your sessions, partners, opponents, and results will appear here after you play recorded matches.'
                  : 'This player has not appeared in any recorded matches yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context, MatchRecord match) {
    final playerId = widget.player.id!;
    final didWin = match.didPlayerWin(playerId);
    final partners = match.partnerNamesFor(playerId);
    final opponents = match.opponentNamesFor(playerId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatDate(match.date)} • ${_formatTime(match.date)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${match.gameMode == 'doubles' ? 'DOUBLES' : 'SINGLES'} • ${_getLogicLabel(match.matchLogic).toUpperCase()}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppColors.primary(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: didWin
                      ? const Color(0xFFCAFD00).withValues(alpha: 0.25)
                      : AppColors.surfaceContainerHigh(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  didWin ? 'WIN' : 'LOSS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: didWin
                        ? const Color(0xFF4A5E00)
                        : AppColors.textMuted(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TimelineDetailRow(
            label: 'Partners',
            value: partners.isEmpty ? 'Solo' : partners.join(', '),
          ),
          const SizedBox(height: 12),
          _TimelineDetailRow(
            label: 'Opponents',
            value: opponents.isEmpty ? 'Unavailable' : opponents.join(', '),
          ),
          const SizedBox(height: 12),
          _TimelineDetailRow(
            label: 'Recent result',
            value: didWin ? 'Won this session' : 'Lost this session',
          ),
        ],
      ),
    );
  }
}

class _TimelineDetailRow extends StatelessWidget {
  const _TimelineDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.textMuted(context),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain(context),
            ),
          ),
        ),
      ],
    );
  }
}
