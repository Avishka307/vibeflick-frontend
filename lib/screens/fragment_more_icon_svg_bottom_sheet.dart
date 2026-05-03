import 'package:flutter/material.dart';
import 'activity_setting_option.dart'; // Import settings screen

class MoreIconSvgFragmentBottomSheet extends StatelessWidget {
  const MoreIconSvgFragmentBottomSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            alignment: Alignment.center,
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Share Option
          _buildOptionItem(
            context: context,
            id: 'SheyaOption',
            icon: Icons.share,
            title: 'Share',
            onTap: () {
              Navigator.pop(context);
              _handleShareOption(context);
            },
          ),

          // QR Code Option
          _buildOptionItem(
            context: context,
            id: 'QrCodeOption',
            icon: Icons.qr_code_scanner,
            title: 'QR Code',
            onTap: () {
              Navigator.pop(context);
              _handleQRCodeOption(context);
            },
          ),

          // Settings Option - Navigate to Settings Screen
          _buildOptionItem(
            context: context,
            id: 'SettingOption',
            icon: Icons.settings,
            title: 'Settings',
            onTap: () {
              Navigator.pop(context); // Close bottom sheet first
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ActivitySettingOption(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required BuildContext context,
    required String id,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: Colors.black,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  // Handle Share Option
  void _handleShareOption(BuildContext context) {
    // Implement share functionality
    // Example using share_plus package:
    // Share.share('Check out this app!');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share option clicked')),
    );
  }

  // Handle QR Code Option
  void _handleQRCodeOption(BuildContext context) {
    // Navigate to QR Code screen or show QR dialog
    // Example:
    // Navigator.push(context, MaterialPageRoute(builder: (context) => QRCodeScreen()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR Code option clicked')),
    );
  }
}

// Usage example: Show as bottom sheet
void showMoreOptionsBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const MoreIconSvgFragmentBottomSheet(),
  );
}

// Example: How to use in your main screen
class ExampleUsageScreen extends StatelessWidget {
  const ExampleUsageScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => showMoreOptionsBottomSheet(context),
          ),
        ],
      ),
      body: const Center(
        child: Text('Press more icon to open bottom sheet'),
      ),
    );
  }
}