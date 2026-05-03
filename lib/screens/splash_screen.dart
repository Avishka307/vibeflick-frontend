import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../firebase_options.dart';
import '../services/auth_service.dart';

import '../main.dart';
import 'login_page_activity.dart';
import 'banned_user_screen.dart'; // ✅ ADD

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _initializeApp();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final currentUser = AuthService.getCurrentUser();

    if (currentUser == null) {
      debugPrint('🚪 No user logged in → Navigating to Login Page');
      _navigateToLoginPage();
      return;
    }

    debugPrint('✅ User logged in: ${currentUser.uid}');

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        debugPrint('⚠️ User document not found → Going to Login');
        await FirebaseAuth.instance.signOut();
        _navigateToLoginPage();
        return;
      }

      final userData = userDoc.data()!;

      // ✅ ADD: Strike 3 Ban Check
      final accountStatus = userData['accountStatus'] ?? 'active';
      if (accountStatus == 'banned') {
        debugPrint('💀 Account banned → Navigate to BannedScreen');
        _navigateToBannedScreen();
        return;
      }
      // ✅ END

      final interests = userData['interests'];

      bool hasInterests = false;

      if (interests is List) {
        hasInterests = interests.isNotEmpty;
      } else if (interests is String) {
        hasInterests = interests.isNotEmpty;
      }

      debugPrint('📊 User has interests: $hasInterests');

      if (!hasInterests) {
        debugPrint('🎯 No interests → Navigate to Interest Selection');
        await AuthService.checkUserInterestsAndNavigate(
          context: context,
          uid: currentUser.uid,
          onLoadingEnd: () {},
        );
      } else {
        debugPrint('🏠 Has interests → Navigate to Home');
        _navigateToHome();
      }
    } catch (e) {
      debugPrint('❌ Error checking user data: $e');
      _navigateToLoginPage();
    }
  }

  void _navigateToLoginPage() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const LoginPageActivity(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ✅ ADD
  void _navigateToBannedScreen() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const BannedUserScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
  // ✅ END

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F0F),
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F0F0F),
            ],
          ),
        ),
        child: Stack(
          children: [
            ...List.generate(30, (index) => _buildFloatingParticle(index)),

            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF006E), Color(0xFF8E2DE2)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF006E).withOpacity(0.6),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFFFF006E),
                          Color(0xFF8E2DE2),
                          Color(0xFF00D9FF),
                        ],
                      ).createShader(bounds),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: const [
                          Text(
                            'Vibe',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -2,
                            ),
                          ),
                          Text(
                            'Flick',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: -2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Discover • Create • Share',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: 3,
                        fontWeight: FontWeight.w300,
                      ),
                    ),

                    const SizedBox(height: 60),

                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFFFF006E).withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingParticle(int index) {
    final random = index * 0.1;
    final delay = (index % 3) * 500;

    return Positioned(
      left: (index % 7) * 60.0,
      top: (index ~/ 7) * 120.0,
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 2000 + delay),
        builder: (context, double value, child) {
          return Transform.translate(
            offset: Offset(
              (value * 30) * (index % 2 == 0 ? 1 : -1),
              (value * 30) * (index % 3 == 0 ? 1 : -1),
            ),
            child: Opacity(
              opacity: 0.1 + (value * 0.2),
              child: Container(
                width: 3 + (index % 4) * 2,
                height: 3 + (index % 4) * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF006E).withOpacity(0.6),
                      const Color(0xFF8E2DE2).withOpacity(0.4),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF006E).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        onEnd: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }
}