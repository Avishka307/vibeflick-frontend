import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MoreOptionsBottomSheet extends StatefulWidget {
  final bool currentDuet;
  final bool currentSave;
  final bool currentComment;
  final bool currentSaveDevice;
  // ✅ FIX: postId add කළා — allowComment Firestore update සඳහා
  final String? postId;
  final Function(bool duet, bool save, bool comment, bool saveDevice) onSettingsChanged;

  const MoreOptionsBottomSheet({
    super.key,
    this.currentDuet = true,
    this.currentSave = true,
    this.currentComment = true,
    this.currentSaveDevice = false,
    this.postId,
    required this.onSettingsChanged,
  });

  @override
  State<MoreOptionsBottomSheet> createState() => _MoreOptionsBottomSheetState();

  static void show(
      BuildContext context, {
        bool currentDuet = true,
        bool currentSave = true,
        bool currentComment = true,
        bool currentSaveDevice = false,
        String? postId,
        required Function(bool duet, bool save, bool comment, bool saveDevice) onSettingsChanged,
      }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MoreOptionsBottomSheet(
        currentDuet: currentDuet,
        currentSave: currentSave,
        currentComment: currentComment,
        currentSaveDevice: currentSaveDevice,
        postId: postId,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }
}

class _MoreOptionsBottomSheetState extends State<MoreOptionsBottomSheet> {
  late bool duetEnabled;
  late bool saveEnabled;
  late bool commentEnabled;
  late bool saveDeviceEnabled;

  bool _isUpdating = false;

  // Primary color - Blue
  static const Color primaryColor = Color(0xFF0095F6);

  @override
  void initState() {
    super.initState();
    duetEnabled = widget.currentDuet;
    saveEnabled = widget.currentSave;
    commentEnabled = widget.currentComment;
    saveDeviceEnabled = widget.currentSaveDevice;
  }

  void _notifyChange() {
    widget.onSettingsChanged(
      duetEnabled,
      saveEnabled,
      commentEnabled,
      saveDeviceEnabled,
    );
  }

  /// ✅ FIX: allowComment toggle වෙනකොට Firestore update කරනවා
  /// postId pass කළොත් Firestore update, නැත්නම් callback only (upload flow)
  Future<void> _updateCommentAllowed(bool value) async {
    setState(() {
      commentEnabled = value;
      _isUpdating = true;
    });

    _notifyChange();

    // postId තිබෙනවානම් = already uploaded post, Firestore update කරනවා
    if (widget.postId != null && widget.postId!.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('media_posts')
            .doc(widget.postId)
            .update({'allowComment': value});

        debugPrint('✅ Firestore allowComment updated: $value (postId: ${widget.postId})');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value
                    ? 'Comments enabled — viewers can now comment'
                    : 'Comments disabled — comment box will appear but messages are blocked',
              ),
              backgroundColor: value ? Colors.green : Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Error updating allowComment: $e');

        // Rollback on error
        setState(() => commentEnabled = !value);
        _notifyChange();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update comment setting. Please try again.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    setState(() => _isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                const Text(
                  'More Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                  ),
                ),
                const Spacer(),
                // ✅ Loading indicator
                if (_isUpdating)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFF8E8E93),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Options List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildOptionItem(
                  icon: Icons.people,
                  title: 'Allow Duet',
                  subtitle: 'Let others duet with this video',
                  value: duetEnabled,
                  onChanged: (value) {
                    setState(() => duetEnabled = value);
                    _notifyChange();
                  },
                ),
                _buildDivider(),
                _buildOptionItem(
                  icon: Icons.bookmark,
                  title: 'Allow Save',
                  subtitle: 'Let others save this video',
                  value: saveEnabled,
                  onChanged: (value) {
                    setState(() => saveEnabled = value);
                    _notifyChange();
                  },
                ),
                _buildDivider(),

                // ✅ FIX: Allow Comments — special handler with Firestore update
                _buildCommentOptionItem(),

                _buildDivider(),
                _buildOptionItem(
                  icon: Icons.download,
                  title: 'Save to Device',
                  subtitle: 'Save a copy to your device',
                  value: saveDeviceEnabled,
                  onChanged: (value) {
                    setState(() => saveDeviceEnabled = value);
                    _notifyChange();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// ✅ FIX: Comment option item — disabled state ශෙ
  Widget _buildCommentOptionItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.chat_bubble,
              // ✅ Icon color changes based on enabled/disabled
              color: commentEnabled ? const Color(0xFF000000) : const Color(0xFFCCCCCC),
              size: 20,
            ),
          ),

          const SizedBox(width: 16),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allow Comments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    // ✅ Title color changes
                    color: commentEnabled ? const Color(0xFF000000) : const Color(0xFF999999),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // ✅ Subtitle changes based on state
                  commentEnabled
                      ? 'Let others comment on this video'
                      : 'Comment box visible but messages blocked',
                  style: TextStyle(
                    fontSize: 13,
                    color: commentEnabled ? const Color(0xFF8E8E93) : const Color(0xFFFF9500),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // iOS Style Switch
          GestureDetector(
            onTap: _isUpdating ? null : () => _updateCommentAllowed(!commentEnabled),
            child: Opacity(
              opacity: _isUpdating ? 0.5 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 52,
                height: 32,
                decoration: BoxDecoration(
                  color: commentEnabled ? primaryColor : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: commentEnabled ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF000000),
              size: 20,
            ),
          ),

          const SizedBox(width: 16),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // iOS Style Switch
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              height: 32,
              decoration: BoxDecoration(
                color: value ? primaryColor : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 56),
      color: const Color(0xFFE0E0E0),
    );
  }
}