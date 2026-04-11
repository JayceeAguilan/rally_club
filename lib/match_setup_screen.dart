import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'match_result_screen.dart';
import 'firebase_service.dart';
import 'models/player.dart';
import 'match_generator.dart';
import 'responsive.dart';
import 'auth_provider.dart';
import 'session_guest_player_store.dart';

class MatchSetupScreen extends StatefulWidget {
  const MatchSetupScreen({super.key});

  @override
  MatchSetupScreenState createState() => MatchSetupScreenState();
}

class MatchSetupScreenState extends State<MatchSetupScreen> {
  String _selectedMode = 'doubles';
  String _selectedLogic = 'auto';
  bool _isGenerating = false;
  Future<List<Player>> _playersFuture = Future.value(const <Player>[]);
  List<Player> _guestPlayers = SessionGuestPlayerStore.instance.players;

  @override
  void initState() {
    super.initState();
    refreshPlayers();
  }

  void refreshPlayers() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAdmin) {
      setState(() {
        _playersFuture = Future.value(const <Player>[]);
      });
      return;
    }

    final future = FirebaseService()
        .getPlayers(clubId: auth.appUser!.clubId!)
        .then((players) {
          if (mounted) {
            setState(() {
              _playersFuture = Future.value(players);
            });
          } else {
            _playersFuture = Future.value(players);
          }
          return players;
        });

    setState(() {
      _playersFuture = future;
    });
  }

  List<Player> _buildSessionPlayers(List<Player> permanentPlayers) {
    return SessionGuestPlayerStore.mergeSessionPlayers(
      permanentPlayers: permanentPlayers,
      guestPlayers: _guestPlayers,
    );
  }

  Future<Map<String, Map<String, int>>?> _loadStandingsMap({
    required String clubId,
    required String logic,
  }) async {
    if (logic != 'history') {
      return null;
    }

    final standings = await FirebaseService().getPlayerStandings(
      clubId: clubId,
    );
    final standingsMap = <String, Map<String, int>>{};
    for (final standing in standings) {
      final player = standing['player'] as Player;
      if (player.id == null) {
        continue;
      }

      standingsMap[player.id!] = {
        'wins': standing['wins'] as int,
        'losses': standing['losses'] as int,
      };
    }
    return standingsMap;
  }

  Future<void> _generateMatch({required int delayMilliseconds}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _isGenerating = true;
    });

    await Future.delayed(Duration(milliseconds: delayMilliseconds));

    final permanentPlayers = await FirebaseService().getPlayers(
      clubId: auth.appUser!.clubId!,
    );
    final logic = (_selectedLogic == 'mixed' && _selectedMode == 'singles')
        ? 'auto'
        : _selectedLogic;
    final standingsMap = await _loadStandingsMap(
      clubId: auth.appUser!.clubId!,
      logic: logic,
    );
    final result = MatchGenerator.generate(
      availablePlayers: _buildSessionPlayers(permanentPlayers),
      gameMode: _selectedMode,
      matchLogic: logic,
      playerStandings: standingsMap,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isGenerating = false;
    });

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error!),
          backgroundColor: AppColors.textMain(context),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchResultScreen(match: result.match!),
      ),
    );
  }

  Future<void> _openGuestPlayerSheet({Player? player}) async {
    final sessionPlayer = await showModalBottomSheet<Player>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GuestPlayerSheet(playerToEdit: player),
    );

    if (sessionPlayer == null || !mounted) {
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final permanentPlayers = await FirebaseService().getPlayers(
      clubId: auth.appUser!.clubId!,
    );

    if (!mounted) {
      return;
    }

    final normalizedName = sessionPlayer.name.trim().toLowerCase();
    final hasDuplicateName = _buildSessionPlayers(permanentPlayers).any(
      (existingPlayer) =>
          existingPlayer.id != sessionPlayer.id &&
          existingPlayer.name.trim().toLowerCase() == normalizedName,
    );
    if (hasDuplicateName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That name is already in the current session.'),
        ),
      );
      return;
    }

    SessionGuestPlayerStore.instance.upsert(sessionPlayer);
    setState(() {
      _guestPlayers = SessionGuestPlayerStore.instance.players;
    });
  }

  void _toggleGuestAvailability(Player guestPlayer, bool isAvailable) {
    SessionGuestPlayerStore.instance.upsert(
      guestPlayer.copyWith(isAvailable: isAvailable),
    );
    setState(() {
      _guestPlayers = SessionGuestPlayerStore.instance.players;
    });
  }

  void _removeGuestPlayer(Player guestPlayer) {
    final playerId = guestPlayer.id;
    if (playerId == null) {
      return;
    }

    SessionGuestPlayerStore.instance.remove(playerId);
    setState(() {
      _guestPlayers = SessionGuestPlayerStore.instance.players;
    });
  }

  void _clearGuestPlayers() {
    SessionGuestPlayerStore.instance.clear();
    setState(() {
      _guestPlayers = SessionGuestPlayerStore.instance.players;
    });
  }

  void setGameMode(String mode) {
    setState(() {
      _selectedMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthProvider, bool>((auth) => auth.isAdmin);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context).withValues(alpha: 0.7),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const AppBrandTitle(),
        leading: IconButton(
          icon: Icon(Icons.menu, color: AppColors.primary(context)),
          onPressed: () {
            mainScaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      body: !isAdmin
          ? _buildAccessDeniedState(context)
          : LayoutBuilder(
              builder: (context, constraints) {
                final r = Responsive(context);
                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.pagePadding,
                        vertical: 16.0,
                      ),
                      child: r.constrainWidth(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Screen Header
                            Text(
                              'Match Setup',
                              style: TextStyle(
                                color: AppColors.textMain(context),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Step 1: Game Mode
                            _buildSectionTitle('01', 'Select Game Mode'),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildGameModeCard(
                                    id: 'singles',
                                    title: 'Singles',
                                    subtitle: '1 vs 1 intense court coverage',
                                    icon: Icons.person,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildGameModeCard(
                                    id: 'doubles',
                                    title: 'Doubles',
                                    subtitle: '2 vs 2 tactical team play',
                                    icon: Icons.groups,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Step 2: Matching Logic
                            _buildSectionTitle('02', 'Matching Logic'),
                            const SizedBox(height: 16),
                            _buildLogicCard(
                              id: 'auto',
                              title: 'Auto-Balanced',
                              subtitle:
                                  'Algorithmically balances teams based on current DUPR ratings.',
                              icon: Icons.balance,
                              isRecommended: true,
                            ),
                            const SizedBox(height: 12),
                            _buildLogicCard(
                              id: 'skill',
                              title: 'Skill-Separated',
                              subtitle:
                                  'Matches players within the same derived DUPR band together.',
                              icon: Icons.equalizer,
                            ),
                            const SizedBox(height: 12),
                            _buildLogicCard(
                              id: 'history',
                              title: 'Winners and Losers',
                              subtitle:
                                  'Matches previous match winners against other winners.',
                              icon: Icons.military_tech,
                            ),
                            // Only show Mixed Doubles when Doubles mode is selected
                            if (_selectedMode == 'doubles') ...[
                              const SizedBox(height: 12),
                              _buildLogicCard(
                                id: 'mixed',
                                title: 'Mixed Doubles',
                                subtitle:
                                    'Mandates one male and one female player per team.',
                                icon: Icons.diversity_3,
                              ),
                            ],
                            const SizedBox(height: 32),

                            _buildSectionTitle('03', 'Session Guests'),
                            const SizedBox(height: 16),
                            _buildGuestPlayerSection(),
                            const SizedBox(height: 32),

                            // Session Summary
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh(context),
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Session Summary',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textMain(context),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Heatmap Concept
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface(context),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'ACTIVE PLAYERS',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5,
                                                color: AppColors.textMuted(
                                                  context,
                                                ),
                                              ),
                                            ),
                                            FutureBuilder<List<Player>>(
                                              future: _playersFuture,
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  );
                                                }
                                                final activeCount =
                                                    _buildSessionPlayers(
                                                          snapshot.data ??
                                                              const <Player>[],
                                                        )
                                                        .where(
                                                          (p) => p.isAvailable,
                                                        )
                                                        .length;
                                                return Text(
                                                  activeCount.toString(),
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppColors.primary(
                                                      context,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            for (var i = 0; i < 4; i++) ...[
                                              Expanded(
                                                child: Container(
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary(
                                                      context,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Expanded(
                                              child: Container(
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary(
                                                    context,
                                                  ).withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Container(
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary(
                                                    context,
                                                  ).withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _guestPlayers.isEmpty
                                              ? 'INCLUDING PERMANENT ROSTER'
                                              : 'INCLUDING ${_guestPlayers.where((player) => player.isAvailable).length} ACTIVE GUEST${_guestPlayers.where((player) => player.isAvailable).length == 1 ? '' : 'S'}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textMuted(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isGenerating
                                          ? null
                                          : () => _generateMatch(
                                              delayMilliseconds: 1200,
                                            ),
                                      icon: _isGenerating
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Color(0xFF4A5E00),
                                                strokeWidth: 3,
                                              ),
                                            )
                                          : const Text(
                                              'Generate Match',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF4A5E00),
                                              ),
                                            ),
                                      label: _isGenerating
                                          ? const SizedBox.shrink()
                                          : const Icon(
                                              Icons.bolt,
                                              color: Color(0xFF4A5E00),
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFCAFD00,
                                        ),
                                        disabledBackgroundColor: const Color(
                                          0xFFCAFD00,
                                        ).withValues(alpha: 0.6),
                                        foregroundColor: const Color(
                                          0xFF4A5E00,
                                        ),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Reshuffle & Reset buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: _isGenerating
                                              ? null
                                              : () => _generateMatch(
                                                  delayMilliseconds: 800,
                                                ),
                                          icon: const Icon(
                                            Icons.refresh,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Reshuffle',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            backgroundColor:
                                                AppColors.surfaceContainerHigh(
                                                  context,
                                                ),
                                            foregroundColor: AppColors.textMain(
                                              context,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _selectedMode = 'doubles';
                                              _selectedLogic = 'auto';
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.restart_alt,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Reset',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            backgroundColor: AppColors.divider(
                                              context,
                                            ),
                                            foregroundColor:
                                                AppColors.textMuted(context),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: r.bottomNavPadding),
                          ],
                        ), // Close Column
                      ), // Close constrainWidth
                    ), // Close SingleChildScrollView
                    // Full Screen Epic Loading Overlay
                    if (_isGenerating)
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xFF040E1F).withValues(alpha: 0.9),
                          child: TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 300),
                            builder: (context, double value, child) {
                              return Opacity(
                                opacity: value,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFCAFD00),
                                          strokeWidth: 6,
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      const Text(
                                        'GENERATING MATCH',
                                        style: TextStyle(
                                          color: Color(0xFFCAFD00),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 4.0,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Running ${_selectedLogic.toUpperCase()} algorithm...',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ); // Close Stack
              }, // Close LayoutBuilder builder
            ), // Close LayoutBuilder
    ); // Close Scaffold
  }

  Widget _buildSectionTitle(String number, String title) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary(context),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.onPrimary(context),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textMain(context),
          ),
        ),
      ],
    );
  }

  Widget _buildGameModeCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = _selectedMode == id;
    final isDark = AppColors.isDark(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = id;
          if (id == 'singles' && _selectedLogic == 'mixed') {
            _selectedLogic = 'auto';
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary(context)
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: isSelected
                      ? AppColors.onPrimary(context)
                      : AppColors.textMain(context).withValues(alpha: 0.4),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFFCAFD00))
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? null
                        : Border.all(
                            color: AppColors.border(context),
                            width: 2,
                          ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: isSelected ? AppColors.primary(context) : null,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isSelected
                    ? AppColors.onPrimary(context)
                    : AppColors.textMain(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? AppColors.onPrimary(context).withValues(alpha: 0.8)
                    : AppColors.textMuted(context),
              ),
            ),
          ],
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
                  'Only admin accounts can generate matches.',
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

  Widget _buildLogicCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    bool isRecommended = false,
  }) {
    final bool isSelected = _selectedLogic == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLogic = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surface(context)
              : AppColors.divider(context),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: const Color(0xFFCAFD00), width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFCAFD00)
                    : AppColors.surfaceContainerHigh(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF4A5E00)
                    : AppColors.primary(context),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMain(context),
                        ),
                      ),
                      if (isRecommended)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onPrimary(context),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestPlayerSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh(context),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temporary guest players stay only in the active session and never create a permanent account.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_guestPlayers.length} guest${_guestPlayers.length == 1 ? '' : 's'} ready',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.3,
                        color: AppColors.primary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => _openGuestPlayerSheet(),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add Guest'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: AppColors.onPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_guestPlayers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'No guest players added yet. Use this when someone is joining today without a permanent Rally Club account.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textMuted(context),
                ),
              ),
            )
          else ...[
            for (final guestPlayer in _guestPlayers) ...[
              _buildGuestPlayerCard(guestPlayer),
              const SizedBox(height: 12),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearGuestPlayers,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Clear Session Guests'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuestPlayerCard(Player guestPlayer) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openGuestPlayerSheet(player: guestPlayer),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                color: AppColors.primary(context),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          guestPlayer.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textMain(context),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary(context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'GUEST',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: AppColors.onPrimary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildGuestMetaChip(guestPlayer.gender),
                      _buildGuestMetaChip(guestPlayer.displayDuprLabel),
                      _buildGuestMetaChip(
                        guestPlayer.isAvailable ? 'Available' : 'Bench',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile.adaptive(
                          value: guestPlayer.isAvailable,
                          onChanged: (value) =>
                              _toggleGuestAvailability(guestPlayer, value),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            'Available for matching',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted(context),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit guest',
                        onPressed: () =>
                            _openGuestPlayerSheet(player: guestPlayer),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Remove guest',
                        onPressed: () => _removeGuestPlayer(guestPlayer),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestMetaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: AppColors.textMuted(context),
        ),
      ),
    );
  }
}

