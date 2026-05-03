import 'package:flutter/material.dart';

class SoundsSearchTab extends StatelessWidget {
  final String query;
  const SoundsSearchTab({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.music_note_rounded,
                  size: 40, color: Colors.white.withOpacity(0.2)),
            ),
            const SizedBox(height: 18),
            const Text('Sounds',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text('Sound search coming soon',
                style:
                TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.35))),
          ],
        ),
      ),
    );
  }
}