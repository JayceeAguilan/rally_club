import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'add_new_player_sheet.dart';
import 'firebase_service.dart';
import 'models/player.dart';
import 'player_match_history_screen.dart';
import 'responsive.dart';
import 'auth_provider.dart';

class PlayerManagementScreen extends StatefulWidget {
  const PlayerManagementScreen({super.key});

  @override
  State<PlayerManagementScreen> createState() => _PlayerManagementScreenState();
}

class _PlayerManagementScreenState extends State<PlayerManagementScreen> {
  late Future<List<Player>> _playersFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSkill = 'All';
  String _selectedStatus = 'All';
  String _selectedGender = 'All';
  Map<String, Map<String, int>> _standingsMap = {};

  @override
  void initState() {
    super.initState();
    _refreshPlayers();
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

  void _refreshPlayers() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _playersFuture = FirebaseService().getPlayers(
        clubId: auth.appUser!.clubId!,
      );
    });
    _loadStandings();
  }

  Future<void> _loadStandings() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final standings = await FirebaseService().getPlayerStandings(
      clubId: auth.appUser!.clubId!,
    );
    final map = <String, Map<String, int>>{};
    for (final s in standings) {
      final player = s['player'] as Player;
      if (player.id != null) {
        map[player.id!] = {
          'wins': s['wins'] as int,
          'losses': s['losses'] as int,
        };
      }
    }
    if (mounted) {
      setState(() {
        _standingsMap = map;
      });
    }
  }

  Future<void> _openAddPlayerSheet({Player? player}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = auth.isAdmin;
    final canEditPlayer =
        player?.isOwnedByUser(
          linkedPlayerId: auth.appUser?.playerId,
          userUid: auth.firebaseUser?.uid,
        ) ??
        false;

    if (player == null && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can add new players.')),
      );
      return;
    }

    if (player != null && !isAdmin && !canEditPlayer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only edit your own profile.')),
      );
      return;
    }

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddNewPlayerSheet(playerToEdit: player),
    );
    if (result == true) {
      _refreshPlayers();
    }
  }

  Future<void> _confirmDelete(Player player) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can remove players.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Text(
          'Remove Athlete',
          style: TextStyle(color: AppColors.textMain(context)),
        ),
        content: Text(
          'Are you sure you want to permanently delete ${player.name}?',
          style: TextStyle(color: AppColors.textSub(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: TextStyle(color: AppColors.textMuted(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (confirm == true) {
      await FirebaseService().deletePlayer(
        player.id!,
        actingUid: auth.firebaseUser!.uid,
        clubId: auth.appUser!.clubId!,
      );
      _refreshPlayers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final currentPlayerId = auth.appUser?.playerId;
    final currentUid = auth.firebaseUser?.uid;
    final screenTitle = isAdmin ? 'Player Management' : 'My Profile';
    final emptyStateText = isAdmin
        ? 'No local players found. Create a new entry.'
        : 'Your player profile is not available yet.';

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
                        // Editorial Header Section
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -30,
                              left: -10,
                              child: Text(
                                '01',
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
                                const SizedBox(height: 16),
                                Text(
                                  screenTitle,
                                  style: TextStyle(
                                    color: AppColors.textMain(context),
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        if (isAdmin) ...[
                          // Filter & Search Section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh(context),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Search Input
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface(context),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    style: TextStyle(
                                      color: AppColors.textMain(context),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Find a teammate...',
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
                                                color: AppColors.textMuted(
                                                  context,
                                                ),
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _searchController.clear(),
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // DUPR band chips
                                Row(
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
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _buildActionChip(
                                              'All',
                                              _selectedSkill == 'All',
                                              () => setState(
                                                () => _selectedSkill = 'All',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildActionChip(
                                              'Unrated',
                                              _selectedSkill == 'Unrated',
                                              () => setState(
                                                () => _selectedSkill = 'Unrated',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildActionChip(
                                              'Beginner',
                                              _selectedSkill == 'Beginner',
                                              () => setState(
                                                () =>
                                                    _selectedSkill = 'Beginner',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildActionChip(
                                              'Intermediate',
                                              _selectedSkill == 'Intermediate',
                                              () => setState(
                                                () => _selectedSkill =
                                                    'Intermediate',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildActionChip(
                                              'Advanced',
                                              _selectedSkill == 'Advanced',
                                              () => setState(
                                                () =>
                                                    _selectedSkill = 'Advanced',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Status Chips
                                Row(
                                  children: [
                                    Text(
                                      'STATUS:',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: AppColors.textMuted(context),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _buildActionChip(
                                              'All',
                                              _selectedStatus == 'All',
                                              () => setState(
                                                () => _selectedStatus = 'All',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildActionChip(
                                              'Available Now',
                                              _selectedStatus ==
                                                  'Available Now',
                                              () => setState(
                                                () => _selectedStatus =
                                                    'Available Now',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildActionChip(
                                              'Away',
                                              _selectedStatus == 'Away',
                                              () => setState(
                                                () => _selectedStatus = 'Away',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Gender Chips
                                Row(
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
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _buildActionChip(
                                              'All',
                                              _selectedGender == 'All',
                                              () => setState(
                                                () => _selectedGender = 'All',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildActionChip(
                                              'Male',
                                              _selectedGender == 'Male',
                                              () => setState(
                                                () => _selectedGender = 'Male',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildActionChip(
                                              'Female',
                                              _selectedGender == 'Female',
                                              () => setState(
                                                () =>
                                                    _selectedGender = 'Female',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ] else ...[],

                        // Player List from Local Database
                        FutureBuilder<List<Player>>(
                          future: _playersFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 32.0,
                                  ),
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary(context),
                                  ),
                                ),
                              );
                            }

                            final allPlayers = snapshot.data ?? [];

                            final players = isAdmin
                                ? allPlayers.where((p) {
                                    final matchesSearch =
                                        _searchQuery.isEmpty ||
                                        p.name.toLowerCase().contains(
                                          _searchQuery,
                                        ) ||
                                        p.gender.toLowerCase().contains(
                                          _searchQuery,
                                        ) ||
                                        p.displayDuprLabel
                                            .toLowerCase()
                                            .contains(_searchQuery) ||
                                        p.displayDuprRating.contains(
                                          _searchQuery,
                                        ) ||
                                        p.displaySkillLabel
                                            .toLowerCase()
                                            .contains(_searchQuery);
                                    bool matchesSkill =
                                        _selectedSkill == 'All' ||
                                        p.matchesSkillFilter(_selectedSkill);
                                    bool matchesStatus = true;
                                    if (_selectedStatus == 'Available Now') {
                                      matchesStatus = p.isAvailable;
                                    } else if (_selectedStatus == 'Away') {
                                      matchesStatus = !p.isAvailable;
                                    }
                                    bool matchesGender =
                                        _selectedGender == 'All' ||
                                        p.gender == _selectedGender;
                                    return matchesSearch &&
                                        matchesSkill &&
                                        matchesStatus &&
                                        matchesGender;
                                  }).toList()
                                : allPlayers
                                      .where(
                                        (p) => p.isOwnedByUser(
                                          linkedPlayerId: currentPlayerId,
                                          userUid: currentUid,
                                        ),
                                      )
                                      .toList();

                            if (players.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 32.0,
                                  ),
                                  child: Text(
                                    emptyStateText,
                                    style: TextStyle(
                                      color: AppColors.textMuted(context),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Column(
                              children: players.map((player) {
                                final wins =
                                    _standingsMap[player.id]?['wins'] ?? 0;
                                final losses =
                                    _standingsMap[player.id]?['losses'] ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: _buildPlayerCard(
                                    context: context,
                                    player: player,
                                    wins: wins,
                                    losses: losses,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Empty State Add New Entry
                        if (isAdmin)
                          InkWell(
                            onTap: _openAddPlayerSheet,
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.border(
                                    context,
                                  ).withValues(alpha: 0.5),
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerHigh(
                                        context,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person_add,
                                      color: AppColors.textMuted(context),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'New Entry',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMuted(context),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Expand the court roster',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSub(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        SizedBox(height: r.bottomNavPadding),
                      ],
                    ), // Column
                  ), // Padding
                ), // constrainWidth
              ), // SliverToBoxAdapter
            ], // slivers
          ); // CustomScrollView
        }, // LayoutBuilder builder
      ), // LayoutBuilder
      floatingActionButton: isAdmin
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: FloatingActionButton(
                onPressed: _openAddPlayerSheet,
                backgroundColor: const Color(0xFFCAFD00),
                child: const Icon(Icons.add, color: Color(0xFF4A5E00)),
              ),
            )
          : null,
    );
  }

  Widget _buildActionChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCAFD00)
              : AppColors.border(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? const Color(0xFF4A5E00)
                : AppColors.textMain(context),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard({
    required BuildContext context,
    required Player player,
    required int wins,
    required int losses,
  }) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = auth.isAdmin;
    final isOwnProfile = player.isOwnedByUser(
      linkedPlayerId: auth.appUser?.playerId,
      userUid: auth.firebaseUser?.uid,
    );
    final canEditPlayer = isAdmin || isOwnProfile;
    final canDeletePlayer = isAdmin;
    final canToggleAvailability = isAdmin || isOwnProfile;

    IconData icon = player.gender == 'Female'
        ? Icons.female
        : (player.gender == 'Male' ? Icons.male : Icons.person);
    Color imageColor = AppColors.border(context);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerMatchHistoryScreen(player: player),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: imageColor,
                            borderRadius: BorderRadius.circular(16),
                            image: player.profileImageBase64 != null
                                ? DecorationImage(
                                    image: MemoryImage(
                                      base64Decode(player.profileImageBase64!),
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: player.profileImageBase64 == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 32,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCAFD00),
                              border: Border.all(
                                color: AppColors.surface(context),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              icon,
                              size: 12,
                              color: const Color(0xFF4A5E00),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textMain(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh(context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                player.gender.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textSub(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${player.displaySkillLabel.toUpperCase()} • ${player.displayDuprRating}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  children: [
                    if (canEditPlayer)
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          color: AppColors.textMuted(context),
                          size: 20,
                        ),
                        onPressed: () => _openAddPlayerSheet(player: player),
                      ),
                    if (canDeletePlayer)
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Color(0xFFE57373),
                          size: 20,
                        ),
                        onPressed: () => _confirmDelete(player),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEASON RECORD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                      Text(
                        '$wins - $losses',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary(context),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'AVAILABILITY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: canToggleAvailability
                            ? () async {
                                await FirebaseService()
                                    .togglePlayerAvailability(
                                      player.id!,
                                      !player.isAvailable,
                                      actingUid: auth.firebaseUser!.uid,
                                      clubId: auth.appUser!.clubId!,
                                    );
                                _refreshPlayers();
                              }
                            : null,
                        child: Container(
                          width: 40,
                          height: 20,
                          decoration: BoxDecoration(
                            color: player.isAvailable
                                ? AppColors.primary(context)
                                : AppColors.border(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 4,
                                left: player.isAvailable ? null : 4,
                                right: player.isAvailable ? 4 : null,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!canToggleAvailability)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'ADMIN / OWNER',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppColors.textMuted(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCAFD00).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 16,
                    color: AppColors.primary(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOwnProfile ? 'MY HISTORY' : 'VIEW HISTORY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary(context),
                      letterSpacing: 1.0,
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
