import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SearchInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;
  final VoidCallback onVoiceSearch;
  final Function(String) onSubmitted;

  const SearchInputField({
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Search Field
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: focusNode.hasFocus
                      ? const Color(0xFFFF0050)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: SvgPicture.asset(
                      'assets/images/search_icon.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        Colors.white.withOpacity(0.6),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onSubmitted: onSubmitted,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search videos or creators...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                      color: Colors.white.withOpacity(0.6),
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
                      color: Colors.white.withOpacity(0.6),
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