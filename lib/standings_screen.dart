import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'firebase_service.dart';
import 'models/player.dart';
import 'responsive.dart';
import 'auth_provider.dart';

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  StandingsScreenState createState() => StandingsScreenState();
}

class StandingsScreenState extends State<StandingsScreen> {
  late Future<List<Map<String, dynamic>>> _standingsFuture;
  List<Map<String, dynamic>>? _cachedStandings;
  String _sortBy = 'duprRating';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterSkill = 'All';
  String _filterGender = 'All'; // 'All', 'Male', 'Female'

  @override
  void initState() {
    super.initState();
    refreshStandings();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      // The standings view can still render from cached data.
    }
  }

  void refreshStandings() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _standingsFuture = FirebaseService().getPlayerStandings(
        clubId: auth.appUser!.clubId!,
      );
    });

    unawaited(_refreshStandingsFromRemote());
  }

  Future<void> _refreshStandingsFromRemote() async {
    await _preloadClubData();
    if (!mounted) {
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _standingsFuture = FirebaseService().getPlayerStandings(
        clubId: auth.appUser!.clubId!,
      );
    });
  }

  void _sortStandings(List<Map<String, dynamic>> standings) {
    switch (_sortBy) {
      case 'duprRating':
        standings.sort((a, b) {
          final playerA = a['player'] as Player;
          final playerB = b['player'] as Player;
          final cmp = playerB.effectiveDuprRating.compareTo(
            playerA.effectiveDuprRating,
          );
          if (cmp != 0) return cmp;
          return (b['wins'] as int).compareTo(a['wins'] as int);
        });
        break;
      case 'wins':
        standings.sort(
          (a, b) => (b['wins'] as int).compareTo(a['wins'] as int),
        );
        break;
      case 'losses':
        standings.sort(
          (a, b) => (b['losses'] as int).compareTo(a['losses'] as int),
        );
        break;
      case 'matchesPlayed':
        standings.sort(
          (a, b) =>
              (b['matchesPlayed'] as int).compareTo(a['matchesPlayed'] as int),
        );
        break;
      case 'recentFormScore':
        standings.sort((a, b) {
          final formCmp = (b['recentFormScore'] as double).compareTo(
            a['recentFormScore'] as double,
          );
          if (formCmp != 0) return formCmp;
          return (b['wins'] as int).compareTo(a['wins'] as int);
        });
        break;
      case 'currentStreak':
        standings.sort((a, b) {
          final streakCmp = (b['currentStreak'] as int).compareTo(
            a['currentStreak'] as int,
          );
          if (streakCmp != 0) return streakCmp;
          return (b['wins'] as int).compareTo(a['wins'] as int);
        });
        break;
      case 'winPercent':
      default:
        standings.sort((a, b) {
          final cmp = (b['winPercent'] as double).compareTo(
            a['winPercent'] as double,
          );
          if (cmp != 0) return cmp;
          return (b['wins'] as int).compareTo(a['wins'] as int);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context).withValues(alpha: 0.7),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: AppColors.primary(context)),
          onPressed: () {
            mainScaffoldKey.currentState?.openDrawer();
          },
        ),
        title: const AppBrandTitle(),
        actions: const [TopNavbarSyncStatusIndicator()],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _standingsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _cachedStandings = snapshot.data;
          }
          final standings = _cachedStandings;

          if (standings == null) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primary(context),
              ),
            );
          }

          // Apply current sorting
          _sortStandings(standings);

          // Find top 3 for Season Leaders carousel
          final topPlayers = standings
              .where((s) => (s['wins'] as int) + (s['losses'] as int) > 0)
              .toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final r = Responsive(context);
              return SingleChildScrollView(
                child: r.constrainWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Section
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.pagePadding,
                          vertical: 16.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SEASON STANDINGS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textMuted(context),
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'CLUB STANDINGS',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textMain(context),
                                letterSpacing: -1.0,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Season Leaders
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.workspace_premium,
                              color: AppColors.primary(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Season Leaders',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Carousel
                      SizedBox(
                        height: 180,
                        child: topPlayers.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface(context),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: AppColors.border(context),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Play some matches to see\nseason leaders here.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.textMuted(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                ),
                                physics: const BouncingScrollPhysics(),
                                itemCount: topPlayers.length > 3
                                    ? 3
                                    : topPlayers.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  final s = topPlayers[index];
                                  final player = s['player'] as Player;
                                  final wins = s['wins'] as int;
                                  final losses = s['losses'] as int;
                                  final winPct = s['winPercent'] as double;
                                  final matchesPlayed =
                                      s['matchesPlayed'] as int;
                                  final streakLabel =
                                      s['streakLabel'] as String? ?? '-';
                                  final recentFormScore =
                                      s['recentFormScore'] as double? ?? 0.0;
                                  return _buildLeaderCard(
                                    rank: '#${index + 1}',
                                    name: player.name,
                                    subtitle:
                                        '${player.displayDuprLabel.toUpperCase()} • ${player.displaySkillLabel.toUpperCase()} • ${player.gender.toUpperCase()}',
                                    wins: wins.toString(),
                                    losses: losses.toString(),
                                    winPercent: '${winPct.toStringAsFixed(0)}%',
                                    matchesPlayed: matchesPlayed.toString(),
                                    streakLabel: streakLabel,
                                    recentFormScore: recentFormScore
                                        .toStringAsFixed(0),
                                    isFirst: index == 0,
                                    profileImageBase64:
                                        player.profileImageBase64,
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 24),

                      // Sort & Filter
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Search bar
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.divider(context),
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(
                                  color: AppColors.textMain(context),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search players...',
                                  hintStyle: TextStyle(
                                    color: AppColors.textMuted(
                                      context,
                                    ).withValues(alpha: 0.6),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: AppColors.textMuted(context),
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.close,
                                            color: AppColors.textMuted(context),
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _searchController.clear(),
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Sort row
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Text(
                                    'SORT:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: AppColors.textMuted(context),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildSortChip('DUPR', 'duprRating'),
                                  const SizedBox(width: 8),
                                  _buildSortChip('Win %', 'winPercent'),
                                  const SizedBox(width: 8),
                                  _buildSortChip('Most Wins', 'wins'),
                                  const SizedBox(width: 8),
                                  _buildSortChip('Most Losses', 'losses'),
                                  const SizedBox(width: 8),
                                  _buildSortChip('Matches', 'matchesPlayed'),
                                  const SizedBox(width: 8),
                                  _buildSortChip('Form', 'recentFormScore'),
                                  const SizedBox(width: 8),
                                  _buildSortChip('Streak', 'currentStreak'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // DUPR band filter row
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Text(
                                    'DUPR:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: AppColors.textMuted(context),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildFilterChip(
                                    'All',
                                    _filterSkill,
                                    (v) => setState(() => _filterSkill = v),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    'Unrated',
                                    _filterSkill,
                                    (v) => setState(() => _filterSkill = v),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    'Beginner',
                                    _filterSkill,
                                    (v) => setState(() => _filterSkill = v),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    'Intermediate',
                                    _filterSkill,
                                    (v) => setState(() => _filterSkill = v),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    'Advanced',
                                    _filterSkill,
                                    (v) => setState(() => _filterSkill = v),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Gender filter row
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Text(
                                    'GENDER:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: AppColors.textMuted(context),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildFilterChip(
                                    'All',
                                    _filterGender,
                                    (v) => setState(() => _filterGender = v),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    'Male',
                                    _filterGender,
                                    (v) => setState(() => _filterGender = v),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    'Female',
                                    _filterGender,
                                    (v) => setState(() => _filterGender = v),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Table Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.divider(
                              context,
                            ).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  'RANK',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'PLAYER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  'W / L',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  'GP',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  'WIN %',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Standings List
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: () {
                          final filtered = standings.where((s) {
                            final player = s['player'] as Player;
                            final matchesSearch =
                                _searchQuery.isEmpty ||
                                player.name.toLowerCase().contains(
                                  _searchQuery,
                                ) ||
                                player.displayDuprLabel.toLowerCase().contains(
                                  _searchQuery,
                                ) ||
                                player.displaySkillLabel.toLowerCase().contains(
                                  _searchQuery,
                                );
                            final matchesSkill = player.matchesSkillFilter(
                              _filterSkill,
                            );
                            final matchesGender =
                                _filterGender == 'All' ||
                                player.gender == _filterGender;
                            return matchesSearch &&
                                matchesSkill &&
                                matchesGender;
                          }).toList();

                          if (filtered.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 32.0,
                              ),
                              child: Center(
                                child: Text(
                                  'No players match your filters.',
                                  style: TextStyle(
                                    color: AppColors.textMuted(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: filtered.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final s = entry.value;
                              final player = s['player'] as Player;
                              final wins = s['wins'] as int;
                              final losses = s['losses'] as int;
                              final played = s['matchesPlayed'] as int;
                              final winPct = s['winPercent'] as double;
                              final streakLabel =
                                  s['streakLabel'] as String? ?? '-';
                              final recentResults =
                                  (s['recentResults'] as List<dynamic>? ??
                                          const [])
                                      .cast<String>();
                              final recentFormScore =
                                  s['recentFormScore'] as double? ?? 0.0;
                              final bestPartnerName =
                                  s['bestPartnerName'] as String?;
                              final bestPartnerGames =
                                  s['bestPartnerGames'] as int? ?? 0;
                              final bestPartnerWinPercent =
                                  s['bestPartnerWinPercent'] as double? ?? 0.0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildListRow(
                                  '${idx + 1}',
                                  player.name,
                                  '${player.displayDuprLabel.toUpperCase()} • ${player.displaySkillLabel.toUpperCase()} • ${player.gender.toUpperCase()}',
                                  '$wins / $losses',
                                  '$played',
                                  winPct > 0
                                      ? '${winPct.toStringAsFixed(1)}%'
                                      : '-',
                                  streakLabel,
                                  recentResults,
                                  recentFormScore > 0
                                      ? recentFormScore.toStringAsFixed(0)
                                      : '-',
                                  bestPartnerName == null
                                      ? 'No doubles chemistry yet'
                                      : '$bestPartnerName • ${bestPartnerWinPercent.toStringAsFixed(0)}% in $bestPartnerGames',
                                  player.profileImageBase64,
                                ),
                              );
                            }).toList(),
                          );
                        }(),
                      ),

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

  Widget _buildSortChip(String label, String value) {
    final isActive = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary(context)
              : AppColors.surfaceContainerHigh(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive
                ? AppColors.onPrimary(context)
                : AppColors.textMain(context),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String currentValue,
    ValueChanged<String> onTap,
  ) {
    final isActive = currentValue == label;
    return GestureDetector(
      onTap: () => onTap(label),
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
          label,
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

  Widget _buildLeaderCard({
    required String rank,
    required String name,
    required String subtitle,
    required String wins,
    required String losses,
    required String winPercent,
    required String matchesPlayed,
    required String streakLabel,
    required String recentFormScore,
    required bool isFirst,
    String? profileImageBase64,
  }) {
    final isDark = AppColors.isDark(context);
    final bgColor = isFirst
        ? const Color(0xFF040E1F)
        : AppColors.surface(context);
    final textColor = isFirst ? Colors.white : AppColors.textMain(context);
    final accentColor = isFirst
        ? const Color(0xFFD1FA00)
        : AppColors.primary(context);
    final mutedTextColor = isFirst
        ? Colors.grey[400]!
        : AppColors.textMuted(context);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFirst
              ? accentColor.withValues(alpha: 0.3)
              : AppColors.border(context),
          width: isFirst ? 2 : 1,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -16,
            top: -40,
            child: Text(
              rank,
              style: TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: isFirst
                    ? accentColor.withValues(alpha: 0.2)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05)),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isFirst
                          ? accentColor
                          : AppColors.surfaceContainerHigh(context),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(isFirst ? 2 : 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh(context),
                        shape: BoxShape.circle,
                        border: isFirst
                            ? Border.all(color: bgColor, width: 2)
                            : null,
                        image: profileImageBase64 != null
                            ? DecorationImage(
                                image: MemoryImage(
                                  base64Decode(profileImageBase64),
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: profileImageBase64 == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 32,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isFirst
                                ? accentColor
                                : AppColors.textMuted(context),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WINS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: mutedTextColor,
                            ),
                          ),
                          Text(
                            wins,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOSS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: mutedTextColor,
                            ),
                          ),
                          Text(
                            losses,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'WIN RATE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      Text(
                        winPercent,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTrendPill('GP', matchesPlayed, isFirst: isFirst),
                  _buildTrendPill('STREAK', streakLabel, isFirst: isFirst),
                  _buildTrendPill(
                    'FORM',
                    recentFormScore == '-' ? '-' : '$recentFormScore/100',
                    isFirst: isFirst,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListRow(
    String rank,
    String name,
    String subtitle,
    String wl,
    String played,
    String winPercent,
    String streakLabel,
    List<String> recentResults,
    String recentFormScore,
    String chemistryLabel,
    String? profileImageBase64,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  rank,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSub(context),
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh(context),
                  shape: BoxShape.circle,
                  image: profileImageBase64 != null
                      ? DecorationImage(
                          image: MemoryImage(base64Decode(profileImageBase64)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: profileImageBase64 == null
                    ? Icon(Icons.person, color: AppColors.textMuted(context))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain(context),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  wl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain(context),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  played,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  winPercent,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTrendPill('STREAK', streakLabel),
                _buildTrendPill(
                  'FORM',
                  recentFormScore == '-' ? '-' : '$recentFormScore/100',
                ),
                _buildTrendPill(
                  'RECENT',
                  recentResults.isEmpty ? '-' : recentResults.join(' '),
                ),
                _buildTrendPill('CHEM', chemistryLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendPill(String label, String value, {bool isFirst = false}) {
    final background = isFirst
        ? const Color(0xFFD1FA00).withValues(alpha: 0.18)
        : AppColors.surfaceContainerHigh(context);
    final foreground = isFirst
        ? const Color(0xFFD1FA00)
        : AppColors.textMuted(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: foreground,
          ),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: value,
              style: TextStyle(
                color: isFirst ? Colors.white : AppColors.textMain(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
