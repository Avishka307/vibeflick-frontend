import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  int _tapCount = 0;
  bool _developerMode = false;

  void _handleVersionTap() {
    setState(() {
      _tapCount++;
      if (_tapCount >= 7 && !_developerMode) {
        _developerMode = true;
        _tapCount = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Developer Mode Activated!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.purple,
          ),
        );
      }
    });

    // Reset counter after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _tapCount = 0;
        });
      }
    });
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'officialvibeflickgx@gmail.com',
      query: 'subject=VibeFlick Support',
    );
    if (!await launchUrl(emailUri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About Us',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // 1. Branding & Identity
              _buildBrandingSection(),

              const SizedBox(height: 50),

              // 2. Story & Mission
              _buildStorySection(),

              const SizedBox(height: 50),

              // 3. Connect & Socials
              _buildSocialSection(),

              const SizedBox(height: 60),

              // 4. Footer
              _buildFooter(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingSection() {
    return Column(
      children: [
        // App Logo
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8E2DE2).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.play_circle_fill,
              size: 70,
              color: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // App Name
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          ).createShader(bounds),
          child: const Text(
            'VibeFlick',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Version Number (Easter Egg)
        GestureDetector(
          onTap: _handleVersionTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _developerMode
                    ? const Color(0xFF8E2DE2)
                    : Colors.grey[800]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_developerMode)
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(
                      Icons.developer_mode,
                      color: Color(0xFF8E2DE2),
                      size: 16,
                    ),
                  ),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: _developerMode
                        ? const Color(0xFF8E2DE2)
                        : Colors.grey[400],
                    fontSize: 14,
                    fontWeight: _developerMode ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStorySection() {
    return Column(
      children: [
        // Short Description
        const Text(
          'VibeFlick is the best place to create, share, and discover short videos. Join the vibe!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.6,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 30),

        // Developer Info
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey[900]!,
                Colors.grey[850]!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[800]!, width: 1),
          ),
          child: Column(
            children: [
              Text(
                'Developed by',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Avishka Dilshan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'VibeFlick Gx Inc.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialSection() {
    return Column(
      children: [
        Text(
          'Connect With Us',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 20),

        // Social Media Icons
        Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: [
            _buildSocialIcon(
              FontAwesomeIcons.globe,
              'Website',
              'https://vibeflick.com',
            ),
            _buildSocialIcon(
              FontAwesomeIcons.facebook,
              'Facebook',
              'https://facebook.com/vibeflick',
            ),
            _buildSocialIcon(
              FontAwesomeIcons.instagram,
              'Instagram',
              'https://instagram.com/vibeflick',
            ),
            _buildSocialIcon(
              FontAwesomeIcons.github,
              'GitHub',
              'https://github.com/vibeflick',
            ),
          ],
        ),

        const SizedBox(height: 30),

        // Contact Email
        GestureDetector(
          onTap: _launchEmail,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.email_outlined,
                  color: Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'officialvibeflickgx@gmail.com',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, String label, String url) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8E2DE2).withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Divider(color: Colors.grey[800], thickness: 1),
        const SizedBox(height: 20),
        Text(
          '© 2026 VibeFlick. All rights reserved.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}