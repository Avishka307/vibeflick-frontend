import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';
import 'activity_selected_media.dart';


class MeadiaFragment extends StatefulWidget {
  const MeadiaFragment({super.key});

  @override
  State<MeadiaFragment> createState() => _MeadiaFragmentState();
}

class _MeadiaFragmentState extends State<MeadiaFragment> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;

  int selectedCount = 0;
  // ── Multi-select list ─────────────────────────────────────────────────────
  List<AssetEntity> selectedMediaList = [];
  AssetEntity? get selectedMedia =>
      selectedMediaList.isNotEmpty ? selectedMediaList.first : null;

  List<AssetEntity> _mediaList = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  int _currentPage = 0;
  static const int pageSize = 50;
  bool permissionGranted = false;

  static const int maxImages = 3;
  static const int maxVideoDurationSeconds = 60;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _requestPermissionAndLoadMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        isLoading = true;
        _mediaList.clear();
        _currentPage = 0;
        hasMore = true;
      });
      _loadMedia();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!isLoadingMore && hasMore) {
        _loadMoreMedia();
      }
    }
  }

  Future<void> _requestPermissionAndLoadMedia() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();

      if (ps.isAuth || ps.hasAccess) {
        setState(() {
          permissionGranted = true;
        });
        await _loadMedia();
      } else {
        setState(() {
          permissionGranted = false;
          isLoading = false;
        });
        if (mounted) {
          _showPermissionDialog();
        }
      }
    } catch (e) {
      print('Permission error: $e');
      setState(() {
        permissionGranted = false;
        isLoading = false;
      });
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Permission Required',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Please grant access to photos and videos to continue.',
          style: TextStyle(color: Color(0xFF8B949E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              PhotoManager.openSetting();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF58A6FF),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  RequestType get _currentRequestType {
    switch (_tabController.index) {
      case 1:
        return RequestType.video;
      case 2:
        return RequestType.image;
      default:
        return RequestType.common;
    }
  }

  Future<List<AssetPathEntity>> _getAlbums() async {
    return await PhotoManager.getAssetPathList(
      type: _currentRequestType,
      hasAll: true,
      onlyAll: false,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
        videoOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
  }

  Future<void> _loadMedia() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      _currentPage = 0;
      hasMore = true;
      _mediaList.clear();
    });

    try {
      final albums = await _getAlbums();

      if (albums.isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final recentPath = albums.first;
      final int totalCount = await recentPath.assetCountAsync;

      if (totalCount == 0) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final media = await recentPath.getAssetListPaged(
        page: 0,
        size: pageSize,
      );

      print('Loaded ${media.length} media items');

      if (mounted) {
        setState(() {
          _mediaList = media;
          _currentPage = 1;
          isLoading = false;
          hasMore = media.length >= pageSize && media.length < totalCount;
        });
      }
    } catch (e) {
      print('Error loading media: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadMoreMedia() async {
    if (isLoadingMore || !hasMore || !mounted) return;

    setState(() => isLoadingMore = true);

    try {
      final albums = await _getAlbums();
      if (albums.isEmpty) {
        setState(() { hasMore = false; isLoadingMore = false; });
        return;
      }

      final recentPath = albums.first;
      final int totalCount = await recentPath.assetCountAsync;

      final moreMedia = await recentPath.getAssetListPaged(
        page: _currentPage,
        size: pageSize,
      );

      print('Loaded more ${moreMedia.length} items');

      if (mounted) {
        setState(() {
          if (moreMedia.isNotEmpty) {
            _mediaList.addAll(moreMedia);
            _currentPage++;
          }
          hasMore = moreMedia.length >= pageSize && _mediaList.length < totalCount;
          isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more media: $e');
      if (mounted) setState(() { isLoadingMore = false; hasMore = false; });
    }
  }

  // ── Selection Logic ───────────────────────────────────────────────────────

  void _showToast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF21262D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void handleMediaSelection(AssetEntity asset) {
    // Already selected → deselect
    if (selectedMediaList.contains(asset)) {
      setState(() {
        selectedMediaList.remove(asset);
        selectedCount = selectedMediaList.length;
      });
      return;
    }

    final bool isVideo = asset.type == AssetType.video;
    final bool hasVideo = selectedMediaList.any((a) => a.type == AssetType.video);
    final bool hasImages = selectedMediaList.any((a) => a.type == AssetType.image);

    if (isVideo) {
      // Cannot mix with images
      if (hasImages) {
        _showToast('Images selected. Please clear selection before choosing a video.');
        return;
      }
      // Only 1 video allowed
      if (hasVideo) {
        _showToast('You can only select 1 video at a time.');
        return;
      }
      // 60 second limit
      if (asset.duration > maxVideoDurationSeconds) {
        final mins = asset.duration ~/ 60;
        final secs = asset.duration % 60;
        _showToast(
          'Video too long (${mins}m ${secs}s). Maximum is 60 seconds.',
        );
        return;
      }
      setState(() {
        selectedMediaList.add(asset);
        selectedCount = selectedMediaList.length;
      });
      return;
    }

    // Image rules
    if (hasVideo) {
      _showToast('A video is selected. Please clear before selecting images.');
      return;
    }
    if (selectedMediaList.length >= maxImages) {
      _showToast('You can select up to $maxImages images only.');
      return;
    }
    setState(() {
      selectedMediaList.add(asset);
      selectedCount = selectedMediaList.length;
    });
  }

  void clearSelection() {
    setState(() {
      selectedMediaList.clear();
      selectedCount = 0;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: const Color(0xFF21262D), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Section with Drag Handle
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A5568),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                const Text(
                  'Select Media',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Tab Layout
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(
                  color: Color(0xFF58A6FF),
                  width: 3,
                ),
                insets: EdgeInsets.symmetric(horizontal: 40),
              ),
              labelColor: const Color(0xFF58A6FF),
              unselectedLabelColor: const Color(0xFF8B949E),
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Videos'),
                Tab(text: 'Photos'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Content
          SizedBox(
            height: 400,
            child: isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF58A6FF),
              ),
            )
                : !permissionGranted
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF8B949E),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Permission Required',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please grant access to photos',
                    style: TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      PhotoManager.openSetting();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF58A6FF),
                    ),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            )
                : _buildMediaGrid(_mediaList),
          ),

          // Bottom Action Bar
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // Selected Count
                if (selectedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '$selectedCount ${selectedCount == 1 ? 'item' : 'items'} selected',
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 12,
                      ),
                    ),
                  ),

                // Action Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Selected Media Preview (first item + count badge)
                    if (selectedMedia != null)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[800],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FutureBuilder<Uint8List?>(
                                future: selectedMedia!.thumbnailDataWithSize(
                                  const ThumbnailSize(200, 200),
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return Stack(
                                      children: [
                                        Image.memory(
                                          snapshot.data!,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                        ),
                                        if (selectedMedia!.type == AssetType.video)
                                          Positioned(
                                            right: 4,
                                            bottom: 4,
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        // +N badge when multiple selected
                                        if (selectedCount > 1)
                                          Positioned(
                                            left: 4,
                                            bottom: 4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF58A6FF),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '+${selectedCount - 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  }
                                  return Container(
                                    color: Colors.grey[700],
                                    child: const Icon(
                                      Icons.image,
                                      color: Colors.white54,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // Close Icon
                          Positioned(
                            top: -8,
                            right: -8,
                            child: GestureDetector(
                              onTap: clearSelection,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF3B5C),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(width: 64),

                    // Buttons
                    Row(
                      children: [
                        // Clear All Button
                        if (selectedCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: OutlinedButton(
                              onPressed: clearSelection,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF85149),
                                side: const BorderSide(
                                  color: Color(0xFFF85149),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              child: const Text(
                                'Clear',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // Next Button
                        ElevatedButton(
                          onPressed: selectedMediaList.isNotEmpty
                              ? () async {
                            final primary = selectedMediaList.first;
                            final file = await primary.file;
                            if (file != null && mounted) {
                              // සියලු selected media files resolve කරනවා
                              final List<String> paths = [];
                              final List<bool> isVideos = [];
                              for (final asset in selectedMediaList) {
                                final f = await asset.file;
                                if (f != null) {
                                  paths.add(f.path);
                                  isVideos.add(asset.type == AssetType.video);
                                }
                              }
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SelectedMediaScreen(
                                    mediaPath: file.path,
                                    isVideo: primary.type == AssetType.video,
                                    // අලුතින් add කරන parameters:
                                    extraMediaPaths: paths.skip(1).toList(),
                                    extraMediaIsVideo: isVideos.skip(1).toList(),
                                  ),
                                ),
                              );
                            }
                          }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3B5C),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF21262D),
                            disabledForegroundColor: const Color(0xFF8B949E),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            minimumSize: const Size(140, 56),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Next',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid(List<AssetEntity> mediaList) {
    if (mediaList.isEmpty && !isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.photo_library_outlined,
              color: Color(0xFF8B949E),
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'No media found',
              style: TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 1000,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: mediaList.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == mediaList.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  color: Color(0xFF58A6FF),
                  strokeWidth: 2,
                ),
              ),
            );
          }

          final asset = mediaList[index];
          final isSelected = selectedMediaList.contains(asset);
          final selectionIndex = selectedMediaList.indexOf(asset);

          return GestureDetector(
            onTap: () => handleMediaSelection(asset),
            child: Container(
              decoration: BoxDecoration(
                border: isSelected
                    ? Border.all(color: const Color(0xFF58A6FF), width: 3)
                    : null,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Media thumbnail
                  FutureBuilder<Uint8List?>(
                    future: asset.thumbnailDataWithSize(
                      const ThumbnailSize(200, 200),
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            cacheWidth: 200,
                          ),
                        );
                      }
                      return Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF58A6FF),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Video duration badge
                  if (asset.type == AssetType.video)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(asset.duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Selection number badge
                  if (isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFF58A6FF),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${selectionIndex + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}