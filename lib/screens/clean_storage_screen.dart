import 'package:flutter/material.dart';
import 'package:my_vibe_flick/screens/storage_info.dart';
import 'package:my_vibe_flick/screens/storage_service.dart';

class CleanStorageScreen extends StatefulWidget {
  const CleanStorageScreen({Key? key}) : super(key: key);

  @override
  State<CleanStorageScreen> createState() => _CleanStorageScreenState();
}

class _CleanStorageScreenState extends State<CleanStorageScreen> {
  final StorageService _storageService = StorageService();
  List<StorageInfo> _storageList = [];
  bool _isLoading = true;
  double _totalSize = 0.0;

  // Dark theme colors
  static const Color _bgColor = Color(0xFF1F1F1F);
  static const Color _cardColor = Color(0xFF2A2A2A);
  static const Color _accentColor = Color(0xFF6C63FF);
  static const Color _secondaryAccent = Color(0xFFFF6584);

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    setState(() => _isLoading = true);
    final storageList = await _storageService.getStorageInfo();
    final total = storageList.fold(0.0, (sum, item) => sum + item.sizeInMB);
    setState(() {
      _storageList = storageList;
      _totalSize = total;
      _isLoading = false;
    });
  }

  // 🆕 Calculate selected size
  double _getSelectedSize() {
    return _storageList
        .where((item) => item.isSelected)
        .fold(0.0, (sum, item) => sum + item.sizeInMB);
  }

  Future<void> _clearSelected() async {
    final selected = _storageList.where((item) => item.isSelected).toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one category to clear'),
          backgroundColor: _cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // 🆕 Show selected size in confirmation
    final selectedSize = _getSelectedSize();
    final sizeText = selectedSize < 1024
        ? '${selectedSize.toStringAsFixed(1)} MB'
        : '${(selectedSize / 1024).toStringAsFixed(2)} GB';

    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Action', style: TextStyle(color: Colors.white)),
        content: Text(
          'Clear ${selected.length} selected ${selected.length == 1 ? 'category' : 'categories'}?\n\nThis will free up $sizeText of storage.', // 🆕 Added size info
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _secondaryAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const CircularProgressIndicator(color: _accentColor),
        ),
      ),
    );

    int successCount = 0;
    for (var item in selected) {
      final success = await _storageService.clearCategory(item);
      if (success) successCount++;
    }

    Navigator.pop(context); // Close loading

    // Reload storage info
    await _loadStorageInfo();

    // Show result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('Successfully cleared $successCount ${successCount == 1 ? 'category' : 'categories'}!'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _secondaryAccent),
            const SizedBox(width: 10),
            const Text('Warning', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'All cache data will be deleted. This action cannot be undone!',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _secondaryAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const CircularProgressIndicator(color: _accentColor),
        ),
      ),
    );

    await _storageService.clearAllCache();
    Navigator.pop(context);
    await _loadStorageInfo();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cleaning_services, color: Colors.white),
            const SizedBox(width: 12),
            const Text('All cache cleared successfully!'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // 🆕 Get category icon
  IconData _getCategoryIcon(String category) {
    final categoryLower = category.toLowerCase();
    if (categoryLower.contains('image')) return Icons.image;
    if (categoryLower.contains('video')) return Icons.videocam;
    if (categoryLower.contains('cache')) return Icons.cached;
    if (categoryLower.contains('temp')) return Icons.folder_special;
    if (categoryLower.contains('download')) return Icons.download;
    return Icons.folder;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Clean Storage',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadStorageInfo,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: _accentColor,
          strokeWidth: 3,
        ),
      )
          : Column(
        children: [
          // Total Storage Card
          _buildTotalStorageCard(),

          // 🆕 Empty State
          if (_storageList.isEmpty)
            Expanded(child: _buildEmptyState())
          else
          // Storage Categories List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _storageList.length,
                itemBuilder: (context, index) {
                  return _buildStorageItem(_storageList[index]);
                },
              ),
            ),

          // Bottom Action Buttons
          if (_storageList.isNotEmpty) _buildBottomActions(),
        ],
      ),
    );
  }

  // 🆕 Empty State Widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cleaning_services_rounded,
              size: 60,
              color: _accentColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your storage is already clean!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No cached data found',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _loadStorageInfo,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              side: BorderSide(color: _accentColor, width: 2),
              foregroundColor: _accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalStorageCard() {
    final percentage = _totalSize > 0 ? (_totalSize / 1024) * 100 : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentColor, _secondaryAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.storage_rounded,
                color: Colors.white.withOpacity(0.9),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Total Storage Used',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _totalSize < 1024
                ? '${_totalSize.toStringAsFixed(1)} MB'
                : '${(_totalSize / 1024).toStringAsFixed(2)} GB',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 100.0) / 100,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(1)}% of 1 GB',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageItem(StorageInfo info) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: info.isSelected ? _accentColor : Colors.transparent,
          width: 2,
        ),
        boxShadow: info.isSelected
            ? [
          BoxShadow(
            color: _accentColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
            : [],
      ),
      child: ListTile(
        // 🆕 Use ListTile instead of CheckboxListTile
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

        // 🆕 Category icon (leading works in ListTile)
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getCategoryIcon(info.category),
            color: _accentColor,
            size: 24,
          ),
        ),

        // Title and subtitle
        title: Text(
          info.category,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${info.fileCount} ${info.fileCount == 1 ? 'file' : 'files'}',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
            ),
          ),
        ),

        // Checkbox on the right
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Size badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: info.sizeInMB > 100
                    ? _secondaryAccent.withOpacity(0.2)
                    : _accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                info.sizeText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: info.sizeInMB > 100 ? _secondaryAccent : _accentColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Checkbox
            Checkbox(
              value: info.isSelected,
              onChanged: (value) {
                setState(() => info.isSelected = value ?? false);
              },
              activeColor: _accentColor,
              checkColor: Colors.white,
            ),
          ],
        ),

        // Make entire tile tappable
        onTap: () {
          setState(() => info.isSelected = !info.isSelected);
        },
      ),
    );
  }

  Widget _buildBottomActions() {
    final selectedSize = _getSelectedSize();
    final sizeText = selectedSize < 1024
        ? '${selectedSize.toStringAsFixed(1)} MB'
        : '${(selectedSize / 1024).toStringAsFixed(2)} GB';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearSelected,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Clear Selected',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    // 🆕 Show selected size
                    if (selectedSize > 0)
                      Text(
                        '($sizeText)',
                        style: const TextStyle(fontSize: 11),
                      ),
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: _accentColor, width: 2),
                  foregroundColor: _accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.cleaning_services_rounded, size: 20),
                label: const Text(
                  'Clear All',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _secondaryAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}