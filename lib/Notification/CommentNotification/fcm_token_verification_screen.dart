import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// 🔍 FCM Token Verification Widget
// Use this to check if tokens are properly saved in Firestore

class FCMTokenVerificationScreen extends StatefulWidget {
  const FCMTokenVerificationScreen({Key? key}) : super(key: key);

  @override
  State<FCMTokenVerificationScreen> createState() =>
      _FCMTokenVerificationScreenState();
}

class _FCMTokenVerificationScreenState
    extends State<FCMTokenVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String _status = 'Not checked';
  String _currentToken = '';
  String _firestoreToken = '';
  bool _tokensMatch = false;
  bool _isLoading = false;

  get _forceUpdateToken => null;
  get _checkTokens => null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM Token Verification'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.blue.shade700,
                      size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FCM Token Checker',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Verify your notification setup',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // User Info
            _buildInfoCard(
              'Current User',
              _auth.currentUser?.uid ?? 'Not logged in',
              Icons.person,
              Colors.green,
            ),

            const SizedBox(height: 16),

            // Status
            _buildStatusCard(),

            const SizedBox(height: 16),

            // Current Token
            if (_currentToken.isNotEmpty) ...[
              _buildTokenCard(
                'Device FCM Token',
                _currentToken,
                Icons.phone_android,
                Colors.blue,
              ),
              const SizedBox(height: 16),
            ],

            // Firestore Token
            if (_firestoreToken.isNotEmpty) ...[
              _buildTokenCard(
                'Firestore Saved Token',
                _firestoreToken,
                Icons.cloud,
                Colors.purple,
              ),
              const SizedBox(height: 16),
            ],

            // Match Status
            if (_currentToken.isNotEmpty && _firestoreToken.isNotEmpty) ...[
              _buildMatchCard(),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            _buildActionButtons(),

            const SizedBox(height: 24),

            // Instructions
            _buildInstructionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon,
      Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;

    if (_status.contains('✅')) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (_status.contains('❌')) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _status,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: statusColor == Colors.green
                    ? Colors.green.shade900
                    : statusColor == Colors.red
                    ? Colors.red.shade900
                    : Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenCard(String title, String token, IconData icon,
      Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color == Colors.blue
                      ? Colors.blue.shade900
                      : Colors.purple.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              token,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Length: ${token.length} characters',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _tokensMatch ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _tokensMatch ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _tokensMatch ? Icons.check_circle : Icons.warning,
            color: _tokensMatch ? Colors.green : Colors.red,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tokensMatch ? 'Tokens Match! ✅' : 'Tokens Mismatch! ❌',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _tokensMatch ? Colors.green.shade900 : Colors.red
                        .shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _tokensMatch
                      ? 'Your device token is correctly saved in Firestore'
                      : 'Device token does not match Firestore. Update needed!',
                  style: TextStyle(
                    fontSize: 12,
                    color: _tokensMatch ? Colors.green.shade700 : Colors.red
                        .shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _checkTokens,
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.search),
            label: Text(_isLoading ? 'Checking...' : 'Check Tokens'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _forceUpdateToken,
            icon: const Icon(Icons.refresh),
            label: const Text('Force Update Token'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'How to Fix Issues',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionItem('1', 'Press "Check Tokens" to verify setup'),
          _buildInstructionItem(
              '2', 'If tokens don\'t match, press "Force Update"'),
          _buildInstructionItem('3', 'Logout and login again to refresh token'),
          _buildInstructionItem(
              '4', 'Make sure FCMService is initialized in main.dart'),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}