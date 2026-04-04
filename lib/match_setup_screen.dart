import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'match_result_screen.dart';
import 'firebase_service.dart';
import 'models/player.dart';
import 'match_generator.dart';
import 'responsive.dart';
import 'auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    refreshPlayers();
  }

  void refreshPlayers() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _playersFuture = auth.isAdmin
          ? FirebaseService().getPlayers(clubId: auth.appUser!.clubId!)
          : Future.value(const <Player>[]);
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
                                  'Algorithmically balances teams based on individual skill ratings.',
                              icon: Icons.balance,
                              isRecommended: true,
                            ),
                            const SizedBox(height: 12),
                            _buildLogicCard(
                              id: 'skill',
                              title: 'Skill-Separated',
                              subtitle:
                                  'Matches players with the exact same skill level together.',
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
                                                    snapshot.data
                                                        ?.where(
                                                          (p) => p.isAvailable,
                                                        )
                                                        .length ??
                                                    0;
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
                                          '92% CAPACITY REACHED',
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
                                          : () async {
                                              final auth =
                                                  Provider.of<AuthProvider>(
                                                    context,
                                                    listen: false,
                                                  );
                                              setState(() {
                                                _isGenerating = true;
                                              });

                                              await Future.delayed(
                                                const Duration(
                                                  milliseconds: 1200,
                                                ),
                                              );
                                              final allPlayers =
                                                  await FirebaseService()
                                                      .getPlayers(
                                                        clubId: auth
                                                            .appUser!
                                                            .clubId!,
                                                      );

                                              final logic =
                                                  (_selectedLogic == 'mixed' &&
                                                      _selectedMode ==
                                                          'singles')
                                                  ? 'auto'
                                                  : _selectedLogic;

                                              Map<String, Map<String, int>>?
                                              standingsMap;
                                              if (logic == 'history') {
                                                final standings =
                                                    await FirebaseService()
                                                        .getPlayerStandings(
                                                          clubId: auth
                                                              .appUser!
                                                              .clubId!,
                                                        );
                                                standingsMap = {};
                                                for (final s in standings) {
                                                  final player =
                                                      s['player'] as Player;
                                                  if (player.id != null) {
                                                    standingsMap[player.id!] = {
                                                      'wins': s['wins'] as int,
                                                      'losses':
                                                          s['losses'] as int,
                                                    };
                                                  }
                                                }
                                              }

                                              final result =
                                                  MatchGenerator.generate(
                                                    availablePlayers:
                                                        allPlayers,
                                                    gameMode: _selectedMode,
                                                    matchLogic: logic,
                                                    playerStandings:
                                                        standingsMap,
                                                  );

                                              if (!context.mounted) return;

                                              setState(() {
                                                _isGenerating = false;
                                              });

                                              if (!result.isSuccess) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      result.error!,
                                                    ),
                                                    backgroundColor:
                                                        AppColors.textMain(
                                                          context,
                                                        ),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      MatchResultScreen(
                                                        match: result.match!,
                                                      ),
                                                ),
                                              );
                                            },
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
                                              : () async {
                                                  final auth =
                                                      Provider.of<AuthProvider>(
                                                        context,
                                                        listen: false,
                                                      );
                                                  setState(() {
                                                    _isGenerating = true;
                                                  });
                                                  await Future.delayed(
                                                    const Duration(
                                                      milliseconds: 800,
                                                    ),
                                                  );
                                                  final players =
                                                      await FirebaseService()
                                                          .getPlayers(
                                                            clubId: auth
                                                                .appUser!
                                                                .clubId!,
                                                          );
                                                  final available = players
                                                      .where(
                                                        (p) => p.isAvailable,
                                                      )
                                                      .toList();
                                                  Map<String, Map<String, int>>?
                                                  standings;
                                                  if (_selectedLogic ==
                                                      'history') {
                                                    final standingsList =
                                                        await FirebaseService()
                                                            .getPlayerStandings(
                                                              clubId: auth
                                                                  .appUser!
                                                                  .clubId!,
                                                            );
                                                    standings = {};
                                                    for (final s
                                                        in standingsList) {
                                                      final p =
                                                          s['player'] as Player;
                                                      if (p.id != null) {
                                                        standings[p.id!] = {
                                                          'wins':
                                                              s['wins'] as int,
                                                          'losses':
                                                              s['losses']
                                                                  as int,
                                                        };
                                                      }
                                                    }
                                                  }
                                                  final result =
                                                      MatchGenerator.generate(
                                                        gameMode: _selectedMode,
                                                        matchLogic:
                                                            _selectedLogic,
                                                        availablePlayers:
                                                            available,
                                                        playerStandings:
                                                            standings,
                                                      );

                                                  setState(() {
                                                    _isGenerating = false;
                                                  });

                                                  if (!context.mounted) return;
                                                  if (!result.isSuccess) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          result.error ??
                                                              'Error',
                                                        ),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          MatchResultScreen(
                                                            match:
                                                                result.match!,
                                                          ),
                                                    ),
                                                  );
                                                },
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
}
