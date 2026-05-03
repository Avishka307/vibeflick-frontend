import 'package:flutter/material.dart';

class SearchSuggestions extends StatelessWidget {
  final String query;
  final Function(String) onSuggestionTap;

  const SearchSuggestions({
    super.key,
    required this.query,
    required this.onSuggestionTap,
  });

  List<Map<String, dynamic>> _getSuggestions() {
    // Real API integration එකක් යන්නේ මෙතනට
    final allSuggestions = [
      {
        'text': 'dance challenge',
        'type': 'hashtag',
        'users': ['@kasunp', '@nimalis']
      },
      {
        'text': 'dance moves',
        'type': 'video',
        'users': ['@ravindu', '@sachinid']
      },
      {'text': 'dance tutorial', 'type': 'video', 'users': ['@kasunp']},
      {'text': 'cooking tips', 'type': 'hashtag', 'users': ['@nimalis']},
      {'text': 'comedy skits', 'type': 'video', 'users': ['@ravindu']},
      {
        'text': 'travel vlog',
        'type': 'video',
        'users': ['@sachinid', '@kasunp']
      },
      {'text': 'fitness workout', 'type': 'hashtag', 'users': ['@nimalis']},
    ];

    if (query.isEmpty) return [];

    return allSuggestions
        .where((s) => s['text'].toString().toLowerCase().contains(
      query.toLowerCase(),
    ))
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _getSuggestions();

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return _SuggestionItem(
                  suggestion: suggestion,
                  query: query,
                  onTap: () => onSuggestionTap(suggestion['text']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionItem extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final String query;
  final VoidCallback onTap;

  const _SuggestionItem({
    required this.suggestion,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = suggestion['text'] as String;
    final type = suggestion['type'] as String;
    final users = suggestion['users'] as List<dynamic>;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              type == 'hashtag' ? Icons.tag_rounded : Icons.search_rounded,
              color: const Color(0xFF5F6368),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      children: _highlightQuery(text, query),
                    ),
                  ),
                  if (users.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0050).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            users.first,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF0050),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (users.length > 1) ...[
                          const SizedBox(width: 6),
                          Text(
                            '+${users.length - 1} more',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.north_west_rounded,
              color: Colors.black.withOpacity(0.3),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _highlightQuery(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return [TextSpan(text: text)];
    }

    return [
      if (index > 0) TextSpan(text: text.substring(0, index)),
      TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      if (index + query.length < text.length)
        TextSpan(text: text.substring(index + query.length)),
    ];
  }
}