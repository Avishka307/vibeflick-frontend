import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

/// 🎥 Modern Live Stream Screen - Premium Social Media Live Feature
/// Features: Glassmorphism UI, Real-time Chat, Virtual Gifts, Face Filters,
/// Floating Hearts, Viewer Count, Follow System, and More!
class LiveStreamScreen extends StatefulWidget {
  final String streamId;
  final String hostName;
  final String hostAvatar;
  final bool isHost;

  const LiveStreamScreen({
    Key? key,
    required this.streamId,
    required this.hostName,
    required this.hostAvatar,
    this.isHost = false,
  }) : super(key: key);

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen>
    with TickerProviderStateMixin {
  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  late AnimationController _heartAnimationController;

  // State variables
  int _viewerCount = 0;
  int _totalLikes = 0;
  int _userCoins = 500; // User's coin balance
  bool _isFollowing = false;
  bool _showFilters = false;
  bool _beautyModeEnabled = false;
  String _selectedFilter = 'None';

  // Chat messages
  List<ChatMessage> _messages = [];

  // Floating hearts
  List<FloatingHeart> _floatingHearts = [];
  Timer? _heartCleanupTimer;

  // Gift animations queue
  List<GiftAnimation> _giftAnimations = [];

  // Available gifts
  final List<VirtualGift> _availableGifts = [
    VirtualGift(name: 'Rose', icon: '🌹', cost: 10, color: Colors.red),
    VirtualGift(name: 'Heart', icon: '💖', cost: 20, color: Colors.pink),
    VirtualGift(name: 'Diamond', icon: '💎', cost: 50, color: Colors.blue),
    VirtualGift(name: 'Crown', icon: '👑', cost: 100, color: Colors.amber),
    VirtualGift(name: 'Rocket', icon: '🚀', cost: 200, color: Colors.purple),
    VirtualGift(name: 'Sports Car', icon: '🏎️', cost: 500, color: Colors.orange),
  ];

  // Face filters
  final List<String> _filters = [
    'None',
    'Smooth Skin',
    'Beauty',
    'Dog Ears',
    'Cat Whiskers',
    'Sparkles',
    'Vintage',
    'Cool Tone'
  ];

  @override
  void initState() {
    super.initState();
    _initializeStream();
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Auto-scroll chat to bottom
    _chatScrollController.addListener(_scrollListener);

    // Cleanup timer for hearts
    _heartCleanupTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _cleanupHearts();
    });

    // Simulate viewer count changes
    _simulateViewerChanges();

