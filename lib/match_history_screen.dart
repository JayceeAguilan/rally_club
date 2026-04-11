import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'firebase_service.dart';
import 'models/match_record.dart';
import 'responsive.dart';
import 'models/player.dart';
import 'auth_provider.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  late Future<List<MatchRecord>> _matchesFuture;
  List<MatchRecord>? _cachedMatches;
  Map<String, Map<String, dynamic>> _standingsMap = {};
  String _filterGameMode = 'All';
  String _filterMatchLogic = 'All';

  @override
  void initState() {
    super.initState();
    _refreshMatches();
  }

  Future<void> _preloadClubData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final clubId = auth.appUser?.clubId;
    if (clubId == null || clubId.isEmpty) {
      return;
    }

    try {
      await FirebaseService().preloadCoreClubData(
        clubId: clubId,
        actingUid: auth.firebaseUser?.uid,
      );
    } catch (_) {
      // Match history can still render from cached matches.
    }
  }

  void _refreshMatches() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _matchesFuture = FirebaseService().getMatches(
        clubId: auth.appUser!.clubId!,
      );
    });

    unawaited(_refreshMatchesFromRemote());
    _loadStandings();
  }

  Future<void> _refreshMatchesFromRemote() async {
    await _preloadClubData();
    if (!mounted) {
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _matchesFuture = FirebaseService().getMatches(
        clubId: auth.appUser!.clubId!,
      );
    });
  }

  Future<void> _loadStandings() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final standings = await FirebaseService().getPlayerStandings(
      clubId: auth.appUser!.clubId!,
    );
    final map = <String, Map<String, dynamic>>{};
    for (final s in standings) {
      final player = s['player'] as Player;
      if (player.id != null) {
        map[player.id!] = {
          'wins': s['wins'] as int,
          'losses': s['losses'] as int,
          'player': player,
        };
      }
    }
    if (mounted) {
      setState(() {
        _standingsMap = map;
      });
    }

    unawaited(_refreshStandingsFromRemote());
  }

  Future<void> _refreshStandingsFromRemote() async {
    await _preloadClubData();
    if (!mounted) {
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final standings = await FirebaseService().getPlayerStandings(
      clubId: auth.appUser!.clubId!,
    );
    final map = <String, Map<String, dynamic>>{};
    for (final s in standings) {
      final player = s['player'] as Player;
      if (player.id != null) {
        map[player.id!] = {
          'wins': s['wins'] as int,
          'losses': s['losses'] as int,
          'player': player,
        };
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _standingsMap = map;
    });
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final months = [
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
        actions: const [TopNavbarSyncStatusIndicator()],
      ),
      body: FutureBuilder<List<MatchRecord>>(
        future: _matchesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _cachedMatches = snapshot.data;
          }

          final matches = _cachedMatches;

          return LayoutBuilder(
            builder: (context, constraints) {
              final r = Responsive(context);
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: r.pagePadding,
                  vertical: 16.0,
                ),
                child: r.constrainWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'Match History',
                        style: TextStyle(
                          color: AppColors.textMain(context),
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Match count badge
                      if (matches != null && matches.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCAFD00),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${matches.length} MATCH${matches.length > 1 ? 'ES' : ''} RECORDED',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4A5E00),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              'MODE:',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: AppColors.textMuted(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildChip(
                              'All',
                              _filterGameMode,
                              (v) => setState(() => _filterGameMode = v),
                            ),
                            const SizedBox(width: 6),
                            _buildChip(
                              'singles',
                              _filterGameMode,
                              (v) => setState(() => _filterGameMode = v),
                              label: 'Singles',
                            ),
                            const SizedBox(width: 6),
                            _buildChip(
                              'doubles',
                              _filterGameMode,
                              (v) => setState(() => _filterGameMode = v),
                              label: 'Doubles',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              'LOGIC:',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: AppColors.textMuted(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildChip(
                              'All',
                              _filterMatchLogic,
                              (v) => setState(() => _filterMatchLogic = v),
                            ),
                            const SizedBox(width: 6),
                            _buildChip(
                              'auto',
                              _filterMatchLogic,
                              (v) => setState(() => _filterMatchLogic = v),
                              label: 'Auto',
                            ),
                            const SizedBox(width: 6),
                            _buildChip(
                              'skill',
                              _filterMatchLogic,
                              (v) => setState(() => _filterMatchLogic = v),
                              label: 'Skill',
                            ),
                            const SizedBox(width: 6),
                            _buildChip(
                              'history',
                              _filterMatchLogic,
                              (v) => setState(() => _filterMatchLogic = v),
                              label: 'W&L',
                            ),
                            const SizedBox(width: 6),
                            _buildChip(
                              'mixed',
                              _filterMatchLogic,
                              (v) => setState(() => _filterMatchLogic = v),
                              label: 'Mixed',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Match List or Empty State
                      if (matches == null || matches.isEmpty)
                        _buildEmptyState()
                      else
                        ...() {
                          final filtered = matches.where((m) {
                            final modeOk =
                                _filterGameMode == 'All' ||
                                m.gameMode == _filterGameMode;
                            final logicOk =
                                _filterMatchLogic == 'All' ||
                                m.matchLogic == _filterMatchLogic;
                            return modeOk && logicOk;
                          }).toList();
                          if (filtered.isEmpty) {
                            return [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                ),
                                child: Center(
                                  child: Text(
                                    'No matches match your filters.',
                                    style: TextStyle(
                                      color: AppColors.textMuted(context),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ];
                          }
                          return filtered
                              .map(
                                (match) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildMatchCard(match),
                                ),
                              )
                              .toList();
                        }(),

                      const SizedBox(height: 32),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 64,
              color: AppColors.textMuted(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Match History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed matches will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard(MatchRecord match) {
    final isDoubles = match.gameMode == 'doubles';
    final winnerSide = match.winningSide;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: mode badge + date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isDoubles ? 'DOUBLES' : 'SINGLES'} • ${_getLogicLabel(match.matchLogic).toUpperCase()}',
                    style: TextStyle(
                      color: AppColors.primary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(match.date)} • ${_formatTime(match.date)}',
                    style: TextStyle(
                      color: AppColors.textMuted(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              // Winner badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFCAFD00),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      size: 14,
                      color: Color(0xFF4A5E00),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'TEAM $winnerSide',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4A5E00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Team A row
          _buildTeamRow(
            label: 'TEAM A',
            names: match.teamANames,
            playerIds: match.teamAPlayerIds,
            isWinner: winnerSide == 'A',
          ),
          const SizedBox(height: 12),

          // VS divider
          Row(
            children: [
              Expanded(
                child: Container(height: 1, color: AppColors.divider(context)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
              Expanded(
                child: Container(height: 1, color: AppColors.divider(context)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Team B row
          _buildTeamRow(
            label: 'TEAM B',
            names: match.teamBNames,
            playerIds: match.teamBPlayerIds,
            isWinner: winnerSide == 'B',
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRow({
    required String label,
    required String names,
    required String playerIds,
    required bool isWinner,
  }) {
    final nameList = names.split(', ');
    final idList = playerIds.split(',').map((e) => e.trim()).toList();

    return Column(
      children: List.generate(nameList.length, (i) {
        final name = nameList[i];
        final id = i < idList.length ? idList[i] : null;

        String? profileBase64;
        if (id != null && _standingsMap.containsKey(id)) {
          final player = _standingsMap[id]!['player'] as Player;
          profileBase64 = player.profileImageBase64;
        }

        return Padding(
          padding: EdgeInsets.only(bottom: i < nameList.length - 1 ? 12 : 0),
          child: Row(
            children: [
              // Avatar/Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isWinner
                      ? const Color(0xFFCAFD00)
                      : AppColors.divider(context),
                  borderRadius: BorderRadius.circular(12),
                  image: profileBase64 != null && profileBase64.isNotEmpty
                      ? DecorationImage(
                          image: MemoryImage(base64Decode(profileBase64)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: profileBase64 == null || profileBase64.isEmpty
                    ? Icon(
                        isWinner ? Icons.emoji_events : Icons.person,
                        color: isWinner
                            ? const Color(0xFF4A5E00)
                            : AppColors.textMuted(context),
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Name + label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isWinner
                            ? FontWeight.w900
                            : FontWeight.w500,
                        color: isWinner
                            ? AppColors.textMain(context)
                            : AppColors.textSub(context),
                      ),
                    ),
                    if (i == 0)
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: isWinner
                              ? const Color(0xFF4A5E00)
                              : AppColors.textMuted(context),
                        ),
                      ),
                  ],
                ),
              ),
              // Winner/Loser Label
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isWinner
                      ? const Color(0xFF4A5E00).withValues(alpha: 0.1)
                      : AppColors.divider(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isWinner ? 'WINNER' : 'LOSER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isWinner
                        ? AppColors.primary(context)
                        : AppColors.textMuted(context),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildChip(
    String value,
    String currentValue,
    ValueChanged<String> onTap, {
    String? label,
  }) {
    final isActive = currentValue == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFCAFD00)
              : AppColors.divider(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label ?? value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isActive
                ? const Color(0xFF4A5E00)
                : AppColors.textMuted(context),
          ),
        ),
      ),
    );
  }
}
