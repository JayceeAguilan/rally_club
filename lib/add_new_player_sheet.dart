import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'firebase_service.dart';
import 'models/player.dart';
import 'auth_provider.dart';

void showAddNewPlayerSheet(BuildContext context, {Player? player}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddNewPlayerSheet(playerToEdit: player),
  );
}

class AddNewPlayerSheet extends StatefulWidget {
  final Player? playerToEdit;

  const AddNewPlayerSheet({super.key, this.playerToEdit});

  @override
  State<AddNewPlayerSheet> createState() => _AddNewPlayerSheetState();
}

class _AddNewPlayerSheetState extends State<AddNewPlayerSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedSkill = 'Int';
  bool _isAvailable = true;
  String? _profileImageBase64;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 50,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _profileImageBase64 = base64Encode(bytes);
        });
      }
    } catch (_) {
      // Ignored
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.playerToEdit != null) {
      _nameController.text = widget.playerToEdit!.name;
      _notesController.text = widget.playerToEdit!.notes;
      _selectedGender = widget.playerToEdit!.gender;
      _selectedSkill = widget.playerToEdit!.skillLevel;
      _isAvailable = widget.playerToEdit!.isAvailable;
      _profileImageBase64 = widget.playerToEdit!.profileImageBase64;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
            decoration: BoxDecoration(
              border: const Border(
                top: BorderSide(color: Color(0xFFCAFD00), width: 4),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playerToEdit != null ? 'EDIT ENTRY' : 'NEW ENTRY',
                      style: TextStyle(
                        color: AppColors.primary(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.playerToEdit != null
                          ? 'Edit Player'
                          : 'Add New Player',
                      style: TextStyle(
                        color: AppColors.textMain(context),
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ],
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

          // Scrollable Form Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(32, 0, 32, 32 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile ID / Avatar
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.divider(context),
                              shape: BoxShape.circle,
                              image: _profileImageBase64 != null
                                  ? DecorationImage(
                                      image: MemoryImage(
                                        base64Decode(_profileImageBase64!),
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              border: Border.all(
                                color: const Color(0xFFCAFD00),
                                width: 3,
                              ),
                            ),
                            child: _profileImageBase64 == null
                                ? Icon(
                                    Icons.add_a_photo,
                                    size: 32,
                                    color: AppColors.textMuted(context),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary(context),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit,
                                size: 16,
                                color: AppColors.onPrimary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Full Name
                  _buildFormLabel('FULL NAME'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain(context),
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.divider(context),
                      hintText: 'e.g. Jordan Rivers',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted(
                          context,
                        ).withValues(alpha: 0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Gender and Skill level
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gender
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormLabel('GENDER *'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.divider(context),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  _buildSegmentButton('GENDER', 'Male'),
                                  _buildSegmentButton('GENDER', 'Female'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Skill
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormLabel('SKILL LEVEL'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.divider(context),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  _buildSegmentButton('SKILL', 'Beg'),
                                  _buildSegmentButton('SKILL', 'Int'),
                                  _buildSegmentButton('SKILL', 'Adv'),
                                  _buildSegmentButton('SKILL', 'Pro'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Availability Toggle
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh(context),
                      border: Border.all(
                        color: const Color(0xFFCAFD00).withValues(alpha: 0.2),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCAFD00),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.bolt,
                                  color: AppColors.primary(context),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Immediate Availability',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.textMain(context),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'ACTIVE FOR COURT MATCHMAKING',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textMuted(context),
                                        letterSpacing: 1.5,
                                      ),
                                      overflow: TextOverflow.visible,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isAvailable,
                          onChanged: (val) =>
                              setState(() => _isAvailable = val),
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.primary(context),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: AppColors.border(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer Actions
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: AppColors.divider(context)),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.surface(context),
                      foregroundColor: AppColors.textMuted(context),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_nameController.text.trim().isEmpty) return;

                      final auth = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      final isAdmin = auth.isAdmin;
                      final isOwnProfile =
                          widget.playerToEdit?.id == auth.appUser?.playerId;

                      if (widget.playerToEdit == null && !isAdmin) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Only admins can add new players.'),
                            ),
                          );
                        }
                        return;
                      }

                      if (widget.playerToEdit != null &&
                          !isAdmin &&
                          !isOwnProfile) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'You can only edit your own profile.',
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      final player = widget.playerToEdit == null
                          ? Player(
                              id: widget.playerToEdit?.id,
                              name: _nameController.text.trim(),
                              gender: _selectedGender,
                              skillLevel: _selectedSkill,
                              isAvailable: _isAvailable,
                              notes: _notesController.text.trim(),
                              profileImageBase64: _profileImageBase64,
                            )
                          : widget.playerToEdit!.copyWith(
                              name: _nameController.text.trim(),
                              gender: _selectedGender,
                              skillLevel: _selectedSkill,
                              isAvailable: _isAvailable,
                              notes: _notesController.text.trim(),
                              profileImageBase64: _profileImageBase64,
                            );

                      if (widget.playerToEdit == null) {
                        await FirebaseService().insertPlayer(
                          player,
                          clubId: auth.appUser!.clubId!,
                          ownerUid: auth.firebaseUser!.uid,
                          actingUid: auth.firebaseUser!.uid,
                        );
                      } else {
                        await FirebaseService().updatePlayer(
                          player,
                          actingUid: auth.firebaseUser!.uid,
                          clubId: auth.appUser!.clubId!,
                        );
                      }

                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFFCAFD00),
                      foregroundColor: const Color(0xFF4A5E00),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      widget.playerToEdit != null
                          ? 'UPDATE PLAYER'
                          : 'SAVE PLAYER',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: AppColors.textMuted(context),
        letterSpacing: 2.0,
      ),
    );
  }

  Widget _buildSegmentButton(String group, String title) {
    final bool isSelected =
        (group == 'GENDER' && _selectedGender == title) ||
        (group == 'SKILL' && _selectedSkill == title);
    final isDark = AppColors.isDark(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (group == 'GENDER') _selectedGender = title;
            if (group == 'SKILL') _selectedSkill = title;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: const Color(0xFFCAFD00), width: 2)
                : Border.all(color: Colors.transparent, width: 2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.12,
                      ),
                      blurRadius: 4,
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              color: isSelected
                  ? AppColors.primary(context)
                  : AppColors.textMuted(context),
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}
