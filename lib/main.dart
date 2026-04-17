import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'active_match_controller.dart';
import 'player_management_screen.dart';
import 'announcements_screen.dart';
import 'match_generator.dart';
import 'match_result_screen.dart';
import 'match_saved_screen.dart';
import 'match_setup_screen.dart';
import 'standings_screen.dart';
import 'match_history_screen.dart';
import 'firebase_service.dart';
import 'models/player.dart';
import 'responsive.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'models/match_record.dart';
import 'models/announcement_inbox_status.dart';
import 'auth_provider.dart';
import 'auth_gate.dart';
import 'announcement_notification_utils.dart';
import 'sync_status.dart';

class AppColors {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color background(BuildContext context) =>
      isDark(context) ? const Color(0xFF121418) : const Color(0xFFF4F6FF);
  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A1D21) : Colors.white;
  static Color surfaceContainerHigh(BuildContext context) =>
      isDark(context) ? const Color(0xFF23272C) : const Color(0xFFD5E3FF);
  static Color textMain(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF242F41);
  static Color textSub(BuildContext context) =>
      isDark(context) ? const Color(0xFF9098A9) : const Color(0xFF6C778C);
  static Color textMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF7D879C) : const Color(0xFF515C70);
  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF2D323A) : const Color(0xFFCDDDFE);
  static Color divider(BuildContext context) =>
      isDark(context) ? const Color(0xFF2D323A) : const Color(0xFFECF1FF);
  static Color primary(BuildContext context) =>
      isDark(context) ? const Color(0xFFCAFD00) : const Color(0xFF4E6300);
  static Color onPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFF242F41) : Colors.white;
  static Color primaryContainer(BuildContext context) =>
      const Color(0xFFCAFD00);
  static Color onPrimaryContainer(BuildContext context) =>
      const Color(0xFF4A5E00);
}

/// Global theme mode notifier — follows the device theme by default.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

final GlobalKey<ScaffoldState> mainScaffoldKey = GlobalKey<ScaffoldState>();
final GlobalKey<DashboardScreenState> dashboardKey =
    GlobalKey<DashboardScreenState>();
final GlobalKey<MatchSetupScreenState> matchSetupKey =
    GlobalKey<MatchSetupScreenState>();
final GlobalKey<StandingsScreenState> standingsKey =
    GlobalKey<StandingsScreenState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable robust offline caching for the entire app
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ActiveMatchController()),
        ChangeNotifierProvider<SyncStatusController>.value(
          value: SyncStatusController.instance,
        ),
      ],
      child: const KineticCourtApp(),
    ),
  );
}

