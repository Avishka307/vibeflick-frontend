import 'package:flutter/material.dart';

class WhoCanViewBottomSheet extends StatefulWidget {
  final String currentSelection;
  final Function(String) onPrivacySelected;

  const WhoCanViewBottomSheet({
    super.key,
    this.currentSelection = 'Public',
    required this.onPrivacySelected,
  });

  @override
  State<WhoCanViewBottomSheet> createState() => _WhoCanViewBottomSheetState();

  static void show(
      BuildContext context, {
        String currentSelection = 'Public',
        required Function(String) onPrivacySelected,
      }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => WhoCanViewBottomSheet(
        currentSelection: currentSelection,
        onPrivacySelected: onPrivacySelected,
      ),
    );
  }
}

class _WhoCanViewBottomSheetState extends State<WhoCanViewBottomSheet> {
  late String selectedPrivacy;

  @override
  void initState() {
    super.initState();
    selectedPrivacy = _convertToDisplayFormat(widget.currentSelection);
  }

  String _convertToDisplayFormat(String privacy) {
    switch (privacy.toLowerCase()) {
      case 'public':
        return 'Public';
      case 'followers':
        return 'Followers';
      case 'onlyme':
      case 'only me':
        return 'Only Me';
      default:
        return 'Public';
    }
  }

  void _updateSelection(String selection) {
    setState(() {
      selectedPrivacy = selection;
    });
    widget.onPrivacySelected(selection);
    Navigator.pop(context);
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
                  'Who can view this video',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                  ),
                ),
                const Spacer(),
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
          _buildOptionItem(
            icon: Icons.public,
            title: 'Public',
            subtitle: 'Everyone can watch this video',
            isSelected: selectedPrivacy == 'Public',
            onTap: () => _updateSelection('Public'),
          ),

          _buildDivider(),

          _buildOptionItem(
            icon: Icons.people,
            title: 'Followers',
            subtitle: 'Your followers can watch this video',
            isSelected: selectedPrivacy == 'Followers',
            onTap: () => _updateSelection('Followers'),
          ),

          _buildDivider(),

          _buildOptionItem(
            icon: Icons.lock,
            title: 'Only Me',
            subtitle: 'Only you can watch this video',
            isSelected: selectedPrivacy == 'Only Me',
            onTap: () => _updateSelection('Only Me'),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

            // Check Mark
            if (isSelected)
              const Icon(
                Icons.check,
                color: Color(0xFFFF0050),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 80),
      color: const Color(0xFFE0E0E0),
    );
  }
}