    // Add welcome message
    _addSystemMessage('Welcome to ${widget.hostName}\'s live stream! 🎉');
  }

  void _scrollListener() {
    // Auto-scroll logic if needed
  }

  void _initializeStream() {
    // TODO: Initialize ZEGOCLOUD Express Engine
    // ZegoExpressEngine.createEngineWithProfile(...)

    setState(() {
      _viewerCount = Random().nextInt(100) + 50;
    });
  }

  void _simulateViewerChanges() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _viewerCount += Random().nextInt(10) - 3;
        if (_viewerCount < 1) _viewerCount = 1;
      });
    });
  }

  void _cleanupHearts() {
    setState(() {
      _floatingHearts.removeWhere((heart) => heart.isExpired);
    });
  }

  void _addSystemMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(
        username: 'System',
        message: message,
        isSystem: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _addChatMessage(String username, String message, {bool isHost = false}) {
    setState(() {
      _messages.add(ChatMessage(
        username: username,
        message: message,
        isHost: isHost,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _addChatMessage('You', message, isHost: widget.isHost);

    // TODO: Send via ZEGOCLOUD ZIM SDK
    // ZIM.getInstance()?.sendMessage(...)

    _messageController.clear();
  }

  void _onDoubleTap() {
    // Add floating heart
    _addFloatingHeart();

    setState(() {
      _totalLikes++;
    });

    // TODO: Send like to server
  }

  void _addFloatingHeart() {
    setState(() {
      _floatingHearts.add(FloatingHeart(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: DateTime.now(),
      ));
    });
  }

  void _toggleFollow() {
    setState(() {
      _isFollowing = !_isFollowing;
    });

    // TODO: Update follow status on server
  }

  void _showGiftSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGiftSheet(),
    );
  }

  Widget _buildGiftSheet() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[900]!.withOpacity(0.95),
            Colors.black.withOpacity(0.98),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Send Gift',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$_userCoins',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Gift grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _availableGifts.length,
              itemBuilder: (context, index) {
                final gift = _availableGifts[index];
                final canAfford = _userCoins >= gift.cost;

                return GestureDetector(
                  onTap: canAfford ? () => _sendGift(gift) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: canAfford
                          ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          gift.color.withOpacity(0.3),
                          gift.color.withOpacity(0.1),
                        ],
                      )
                          : null,
                      color: canAfford ? null : Colors.grey[800],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: canAfford ? gift.color.withOpacity(0.5) : Colors.grey[700]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          gift.icon,
                          style: TextStyle(
                            fontSize: 48,
                            color: canAfford ? null : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          gift.name,
                          style: TextStyle(
                            color: canAfford ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: canAfford ? gift.color.withOpacity(0.3) : Colors.grey[700],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.monetization_on,
                                color: canAfford ? Colors.amber : Colors.grey,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${gift.cost}',
                                style: TextStyle(
                                  color: canAfford ? Colors.white : Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Buy more coins button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _buyCoins,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Buy More Coins',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendGift(VirtualGift gift) {
    if (_userCoins < gift.cost) return;

    setState(() {
      _userCoins -= gift.cost;
      _giftAnimations.add(GiftAnimation(
        gift: gift,
        senderName: 'You',
        startTime: DateTime.now(),
      ));
    });

    Navigator.pop(context);

    // Add chat message
    _addChatMessage('You', 'sent ${gift.icon} ${gift.name}!');

    // TODO: Send gift via backend API

    // Remove animation after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _giftAnimations.removeWhere((anim) => anim.gift.name == gift.name);
      });
    });
  }

  void _buyCoins() {
    // TODO: Implement coin purchase flow
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coin purchase feature coming soon!'),
        backgroundColor: Color(0xFFFFD700),
      ),
    );
  }

  void _showFilterSheet() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _showFilters = false;
    });

    // TODO: Apply filter using ZEGOCLOUD Effects SDK
  }

  void _toggleBeautyMode() {
    setState(() {
      _beautyModeEnabled = !_beautyModeEnabled;
    });

    // TODO: Toggle beauty mode via ZEGOCLOUD
  }

  void _shareStream() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share link copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _endStream() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'End Live Stream?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to end this live stream?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showStreamSummary();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('End Stream'),
          ),
        ],
      ),
    );
  }

  void _showStreamSummary() {
    // TODO: Get actual stats from backend
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StreamSummaryDialog(
        totalViewers: _viewerCount + Random().nextInt(50),
        totalLikes: _totalLikes,
        duration: '45:23',
        giftsEarned: 1250,
        newFollowers: Random().nextInt(20) + 5,
      ),
    ).then((_) {
      Navigator.pop(context); // Exit stream screen
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    _heartAnimationController.dispose();
    _heartCleanupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: GestureDetector(
          onDoubleTap: _onDoubleTap,
          child: Stack(
            children: [
              // Video Stream Background (Full Screen)
              _buildVideoStream(),

              // Floating Hearts
              ..._floatingHearts.map((heart) => _buildFloatingHeart(heart)),

              // Gift Animations
              ..._giftAnimations.map((anim) => _buildGiftAnimation(anim)),

              // Top Overlay
              _buildTopOverlay(),

              // Side Actions
              _buildSideActions(),

              // Chat Messages
              _buildChatMessages(),

              // Bottom Input
              _buildBottomInput(),

              // Filter Panel
              if (_showFilters) _buildFilterPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoStream() {
    // TODO: Replace with actual ZEGOCLOUD video view
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.purple[900]!,
            Colors.blue[900]!,
            Colors.pink[900]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                image: DecorationImage(
                  image: NetworkImage(widget.hostAvatar),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.hostName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Host Profile
            _buildGlassContainer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(widget.hostAvatar),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.hostName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!widget.isHost) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _toggleFollow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: _isFollowing
                              ? null
                              : const LinearGradient(
                            colors: [Color(0xFFFF6B9D), Color(0xFFC06C84)],
                          ),
                          color: _isFollowing ? Colors.grey[700] : null,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),

            // Viewer Count
            _buildGlassContainer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.remove_red_eye, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _formatNumber(_viewerCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Close Button
            GestureDetector(
              onTap: widget.isHost ? _endStream : () => Navigator.pop(context),
              child: _buildGlassContainer(
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideActions() {
    return Positioned(
      right: 12,
      bottom: 160,
      child: Column(
        children: [
          // Like/Heart Button
          _buildActionButton(
            icon: Icons.favorite,
            label: _formatNumber(_totalLikes),
            color: Colors.pink,
            onTap: _onDoubleTap,
          ),
          const SizedBox(height: 20),

          // Gift Button
          _buildActionButton(
            icon: Icons.card_giftcard,
            label: 'Gift',
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            onTap: _showGiftSheet,
          ),
          const SizedBox(height: 20),

          // Filter Button
          _buildActionButton(
            icon: Icons.auto_fix_high,
            label: 'Filters',
            color: _beautyModeEnabled || _selectedFilter != 'None'
                ? Colors.purple
                : Colors.white,
            onTap: _showFilterSheet,
          ),
          const SizedBox(height: 20),

          // Share Button
          _buildActionButton(
            icon: Icons.share,
            label: 'Share',
            onTap: _shareStream,
          ),

          if (widget.isHost) ...[
            const SizedBox(height: 20),
            // Flip Camera
            _buildActionButton(
              icon: Icons.flip_camera_ios,
              label: 'Flip',
              onTap: () {
                // TODO: Flip camera
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    Gradient? gradient,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? Colors.black.withOpacity(0.3) : null,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (color ?? Colors.white).withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color ?? Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessages() {
    return Positioned(
      left: 12,
      right: 80,
      bottom: 100,
      height: 300,
      child: ListView.builder(
        controller: _chatScrollController,
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildChatBubble(message),
          );
        },
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    if (message.isSystem) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          message.message,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: message.isHost
            ? const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
        )
            : null,
        color: message.isHost ? null : Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
        border: message.isHost
            ? Border.all(color: Colors.blue[300]!, width: 2)
            : Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${message.username}: ',
              style: TextStyle(
                color: message.isHost ? Colors.amber : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            TextSpan(
              text: message.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInput() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 30,
      child: SafeArea(
        child: _buildGlassContainer(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Say something...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B9D), Color(0xFFC06C84)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFloatingHeart(FloatingHeart heart) {
    final elapsed = DateTime.now().difference(heart.startTime).inMilliseconds;
    final progress = elapsed / 2000.0;

    if (progress >= 1.0) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final startX = screenWidth - 80 + (Random().nextDouble() * 40 - 20);
    final endX = startX + (Random().nextDouble() * 100 - 50);
    final x = startX + (endX - startX) * progress;
    final y = screenHeight - 200 - (progress * 400);

    final opacity = 1.0 - progress;
    final scale = 0.5 + (progress * 0.5);

    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.orange,
      Colors.yellow,
    ];

    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Icon(
            Icons.favorite,
            color: colors[Random().nextInt(colors.length)],
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget _buildGiftAnimation(GiftAnimation animation) {
    return Positioned(
      left: 0,
      right: 0,
      top: MediaQuery.of(context).size.height * 0.3,
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        builder: (context, double value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: Column(
                children: [
                  Text(
                    animation.gift.icon,
                    style: const TextStyle(fontSize: 120),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          animation.gift.color.withOpacity(0.8),
                          animation.gift.color.withOpacity(0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: animation.gift.color.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Text(
                      '${animation.senderName} sent ${animation.gift.name}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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

  Widget _buildFilterPanel() {
    return Positioned(
      right: 80,
      bottom: 160,
      child: Container(
        width: 120,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleBeautyMode,
                    child: Icon(
                      Icons.face_retouching_natural,
                      color: _beautyModeEnabled ? Colors.purple : Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = filter == _selectedFilter;

                  return GestureDetector(
                    onTap: () => _applyFilter(filter),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.purple.withOpacity(0.5) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

// Data Models
class ChatMessage {
  final String username;
  final String message;
  final bool isSystem;
  final bool isHost;
  final DateTime timestamp;

  ChatMessage({
    required this.username,
    required this.message,
    this.isSystem = false,
    this.isHost = false,
    required this.timestamp,
  });
}

class VirtualGift {
  final String name;
  final String icon;
  final int cost;
  final Color color;

  VirtualGift({
    required this.name,
    required this.icon,
    required this.cost,
    required this.color,
  });
}

class FloatingHeart {
  final String id;
  final DateTime startTime;

  FloatingHeart({
    required this.id,
    required this.startTime,
  });

  bool get isExpired {
    return DateTime.now().difference(startTime).inMilliseconds > 2000;
  }
}

class GiftAnimation {
  final VirtualGift gift;
  final String senderName;
  final DateTime startTime;

  GiftAnimation({
    required this.gift,
    required this.senderName,
    required this.startTime,
  });
}

// Stream Summary Dialog
class StreamSummaryDialog extends StatelessWidget {
  final int totalViewers;
  final int totalLikes;
  final String duration;
  final int giftsEarned;
  final int newFollowers;

  const StreamSummaryDialog({
    Key? key,
    required this.totalViewers,
    required this.totalLikes,
    required this.duration,
    required this.giftsEarned,
    required this.newFollowers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Stream Ended',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildStatRow(Icons.remove_red_eye, 'Total Viewers', totalViewers.toString()),
            _buildStatRow(Icons.favorite, 'Total Likes', totalLikes.toString()),
            _buildStatRow(Icons.schedule, 'Duration', duration),
            _buildStatRow(Icons.card_giftcard, 'Gifts Earned', '$giftsEarned coins', color: Colors.amber),
            _buildStatRow(Icons.person_add, 'New Followers', '+$newFollowers'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}