class KineticCourtApp extends StatelessWidget {
  const KineticCourtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Rally Club',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF4F6FF),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4E6300),
              brightness: Brightness.light,
              primary: const Color(0xFF4E6300),
              onPrimary: Colors.white,
              primaryContainer: const Color(0xFFCAFD00),
              onPrimaryContainer: const Color(0xFF4A5E00),
              surface: const Color(0xFFF4F6FF),
              onSurface: const Color(0xFF242F41),
            ),
            textTheme: const TextTheme(
              displayLarge: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 32,
                letterSpacing: -1.0,
                color: Color(0xFF242F41),
              ),
              titleLarge: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: -0.5,
                color: Color(0xFF242F41),
              ),
              bodyLarge: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Color(0xFF242F41),
              ),
              bodyMedium: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Color(0xFF515C70),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF121418),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFCAFD00),
              brightness: Brightness.dark,
              primary: const Color(0xFFCAFD00),
              onPrimary: const Color(0xFF4A5E00),
              primaryContainer: const Color(0xFFCAFD00),
              onPrimaryContainer: const Color(0xFF4A5E00),
              surface: const Color(0xFF1A1D21),
              onSurface: Colors.white,
            ),
            textTheme: const TextTheme(
              displayLarge: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 32,
                letterSpacing: -1.0,
                color: Colors.white,
              ),
              titleLarge: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
              bodyLarge: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Colors.white,
              ),
              bodyMedium: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Color(0xFF9098A9),
              ),
            ),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int _announcementScreenVisitMarker = 0;
  AnnouncementInboxStatus _announcementInboxStatus =
      const AnnouncementInboxStatus();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateAnnouncementInboxStatus();
    });
  }

  Future<void> _hydrateAnnouncementInboxStatus() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser?.uid ?? auth.appUser?.uid;
    final clubId = auth.appUser?.clubId;
    if (uid == null || clubId == null) {
      return;
    }

    final cachedStatus = await FirebaseService()
        .getCachedAnnouncementInboxStatus(actingUid: uid, clubId: clubId);
    if (mounted && cachedStatus != null) {
      setState(() {
        _announcementInboxStatus = cachedStatus;
      });
    }

    unawaited(_refreshAnnouncementInboxStatus());
  }

  void _selectIndex(int index) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final activeMatchController = context.read<ActiveMatchController>();
    if (!auth.isAdmin && index == 2) {
      setState(() => _currentIndex = 0);
      return;
    }

    if (activeMatchController.isExpanded) {
      activeMatchController.minimize();
    }

    final enteredAnnouncements =
        index == announcementsTabIndex &&
        _currentIndex != announcementsTabIndex;

    setState(() {
      _currentIndex = index;
      if (enteredAnnouncements) {
        _announcementScreenVisitMarker += 1;
      }
    });
    if (index == 0) dashboardKey.currentState?.refreshDashboardData();
    if (index == 2) matchSetupKey.currentState?.refreshPlayers();
    if (index == 3) standingsKey.currentState?.refreshStandings();
  }

  Future<void> _refreshAnnouncementInboxStatus() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser?.uid ?? auth.appUser?.uid;
    final clubId = auth.appUser?.clubId;
    if (uid == null || clubId == null) {
      return;
    }

    try {
      final inboxStatus = await FirebaseService().getAnnouncementInboxStatus(
        actingUid: uid,
        clubId: clubId,
      );
      if (!mounted) return;
      setState(() {
        _announcementInboxStatus = inboxStatus;
      });
    } catch (error) {
      debugPrint(
        'MainNavigationScreen: failed to refresh announcement inbox: $error',
      );
    }
  }

  void _openMatchWorkspace({String? mode, bool resumeActiveMatch = false}) {
    final activeMatchController = context.read<ActiveMatchController>();
    final shouldResume =
        resumeActiveMatch && activeMatchController.hasActiveMatch;

    if (mode != null && !shouldResume) {
      matchSetupKey.currentState?.setGameMode(mode);
    }

    matchSetupKey.currentState?.refreshPlayers();
    setState(() {
      _currentIndex = 2;
    });

    if (shouldResume) {
      activeMatchController.expand();
    }
  }

  void _handleActiveMatchSaved(bool includedGuestPlayers) {
    context.read<ActiveMatchController>().clear();
    dashboardKey.currentState?.refreshDashboardData();
    matchSetupKey.currentState?.refreshPlayers();
    standingsKey.currentState?.refreshStandings();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MatchSavedScreen(includedGuestPlayers: includedGuestPlayers),
      ),
    );
  }

  void _handleActiveMatchReshuffle() {
    context.read<ActiveMatchController>().clear();
    matchSetupKey.currentState?.refreshPlayers();
    setState(() {
      _currentIndex = 2;
    });
  }

  void _handleActiveMatchCancelled() {
    context.read<ActiveMatchController>().clear();
    matchSetupKey.currentState?.refreshPlayers();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The ongoing match was canceled.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthProvider, bool>((auth) => auth.isAdmin);
    final activeMatchController = context.watch<ActiveMatchController>();
    final activeMatch = activeMatchController.activeMatch;
    final profileNavLabel = isAdmin ? 'Players' : 'My Profile';

    if (!isAdmin && _currentIndex == 2) {
      _currentIndex = 0;
    }

    final List<Widget> screens = [
      DashboardScreen(
        key: dashboardKey,
        announcementInboxStatus: _announcementInboxStatus,
        onNewMatchTap: (mode) {
          if (!isAdmin) return;
          _openMatchWorkspace(
            mode: mode,
            resumeActiveMatch: activeMatchController.hasActiveMatch,
          );
        },
        onAnnouncementsTap: () => _selectIndex(announcementsTabIndex),
      ),
      const PlayerManagementScreen(),
      MatchSetupScreen(key: matchSetupKey),
      StandingsScreen(key: standingsKey),
      AnnouncementsScreen(
        visitMarker: _announcementScreenVisitMarker,
        onInboxStateChanged: _refreshAnnouncementInboxStatus,
      ),
    ];

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final sidebar = Container(
      width: 250,
      color: AppColors.surfaceContainerHigh(
        context,
      ), // bg-surface-container-high
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'lib/assets/image/rally_club_logo.png',
                      height: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rally Club',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary(context),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Navigation Links
          _buildSidebarNavItem(Icons.dashboard, 'Dashboard', 0),
          const SizedBox(height: 8),
          _buildSidebarNavItem(Icons.groups, profileNavLabel, 1),
          if (isAdmin) ...[
            const SizedBox(height: 8),
            _buildSidebarNavItem(Icons.sports_tennis, 'Match', 2),
          ],
          const SizedBox(height: 8),
          _buildSidebarNavItem(Icons.leaderboard, 'Standings', 3),
          const SizedBox(height: 8),
          _buildSidebarNavItem(
            Icons.campaign,
            'Announcements',
            announcementsTabIndex,
            badgeCount: _announcementInboxStatus.unreadCount,
          ),

          const Spacer(),

          // Bottom Actions
          Divider(color: AppColors.divider(context)),
          const SizedBox(height: 16),

          // New Match Button
          if (isAdmin) ...[
            ElevatedButton.icon(
              onPressed: () {
                _openMatchWorkspace(
                  resumeActiveMatch: activeMatchController.hasActiveMatch,
                );
                if (mainScaffoldKey.currentState?.isDrawerOpen ?? false) {
                  mainScaffoldKey.currentState?.closeDrawer();
                }
              },
              icon: Icon(
                Icons.add_circle,
                color: AppColors.onPrimaryContainer(context),
              ),
              label: Text(
                'New Match',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.onPrimaryContainer(context),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer(
                  context,
                ), // primary-container
                minimumSize: const Size(double.infinity, 50),
                elevation: 4,
                shadowColor: AppColors.primary(context).withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),

          // Sign Out Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: InkWell(
              onTap: () {
                context.read<ActiveMatchController>().clear();
                Provider.of<AuthProvider>(context, listen: false).signOut();
              },
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    color: AppColors.textMuted(context),
                    size: 20,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Theme Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      AppColors.isDark(context)
                          ? Icons.dark_mode
                          : Icons.light_mode,
                      color: AppColors.textMain(context),
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      AppColors.isDark(context) ? 'Dark Mode' : 'Light Mode',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain(context),
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: AppColors.isDark(context),
                  onChanged: (bool isDark) {
                    themeNotifier.value = isDark
                        ? ThemeMode.dark
                        : ThemeMode.light;
                  },
                  activeThumbColor: AppColors.surface(context),
                  activeTrackColor: AppColors.primary(context),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: AppColors.border(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final content = isDesktop
        ? Row(
            children: [
              sidebar,
              Expanded(
                child: IndexedStack(index: _currentIndex, children: screens),
              ),
            ],
          )
        : IndexedStack(index: _currentIndex, children: screens);

    return Scaffold(
      key: mainScaffoldKey,
      drawer: isDesktop ? null : Drawer(child: sidebar),
      extendBody: !isDesktop,
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          content,
          if (activeMatch != null)
            Positioned.fill(
              child: Offstage(
                offstage: !activeMatchController.isExpanded,
                child: MatchResultScreen(
                  key: ValueKey(activeMatchController.sessionId),
                  match: activeMatch,
                  initialSelectedWinner: activeMatchController.selectedWinner,
                  initialHasExplicitWinner:
                      activeMatchController.hasExplicitWinner,
                  onMinimize: activeMatchController.minimize,
                  onReshuffle: _handleActiveMatchReshuffle,
                  onCancelMatch: _handleActiveMatchCancelled,
                  onSelectedWinnerChanged:
                      activeMatchController.setSelectedWinner,
                  onMatchSaved: _handleActiveMatchSaved,
                ),
              ),
            ),
          if (activeMatch != null && !activeMatchController.isExpanded)
            Positioned(
              left: isDesktop ? null : 16,
              right: 16,
              bottom: isDesktop ? 24 : 104,
              child: Align(
                alignment: isDesktop
                    ? Alignment.bottomRight
                    : Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ActiveMatchMinimizedCard(
                    match: activeMatch,
                    onResume: activeMatchController.expand,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 28, left: 24, right: 24),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.isDark(context)
                      ? const Color(0xFF1E2127)
                      : const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(40),
                  border: AppColors.isDark(context)
                      ? Border.all(
                          color: const Color(0xFFCAFD00).withValues(alpha: 0.4),
                          width: 1,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildBottomNavItem(
                        Icons.dashboard,
                        'Dashboard',
                        0,
                      ),
                    ),
                    Expanded(
                      child: _buildBottomNavItem(
                        Icons.groups,
                        profileNavLabel,
                        1,
                      ),
                    ),
                    if (isAdmin)
                      Expanded(
                        child: _buildBottomNavItem(
                          Icons.sports_tennis,
                          'Match',
                          2,
                        ),
                      ),
                    Expanded(
                      child: _buildBottomNavItem(
                        Icons.leaderboard,
                        'Standings',
                        3,
                      ),
                    ),
                    Expanded(
                      child: _buildBottomNavItem(
                        Icons.campaign,
                        'Announcements',
                        announcementsTabIndex,
                        badgeCount: _announcementInboxStatus.unreadCount,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSidebarNavItem(
    IconData icon,
    String label,
    int index, {
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        _selectIndex(index);
        if (mainScaffoldKey.currentState?.isDrawerOpen ?? false) {
          mainScaffoldKey.currentState?.closeDrawer();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.transparent : Colors.transparent,
          border: isSelected
              ? Border(
                  left: BorderSide(
                    color: AppColors.primaryContainer(context),
                    width: 4,
                  ),
                )
              : const Border(
                  left: BorderSide(color: Colors.transparent, width: 4),
                ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary(context)
                  : AppColors.textMuted(context),
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected
                    ? AppColors.primary(context)
                    : AppColors.textMuted(context),
              ),
            ),
            if (badgeCount > 0) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer(context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: TextStyle(
                    color: AppColors.onPrimaryContainer(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    IconData icon,
    String label,
    int index, {
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        _selectIndex(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 48,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
                size: 24,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: TextStyle(
                          color: AppColors.onPrimaryContainer(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppBrandTitle extends StatelessWidget {
  const AppBrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('lib/assets/image/rally_club_logo.png', height: 24),
        const SizedBox(width: 8),
        Text(
          'RALLY CLUB',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -1.0,
            color: AppColors.textMain(context),
          ),
        ),
      ],
    );
  }
}

class TopNavbarSyncStatusIndicator extends StatelessWidget {
  const TopNavbarSyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const SyncStatusBadge(compact: true);
  }
}

class ActiveMatchMinimizedCard extends StatelessWidget {
  const ActiveMatchMinimizedCard({
    super.key,
    required this.match,
    required this.onResume,
  });

  final GeneratedMatch match;
  final VoidCallback onResume;

  String _teamSummary(List<Player> team) {
    return team.map((player) => player.name.split(' ').first).join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onResume,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.sports_tennis,
                  color: AppColors.onPrimaryContainer(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active match in progress',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMain(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${match.gameMode.toUpperCase()} • ${match.matchLogic.toUpperCase()}',
                      style: TextStyle(
                        color: AppColors.textMuted(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_teamSummary(match.teamA)} vs ${_teamSummary(match.teamB)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSub(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: const Text('Resume'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer(context),
                  foregroundColor: AppColors.onPrimaryContainer(context),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final Function(String) onNewMatchTap;
  final VoidCallback onAnnouncementsTap;
  final AnnouncementInboxStatus announcementInboxStatus;

  const DashboardScreen({
    super.key,
    required this.onNewMatchTap,
    required this.onAnnouncementsTap,
    required this.announcementInboxStatus,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  Future<List<Player>> _playersFuture = Future.value(const <Player>[]);
  Future<List<MatchRecord>> _matchesFuture = Future.value(
    const <MatchRecord>[],
  );
  List<Player> _cachedPlayers = const <Player>[];
  List<MatchRecord> _cachedMatches = const <MatchRecord>[];
  DateTime? _statsLastUpdatedAt;
  String? _loadedClubId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final clubId = context.read<AuthProvider>().appUser?.clubId;
    if (clubId == null || clubId.isEmpty || _loadedClubId == clubId) {
      return;
    }

    _loadedClubId = clubId;
    refreshDashboardData();
  }

  void refreshDashboardData() {
    final auth = context.read<AuthProvider>();
    final clubId = auth.appUser?.clubId;
    if (clubId == null || clubId.isEmpty) {
      return;
    }

    setState(() {
      _playersFuture = FirebaseService().getPlayers(clubId: clubId).then((
        players,
      ) {
        _cachedPlayers = players;
        _statsLastUpdatedAt =
            _resolveLatestPlayerUpdate(players) ?? DateTime.now();
        return players;
      });
      _matchesFuture = FirebaseService().getMatches(clubId: clubId).then((
        matches,
      ) {
        _cachedMatches = matches;
        return matches;
      });
    });

    unawaited(_refreshDashboardFromRemote());
  }

  Future<void> _refreshDashboardFromRemote() async {
    final auth = context.read<AuthProvider>();
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
      return;
    }

    if (!mounted) {
      return;
    }

    final players = await FirebaseService().getPlayers(clubId: clubId);
    final matches = await FirebaseService().getMatches(clubId: clubId);
    if (!mounted) {
      return;
    }

    setState(() {
      _cachedPlayers = players;
      _cachedMatches = matches;
      _statsLastUpdatedAt =
          _resolveLatestPlayerUpdate(players) ?? DateTime.now();
      _playersFuture = Future.value(players);
      _matchesFuture = Future.value(matches);
    });
  }

  DateTime? _resolveLatestPlayerUpdate(List<Player> players) {
    DateTime? latestUpdate;

    for (final player in players) {
      final updatedAt = DateTime.tryParse(player.updatedAt ?? '');
      if (updatedAt == null) {
        continue;
      }
      if (latestUpdate == null || updatedAt.isAfter(latestUpdate)) {
        latestUpdate = updatedAt;
      }
    }

    return latestUpdate?.toLocal();
  }

  String _formatStatsLastUpdated(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Last updated when club data syncs';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inSeconds < 60) {
      return 'Last updated just now';
    }
    if (difference.inMinutes < 60) {
      return 'Last updated ${difference.inMinutes}m ago';
    }

    final today = DateTime(now.year, now.month, now.day);
    final updatedDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final timeLabel = _formatClockTime(dateTime);

    if (updatedDay == today) {
      return 'Last updated today at $timeLabel';
    }
    if (updatedDay == today.subtract(const Duration(days: 1))) {
      return 'Last updated yesterday at $timeLabel';
    }

    const monthNames = <String>[
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
    final month = monthNames[dateTime.month - 1];
    return 'Last updated $month ${dateTime.day} at $timeLabel';
  }

  String _formatClockTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthProvider, bool>((auth) => auth.isAdmin);

    return Scaffold(
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
        actions: const [TopNavbarSyncStatusIndicator()],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final r = Responsive(context);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: r.constrainWidth(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.pagePadding,
                      vertical: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Stats Bento - Main
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(r.cardPadding),
                          decoration: BoxDecoration(
                            color: AppColors.primary(context),
                            borderRadius: BorderRadius.circular(
                              r.cardRadius + 8,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CLUB STATUS',
                                style: TextStyle(
                                  color: AppColors.onPrimary(
                                    context,
                                  ).withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.0,
                                  fontSize: r.labelSize + 2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'THE COURT IS\nLIVE RIGHT NOW.',
                                style: TextStyle(
                                  color: AppColors.onPrimary(context),
                                  fontSize: r.titleSize - 4,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 24),
                              FutureBuilder<List<Player>>(
                                future: _playersFuture,
                                builder: (context, snapshot) {
                                  final players =
                                      snapshot.data ?? _cachedPlayers;
                                  int totalPlayers = 0;
                                  int availablePlayers = 0;

                                  if (players.isNotEmpty) {
                                    totalPlayers = players.length;
                                    availablePlayers = players
                                        .where((p) => p.isAvailable)
                                        .length;
                                  }

                                  return Row(
                                    children: [
                                      _buildStatItem(
                                        totalPlayers.toString(),
                                        'Total Players',
                                        AppColors.isDark(context)
                                            ? const Color(0xFF4A5E00)
                                            : const Color(0xFFCAFD00),
                                      ),
                                      const SizedBox(width: 32),
                                      _buildStatItem(
                                        availablePlayers.toString(),
                                        'Available',
                                        AppColors.onPrimary(context),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _formatStatsLastUpdated(_statsLastUpdatedAt),
                                style: TextStyle(
                                  color: AppColors.onPrimary(
                                    context,
                                  ).withValues(alpha: 0.76),
                                  fontWeight: FontWeight.w600,
                                  fontSize: r.labelSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        const AutomaticImageSlider(),
                        if (widget.announcementInboxStatus.unreadCount > 0) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(r.cardPadding),
                            decoration: BoxDecoration(
                              color: AppColors.surface(context),
                              borderRadius: BorderRadius.circular(r.cardRadius),
                              border: Border.all(
                                color: AppColors.primaryContainer(context),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NEW ANNOUNCEMENTS',
                                  style: TextStyle(
                                    fontSize: r.labelSize + 1,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.6,
                                    color: AppColors.primary(context),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${widget.announcementInboxStatus.unreadCount} announcement${widget.announcementInboxStatus.unreadCount == 1 ? '' : 's'} waiting for you.',
                                  style: TextStyle(
                                    fontSize: r.subtitleSize,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textMain(context),
                                  ),
                                ),
                                if (widget
                                        .announcementInboxStatus
                                        .latestUnreadAnnouncement !=
                                    null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    widget
                                        .announcementInboxStatus
                                        .latestUnreadAnnouncement!
                                        .title,
                                    style: TextStyle(
                                      fontSize: r.bodySize,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted(context),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: widget.onAnnouncementsTap,
                                    icon: const Icon(Icons.campaign),
                                    label: const Text('Open announcements'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: r.sectionSpacing),

                        // Quick Actions
                        if (isAdmin) ...[
                          Text(
                            'NEW MATCH',
                            style: TextStyle(
                              fontSize: r.labelSize + 2,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              color: AppColors.textMuted(context),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildQuickActionCard(
                            context,
                            'singles',
                            'Singles Match',
                            '1 vs 1 Competitive',
                            Icons.person,
                          ),
                          const SizedBox(height: 12),
                          _buildQuickActionCard(
                            context,
                            'doubles',
                            'Doubles Match',
                            '2 vs 2 Team Play',
                            Icons.groups,
                          ),
                          SizedBox(height: r.sectionSpacing),
                        ],

                        // Recent Match
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'RECENT MATCH',
                              style: TextStyle(
                                fontSize: r.subtitleSize,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: AppColors.textMain(context),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const MatchHistoryScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'VIEW ALL',
                                style: TextStyle(
                                  fontSize: r.labelSize,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: AppColors.primary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<List<MatchRecord>>(
                          future: _matchesFuture,
                          builder: (context, snapshot) {
                            final matches = snapshot.data ?? _cachedMatches;
                            if (matches.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface(context),
                                  borderRadius: BorderRadius.circular(
                                    r.cardRadius,
                                  ),
                                  border: Border.all(
                                    color: AppColors.border(context),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.history_toggle_off,
                                      size: 48,
                                      color: AppColors.textSub(
                                        context,
                                      ).withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Recent Matches',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textMain(context),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final match = matches.first;
                            final teamA = match.teamANames;
                            final teamB = match.teamBNames;
                            final winner = match.winningSide;

                            return Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(r.cardPadding),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(
                                  r.cardRadius,
                                ),
                                border: Border.all(
                                  color: AppColors.border(context),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer(
                                            context,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'FINAL',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.onPrimaryContainer(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        match.matchLogic.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textSub(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          teamA,
                                          style: TextStyle(
                                            fontSize: r.bodySize,
                                            fontWeight: winner == 'A'
                                                ? FontWeight.w900
                                                : FontWeight.w500,
                                            color: winner == 'A'
                                                ? AppColors.textMain(context)
                                                : AppColors.textSub(context),
                                          ),
                                        ),
                                      ),
                                      if (winner == 'A')
                                        Icon(
                                          Icons.emoji_events,
                                          size: 20,
                                          color: AppColors.primary(context),
                                        ),
                                    ],
                                  ),
                                  Divider(
                                    height: 24,
                                    color: AppColors.divider(context),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          teamB,
                                          style: TextStyle(
                                            fontSize: r.bodySize,
                                            fontWeight: winner == 'B'
                                                ? FontWeight.w900
                                                : FontWeight.w500,
                                            color: winner == 'B'
                                                ? AppColors.textMain(context)
                                                : AppColors.textSub(context),
                                          ),
                                        ),
                                      ),
                                      if (winner == 'B')
                                        Icon(
                                          Icons.emoji_events,
                                          size: 20,
                                          color: AppColors.primary(context),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        SizedBox(height: r.bottomNavPadding),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String number, String label, Color numColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: TextStyle(
            color: numColor,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 4),
        Builder(
          builder: (context) {
            return Text(
              label.toUpperCase(),
              style: TextStyle(
                color: AppColors.onPrimary(context).withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String mode,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return InkWell(
      onTap: () => widget.onNewMatchTap(mode),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border(context), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primary(context), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: AppColors.textMain(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSub(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: AppColors.textMuted(context)),
          ],
        ),
      ),
    );
  }
}

class AutomaticImageSlider extends StatefulWidget {
  const AutomaticImageSlider({super.key});

  @override
  State<AutomaticImageSlider> createState() => _AutomaticImageSliderState();
}

class _AutomaticImageSliderState extends State<AutomaticImageSlider> {
  late PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;

  final List<String> _images = [
    'lib/assets/image/1.jpg',
    'lib/assets/image/2.jpg',
    'lib/assets/image/3.jpg',
    'lib/assets/image/4.jpg',
    'lib/assets/image/5.jpg',
    'lib/assets/image/6.jpg',
    'lib/assets/image/7.jpg',
  ];

  @override
  void initState() {
    super.initState();
    // Start at a high number divisible by array length to simulate infinite backwards scroll too
    _currentPage = _images.length * 1000;
    _pageController = PageController(initialPage: _currentPage);

    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_pageController.hasClients) {
        _currentPage++;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(
            milliseconds: 1000,
          ), // Smooth, slow glide duration
          curve: Curves.easeIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int realIndex = _currentPage % _images.length;

    return Container(
      width: double.infinity,
      height: 200, // Fixed height for the hero slider
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh(
          context,
        ), // surface-container-high
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            // Using null for itemCount creates an infinite scrolling PageView
            itemCount: null,
            itemBuilder: (context, index) {
              final imageIndex = index % _images.length;
              return Image.asset(
                _images[imageIndex],
                fit: BoxFit.cover,
                width: double.infinity,
              );
            },
          ),

          // Sliding Index Number
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Stack(
                      children: _images.asMap().entries.map((entry) {
                        final isActive = realIndex == entry.key;
                        return AnimatedPositioned(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOutCubic,
                          top: isActive ? 0 : 30, // Base position
                          bottom: isActive ? 0 : -30,
                          left: 0,
                          right: 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 500),
                            opacity: isActive ? 1.0 : 0.0,
                            child: Center(
                              child: Text(
                                (entry.key + 1).toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const VerticalDivider(
                    color: Colors.white24,
                    width: 16,
                    indent: 8,
                    endIndent: 8,
                  ),
                  Text(
                    _images.length.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
