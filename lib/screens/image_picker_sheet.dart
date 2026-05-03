import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerSheet {
  static Future<List<File>?> show(
      BuildContext context, {
        required int maxImages,
        required int currentImageCount,
      }) async {
    final remainingSlots = maxImages - currentImageCount;

    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $maxImages images allowed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return null;
    }

    return await showModalBottomSheet<List<File>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ImagePickerSheetContent(
        remainingSlots: remainingSlots,
        maxImages: maxImages,
      ),
    );
  }
}

class _ImagePickerSheetContent extends StatefulWidget {
  final int remainingSlots;
  final int maxImages;

  const _ImagePickerSheetContent({
    required this.remainingSlots,
    required this.maxImages,
  });

  @override
  State<_ImagePickerSheetContent> createState() =>
      _ImagePickerSheetContentState();
}

class _ImagePickerSheetContentState extends State<_ImagePickerSheetContent> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  bool _isLoading = false;

  Future<void> _pickFromGallery() async {
    try {
      setState(() => _isLoading = true);

      // Check and request permission
      PermissionStatus status;

      if (Platform.isAndroid) {
        if (await _getAndroidVersion() >= 33) {
          // Android 13+ uses photos permission
          status = await Permission.photos.request();
        } else {
          // Android 12 and below uses storage permission
          status = await Permission.storage.request();
        }
      } else {
        // iOS
        status = await Permission.photos.request();
      }

      if (!status.isGranted) {
        if (mounted) {
          _showSnackBar('Gallery permission is required');
        }
        setState(() => _isLoading = false);
        return;
      }

      // Pick multiple images
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Convert to File list
      final files = pickedFiles.map((xFile) => File(xFile.path)).toList();

      // Check if selection exceeds limit
      if (files.length > widget.remainingSlots) {
        if (mounted) {
          _showSnackBar(
            'You can only add ${widget.remainingSlots} more image${widget.remainingSlots > 1 ? 's' : ''}',
          );
        }
        // Take only the allowed number
        _selectedImages.addAll(files.take(widget.remainingSlots));
      } else {
        _selectedImages.addAll(files);
      }

      setState(() => _isLoading = false);

      // Show preview
      _showPreview();
    } catch (e) {
      debugPrint('❌ Error picking images: $e');
      if (mounted) {
        _showSnackBar('Failed to pick images');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      try {
        final androidInfo = await Future.value(33); // Default to latest
        return androidInfo;
      } catch (e) {
        return 33;
      }
    }
    return 0;
  }

  Future<void> _pickFromCamera() async {
    try {
      setState(() => _isLoading = true);

      // Check camera permission
      final status = await Permission.camera.request();

      if (!status.isGranted) {
        if (mounted) {
          _showSnackBar('Camera permission is required');
        }
        setState(() => _isLoading = false);
        return;
      }

      // Take photo
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo == null) {
        setState(() => _isLoading = false);
        return;
      }

      _selectedImages.add(File(photo.path));

      setState(() => _isLoading = false);

      // Show preview
      _showPreview();
    } catch (e) {
      debugPrint('❌ Error taking photo: $e');
      if (mounted) {
        _showSnackBar('Failed to take photo');
      }
      setState(() => _isLoading = false);
    }
  }

  void _showPreview() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PreviewSheet(
        images: _selectedImages,
        onConfirm: () {
          Navigator.pop(context); // Close preview
          Navigator.pop(context, _selectedImages); // Return images
        },
        onRemove: (index) {
          setState(() {
            _selectedImages.removeAt(index);
          });
          if (_selectedImages.isEmpty) {
            Navigator.pop(context); // Close preview if no images
          }
        },
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Add Images',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can add ${widget.remainingSlots} more image${widget.remainingSlots > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 24),

          // Gallery option
          _buildOption(
            icon: Icons.photo_library_rounded,
            title: 'Choose from Gallery',
            subtitle: 'Select multiple images',
            onTap: _isLoading ? null : _pickFromGallery,
          ),
          const SizedBox(height: 12),

          // Camera option
          _buildOption(
            icon: Icons.camera_alt_rounded,
            title: 'Take Photo',
            subtitle: 'Use camera to take a new photo',
            onTap: _isLoading ? null : _pickFromCamera,
          ),
          const SizedBox(height: 12),

          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),

          if (_isLoading) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(strokeWidth: 2),
          ],
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF444444),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFF3B5C),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF9CA3AF),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// Preview Sheet
class _PreviewSheet extends StatefulWidget {
  final List<File> images;
  final VoidCallback onConfirm;
  final Function(int) onRemove;

  const _PreviewSheet({
    required this.images,
    required this.onConfirm,
    required this.onRemove,
  });

  @override
  State<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<_PreviewSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Images (${widget.images.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Image grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF2A2A2A),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          widget.images[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          widget.onRemove(index);
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B5C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
              ),
              child: const Text(
                'Add Images',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}