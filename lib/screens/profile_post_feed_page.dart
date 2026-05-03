import 'package:flutter/material.dart';
import 'package:my_vibe_flick/screens/post_detail_page.dart';

class ProfilePostFeedPage extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final int initialIndex;

  const ProfilePostFeedPage({
    Key? key,
    required this.posts,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<ProfilePostFeedPage> createState() => _ProfilePostFeedPageState();
}

class _ProfilePostFeedPageState extends State<ProfilePostFeedPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.posts.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final post = widget.posts[index];
              final postId = post['id'] ?? '';
              final userId = post['uid'] ?? '';

              return PostDetailPage(
                postId: postId,
                initialUserId: userId,
                hideBackButton: true, // ← PostDetailPage back button සම්පූර්ණයෙන් hide
              );
            },
          ),

          // ── Single back button (always visible, top of stack) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}