class _GuestPlayerSheet extends StatefulWidget {
  final Player? playerToEdit;

  const _GuestPlayerSheet({this.playerToEdit});

  @override
  State<_GuestPlayerSheet> createState() => _GuestPlayerSheetState();
}

class _GuestPlayerSheetState extends State<_GuestPlayerSheet> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedGender = 'Male';
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    final player = widget.playerToEdit;
    if (player == null) {
      return;
    }

    _nameController.text = player.name;
    _selectedGender = player.gender;
    _isAvailable = player.isAvailable;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveGuestPlayer() {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guest player name is required.')),
      );
      return;
    }

    final existingPlayer = widget.playerToEdit;
    final guestPlayer =
        (existingPlayer ??
                Player(
                  id: SessionGuestPlayerStore.instance.createGuestId(),
                  name: trimmedName,
                  gender: _selectedGender,
                  isAvailable: _isAvailable,
                  isGuest: true,
                ))
            .copyWith(
              name: trimmedName,
              gender: _selectedGender,
              isAvailable: _isAvailable,
              isGuest: true,
              countsAsPlayer: true,
              notes: 'Session guest',
            );

    Navigator.pop(context, guestPlayer);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: kToolbarHeight),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.playerToEdit == null
                            ? 'SESSION GUEST'
                            : 'EDIT SESSION GUEST',
                        style: TextStyle(
                          color: AppColors.primary(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.playerToEdit == null
                            ? 'Add Temporary Player'
                            : 'Update Temporary Player',
                        style: TextStyle(
                          color: AppColors.textMain(context),
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.textMuted(context)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Guest players are available for match generation right away, but they do not create permanent accounts or roster entries.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Guest name',
                filled: true,
                fillColor: AppColors.divider(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Gender',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                for (final gender in const ['Male', 'Female'])
                  ChoiceChip(
                    label: Text(gender),
                    selected: _selectedGender == gender,
                    onSelected: (_) {
                      setState(() {
                        _selectedGender = gender;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'DUPR rating',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFCAFD00).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.playerToEdit?.displayDuprLabel ?? 'DUPR 2.00 BASELINE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textMain(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Session guests start from the same baseline and are classified automatically from recorded results.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile.adaptive(
              value: _isAvailable,
              onChanged: (value) {
                setState(() {
                  _isAvailable = value;
                });
              },
              contentPadding: EdgeInsets.zero,
              title: const Text('Available immediately for match generation'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveGuestPlayer,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  widget.playerToEdit == null
                      ? 'Add Guest Player'
                      : 'Save Guest Player',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: AppColors.onPrimary(context),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
