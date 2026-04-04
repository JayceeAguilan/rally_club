import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';
import 'firebase_service.dart';
import 'main.dart';
import 'models/announcement.dart';
import 'models/announcement_comment.dart';

Future<void> showAnnouncementDetailSheet(
  BuildContext context, {
  required Announcement announcement,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AnnouncementDetailSheet(announcement: announcement),
  );
}

class AnnouncementDetailSheet extends StatefulWidget {
  const AnnouncementDetailSheet({super.key, required this.announcement});

  final Announcement announcement;

  @override
  State<AnnouncementDetailSheet> createState() =>
      _AnnouncementDetailSheetState();
}

class _AnnouncementDetailSheetState extends State<AnnouncementDetailSheet> {
  late Future<List<AnnouncementComment>> _commentsFuture;
  final TextEditingController _commentController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _refreshComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _refreshComments() {
    final clubId =
        widget.announcement.clubId ??
        context.read<AuthProvider>().appUser!.clubId!;
    setState(() {
      _commentsFuture = FirebaseService().getAnnouncementComments(
        announcementId: widget.announcement.id!,
        clubId: clubId,
      );
    });
  }

  Widget _buildThreadFallback({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    setState(() => _isSaving = true);

    try {
      await FirebaseService().addAnnouncementComment(
        announcementId: widget.announcement.id!,
        text: text,
        actingUid: auth.firebaseUser!.uid,
      );
      _commentController.clear();
      _refreshComments();
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post your comment.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _editComment(AnnouncementComment comment) async {
    final auth = context.read<AuthProvider>();
    final controller = TextEditingController(text: comment.text);
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Text(
          'Edit Comment',
          style: TextStyle(color: AppColors.textMain(context)),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Update your comment'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: TextStyle(color: AppColors.textMuted(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(
              'SAVE',
              style: TextStyle(color: AppColors.primary(context)),
            ),
          ),
        ],
      ),
    );

    if (updated == null || updated.isEmpty || updated == comment.text) {
      return;
    }

    try {
      await FirebaseService().updateAnnouncementComment(
        commentId: comment.id!,
        text: updated,
        actingUid: auth.firebaseUser!.uid,
      );
      _refreshComments();
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the comment.')),
      );
    }
  }

  Future<void> _deleteComment(AnnouncementComment comment) async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Text(
          'Delete Comment',
          style: TextStyle(color: AppColors.textMain(context)),
        ),
        content: Text(
          'Remove this response from the announcement thread?',
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
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseService().deleteAnnouncementComment(
        commentId: comment.id!,
        actingUid: auth.firebaseUser!.uid,
      );
      _refreshComments();
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the comment.')),
      );
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

  String _formatCommentTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';
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
    final month = months[dateTime.month - 1];
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$month ${dateTime.day}, ${dateTime.year} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUid = auth.firebaseUser?.uid;
    final announcement = widget.announcement;
    final scheduledAt = announcement.scheduledDateTime;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      margin: EdgeInsets.only(top: kToolbarHeight),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(32, 32, 24, 24),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFCAFD00), width: 4),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PLAY ANNOUNCEMENT',
                        style: TextStyle(
                          color: AppColors.primary(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        announcement.title,
                        style: TextStyle(
                          color: AppColors.textMain(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                          height: 1.05,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.textMuted(context)),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerHigh(context),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh(context),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: AppColors.primary(context)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatSchedule(scheduledAt),
                          style: TextStyle(
                            color: AppColors.textMain(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AppColors.primary(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          announcement.location,
                          style: TextStyle(
                            color: AppColors.textMain(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Posted by ${announcement.createdByName}',
                    style: TextStyle(
                      color: AppColors.textMuted(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Member Responses',
                style: TextStyle(
                  color: AppColors.textMain(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<AnnouncementComment>>(
              future: _commentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary(context),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _buildThreadFallback(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load the response thread.',
                          style: TextStyle(
                            color: AppColors.textMain(context),
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _refreshComments,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final comments = snapshot.data ?? const <AnnouncementComment>[];
                if (comments.isEmpty) {
                  return _buildThreadFallback(
                    child: Text(
                      'No one has responded yet. Be the first to comment.',
                      style: TextStyle(
                        color: AppColors.textMuted(context),
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                  itemCount: comments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final isOwnComment = comment.authorUid == currentUid;
                    final canDelete = isOwnComment || auth.isAdmin;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isOwnComment
                            ? AppColors.primaryContainer(
                                context,
                              ).withValues(alpha: 0.18)
                            : AppColors.surfaceContainerHigh(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isOwnComment
                              ? AppColors.primary(
                                  context,
                                ).withValues(alpha: 0.3)
                              : AppColors.divider(context),
                        ),
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
                                      comment.authorName,
                                      style: TextStyle(
                                        color: AppColors.textMain(context),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatCommentTimestamp(
                                        comment.createdDateTime,
                                      ),
                                      style: TextStyle(
                                        color: AppColors.textMuted(context),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isOwnComment || canDelete)
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_horiz,
                                    color: AppColors.textMuted(context),
                                  ),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editComment(comment);
                                    }
                                    if (value == 'delete') {
                                      _deleteComment(comment);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (isOwnComment)
                                      const PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                    if (canDelete)
                                      const PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            comment.text,
                            style: TextStyle(
                              color: AppColors.textMain(context),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
            decoration: BoxDecoration(
              color: AppColors.divider(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    enabled: !_isSaving,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Write your response...',
                      filled: true,
                      fillColor: AppColors.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submitComment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer(context),
                    foregroundColor: AppColors.onPrimaryContainer(context),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimaryContainer(context),
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
