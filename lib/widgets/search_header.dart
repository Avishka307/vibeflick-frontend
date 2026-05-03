import 'package:flutter/material.dart';

class SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;
  final VoidCallback onVoiceSearch;
  final Function(String) onSubmitted;

  const SearchHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onClear,
    required this.onVoiceSearch,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16, right: 8),
                    child: Icon(
                      Icons.search_rounded,
                      color: Color(0xFF5F6368),
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onSubmitted: onSubmitted,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search videos or creators...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9AA0A6),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: controller.text.isNotEmpty
                        ? IconButton(
                      key: const ValueKey('clear'),
                      icon: const Icon(Icons.close_rounded),
                      iconSize: 20,
                      color: const Color(0xFF5F6368),
                      onPressed: onClear,
                      splashRadius: 20,
                    )
                        : const SizedBox.shrink(),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: const Icon(Icons.mic_rounded),
                      iconSize: 22,
                      color: const Color(0xFF5F6368),
                      onPressed: onVoiceSearch,
                      splashRadius: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}