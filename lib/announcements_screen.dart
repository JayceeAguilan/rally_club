import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'add_announcement_sheet.dart';
import 'announcement_detail_sheet.dart';
import 'auth_provider.dart';
import 'firebase_service.dart';
import 'main.dart';
import 'models/announcement.dart';
import 'models/announcement_inbox_status.dart';
import 'responsive.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({
    super.key,
    this.loadAnnouncements,
    this.loadInboxStatus,
    this.markAnnouncementsSeen,
    this.onInboxStateChanged,
    this.visitMarker = 0,
  });

  final Future<List<Announcement>> Function(String clubId)? loadAnnouncements;
  final Future<AnnouncementInboxStatus> Function(String uid, String clubId)?
  loadInboxStatus;
  final Future<void> Function(String uid, String clubId)? markAnnouncementsSeen;
  final VoidCallback? onInboxStateChanged;
  final int visitMarker;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late Future<List<Announcement>> _announcementsFuture;
  final TextEditingController _searchController = TextEditingController();
  List<Announcement>? _cachedAnnouncements;
  AnnouncementInboxStatus _inboxStatus = const AnnouncementInboxStatus();
  String _searchQuery = '';
  bool _isLoadingInboxStatus = true;
  bool _hasQueuedSeenSync = false;

  @override
  void initState() {
    super.initState();
    _refreshAnnouncements();
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

  @override
  void didUpdateWidget(covariant AnnouncementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visitMarker != widget.visitMarker) {
      _refreshAnnouncements();
    }
  }

  void _refreshAnnouncements() {
    final auth = context.read<AuthProvider>();
    final loadAnnouncements =
        widget.loadAnnouncements ??
        ((clubId) => FirebaseService().getAnnouncements(clubId: clubId));
    setState(() {
      _announcementsFuture = loadAnnouncements(auth.appUser!.clubId!);
      _isLoadingInboxStatus = true;
      _hasQueuedSeenSync = false;
    });
    _refreshInboxStatus();
  }

  Future<void> _refreshInboxStatus() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser?.uid ?? auth.appUser?.uid;
    final clubId = auth.appUser?.clubId;
    if (uid == null || clubId == null) {
      if (mounted) {
        setState(() => _isLoadingInboxStatus = false);
      }
      return;
    }

    final loadInboxStatus =
        widget.loadInboxStatus ??
        ((uid, clubId) => FirebaseService().getAnnouncementInboxStatus(
          actingUid: uid,
          clubId: clubId,
        ));

    try {
      final inboxStatus = await loadInboxStatus(uid, clubId);
      if (!mounted) return;

      setState(() {
        _inboxStatus = inboxStatus;
        _isLoadingInboxStatus = false;
      });

      widget.onInboxStateChanged?.call();

      if (!_hasQueuedSeenSync && inboxStatus.unreadCount > 0) {
        _hasQueuedSeenSync = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final markAnnouncementsSeen =
              widget.markAnnouncementsSeen ??
              ((uid, clubId) => FirebaseService().markAnnouncementsSeen(
                actingUid: uid,
                clubId: clubId,
              ));
          try {
            await markAnnouncementsSeen(uid, clubId);
            widget.onInboxStateChanged?.call();
          } catch (error) {
            debugPrint(
              'AnnouncementsScreen: failed to mark announcements seen: $error',
            );
          }
        });
      }
    } catch (error) {
      debugPrint('AnnouncementsScreen: failed to load inbox status: $error');
      if (!mounted) return;
      setState(() => _isLoadingInboxStatus = false);
    }
  }

  Future<void> _openAnnouncementComposer() async {
    final result = await showAddAnnouncementSheet(context);
    if (result == true) {
      _refreshAnnouncements();
      widget.onInboxStateChanged?.call();
    }
  }

  String _formatSchedule(DateTime? dateTime) {
    if (dateTime == null) return 'Schedule unavailable';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    final weekday = weekdays[dateTime.weekday - 1];
    final month = months[dateTime.month - 1];
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$weekday, $month ${dateTime.day} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;

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
        actions: [
          IconButton(
            onPressed: _refreshAnnouncements,
            icon: Icon(Icons.refresh, color: AppColors.primary(context)),
            tooltip: 'Refresh announcements',
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openAnnouncementComposer,
              backgroundColor: AppColors.primaryContainer(context),
              foregroundColor: AppColors.onPrimaryContainer(context),
              icon: const Icon(Icons.campaign),
              label: const Text(
                'Post Announcement',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : null,
      body: FutureBuilder<List<Announcement>>(
        future: _announcementsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _cachedAnnouncements = snapshot.data;
          }

          final announcements = _cachedAnnouncements;

          if (announcements == null) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primary(context),
              ),
            );
          }

          final filteredAnnouncements = announcements.where((announcement) {
            if (_searchQuery.isEmpty) return true;
            final haystack = [
              announcement.title,
              announcement.location,
              announcement.createdByName,
            ].join(' ').toLowerCase();
            return haystack.contains(_searchQuery);
          }).toList();

          filteredAnnouncements.sort((a, b) {
            final aCreatedAt =
                a.createdDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bCreatedAt =
                b.createdDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bCreatedAt.compareTo(aCreatedAt);
          });

          return LayoutBuilder(
            builder: (context, constraints) {
              final r = Responsive(context);
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: r.constrainWidth(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.pagePadding,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PLAY ANNOUNCEMENTS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textMuted(context),
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'CLUB UPDATES',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textMain(context),
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 24),
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
                                  hintText:
                                      'Search by title, location, or organizer...',
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
                                          onPressed: _searchController.clear,
                                          icon: Icon(
                                            Icons.close,
                                            color: AppColors.textMuted(context),
                                          ),
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            if (!_isLoadingInboxStatus &&
                                _inboxStatus.unreadCount > 0) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer(context),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_inboxStatus.unreadCount} new announcement${_inboxStatus.unreadCount == 1 ? '' : 's'} since your last visit.',
                                      style: TextStyle(
                                        color: AppColors.onPrimaryContainer(
                                          context,
                                        ),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (_inboxStatus.latestUnreadAnnouncement !=
                                        null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        _inboxStatus
                                            .latestUnreadAnnouncement!
                                            .title,
                                        style: TextStyle(
                                          color: AppColors.onPrimaryContainer(
                                            context,
                                          ),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (snapshot.hasError && announcements.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Could not load announcements.',
                                style: TextStyle(
                                  color: AppColors.textMain(context),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _refreshAnnouncements,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (filteredAnnouncements.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'No announcements match that search yet.'
                                : isAdmin
                                ? 'No announcements yet. Post the next play session for your members.'
                                : 'No announcements yet. Check back for the next scheduled play.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: r.constrainWidth(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            r.pagePadding,
                            0,
                            r.pagePadding,
                            r.bottomNavPadding,
                          ),
                          child: Column(
                            children: filteredAnnouncements.map((announcement) {
                              final scheduledAt =
                                  announcement.scheduledDateTime;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: InkWell(
                                  onTap: () {
                                    showAnnouncementDetailSheet(
                                      context,
                                      announcement: announcement,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(28),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface(context),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: AppColors.divider(context),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          announcement.title,
                                          style: TextStyle(
                                            color: AppColors.textMain(context),
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _InfoRow(
                                          icon: Icons.schedule,
                                          text: _formatSchedule(scheduledAt),
                                        ),
                                        const SizedBox(height: 10),
                                        _InfoRow(
                                          icon: Icons.location_on,
                                          text: announcement.location,
                                        ),
                                        const SizedBox(height: 18),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Posted by ${announcement.createdByName}',
                                                style: TextStyle(
                                                  color: AppColors.textMuted(
                                                    context,
                                                  ),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.forum,
                                                  size: 16,
                                                  color: AppColors.primary(
                                                    context,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Open thread',
                                                  style: TextStyle(
                                                    color: AppColors.primary(
                                                      context,
                                                    ),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary(context), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textMain(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
