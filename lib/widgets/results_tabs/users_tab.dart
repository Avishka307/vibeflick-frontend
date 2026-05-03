import 'package:flutter/material.dart';
import '../skeleton_loader.dart';
import 'dart:async';

class UsersTab extends StatefulWidget {
  final String query;

  const UsersTab({super.key, required this.query});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _users = [];
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadData() {
    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _users.addAll(_generateUsers());
          _isLoading = false;
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      _loadMore();
    }
  }

  void _loadMore() {
    setState(() {
      _isLoadingMore = true;
    });

    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _users.addAll(_generateUsers());
          _isLoadingMore = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> _generateUsers() {
    final names = [
      'Kasun Perera',
      'Nimali Silva',
      'Ravindu Fernando',
      'Sachini Dias',
      'Tharindu Wijesinghe',
      'Dilini Jayawardena',
      'Kasun Gamage',
      'Nethmi Perera',
    ];
    final avatars = ['🎭', '🎨', '🎵', '💃', '🎬', '📸', '🎪', '🎯'];

    return List.generate(8, (index) {
      return {
        'name': names[index % names.length],
        'username': '@${names[index % names.length].toLowerCase().split(' ')[0]}${index + 1}',
        'followers': '${(800 - index * 50)}K',
        'avatar': avatars[index % avatars.length],
        'verified': index < 3,
        'bio': 'Content creator • ${index % 2 == 0 ? 'Dancer' : 'Artist'} • Sri Lanka 🇱🇰',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SkeletonLoader.user(),
          );
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _users.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _users.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: SkeletonLoader.user(),
          );
        }

        final user = _users[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildUserCard(user),
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF0050), Color(0xFFFFB800)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0050).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user['avatar'],
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user['verified']) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: Color(0xFF00D9FF),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user['username'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_rounded,
                          size: 14,
                          color: Color(0xFF5F6368),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${user['followers']} followers',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5F6368),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0050),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0050).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Follow',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (user['bio'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                user['bio'],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withOpacity(0.7),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}