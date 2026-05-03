import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;

class EmojiPickerScreen extends StatefulWidget {
  const EmojiPickerScreen({Key? key}) : super(key: key);

  @override
  State<EmojiPickerScreen> createState() => _EmojiPickerScreenState();
}

class _EmojiPickerScreenState extends State<EmojiPickerScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onEmojiSelected(Emoji emoji) {
    HapticFeedback.selectionClick();
    Navigator.pop(context, emoji.emoji);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: EdgeInsets.only(top: 10, bottom: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Icon(Icons.emoji_emotions_outlined,
                    color: Colors.blue,
                    size: 24),
                SizedBox(width: 10),
                Text(
                  'Pick an Emoji',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close,
                      color: Colors.grey[400],
                      size: 22),
                ),
              ],
            ),
          ),

          // Search Bar (Always Visible)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search emojis...',
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  icon: Icon(Icons.search,
                      color: Colors.grey[600],
                      size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear,
                        color: Colors.grey[600],
                        size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                      : null,
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                onChanged: (value) {
                  setState(() {}); // Update clear button visibility
                },
              ),
            ),
          ),

          Divider(height: 1, color: Colors.grey[800]),

          // Emoji Picker
          Expanded(
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                _onEmojiSelected(emoji);
              },
              textEditingController: _searchController,
              config: Config(
                height: 256,
                checkPlatformCompatibility: true,
                viewOrderConfig: const ViewOrderConfig(
                  top: EmojiPickerItem.categoryBar,
                  middle: EmojiPickerItem.emojiView,
                  bottom: EmojiPickerItem.searchBar, // ← FIXED
                ),
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 32 *
                      (foundation.defaultTargetPlatform == TargetPlatform.iOS
                          ? 1.30
                          : 1.0),
                  verticalSpacing: 0,
                  horizontalSpacing: 0,
                  gridPadding: EdgeInsets.zero,
                  recentsLimit: 28,
                  replaceEmojiOnLimitExceed: false,
                  noRecents: Text(
                    'No recent emojis\nStart using emojis!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  loadingIndicator: const SizedBox.shrink(),
                  columns: 7,
                  buttonMode: ButtonMode.MATERIAL,
                  backgroundColor: Color(0xFF2A2A2A),
                ),
                skinToneConfig: const SkinToneConfig(
                  enabled: true,
                  dialogBackgroundColor: Color(0xFF1E1E1E),
                  indicatorColor: Colors.grey,
                ),
                categoryViewConfig: CategoryViewConfig(
                  tabBarHeight: 46.0,
                  tabIndicatorAnimDuration: Duration(milliseconds: 300),
                  initCategory: Category.RECENT,
                  recentTabBehavior: RecentTabBehavior.RECENT,
                  extraTab: CategoryExtraTab.NONE,
                  backgroundColor: Color(0xFF2A2A2A),
                  indicatorColor: Colors.blue,
                  iconColor: Colors.grey[600]!,
                  iconColorSelected: Colors.blue,
                  backspaceColor: Colors.blue,
                  categoryIcons: const CategoryIcons(
                    recentIcon: Icons.access_time,
                    smileyIcon: Icons.emoji_emotions_outlined,
                    animalIcon: Icons.pets,
                    foodIcon: Icons.fastfood,
                    activityIcon: Icons.sports_soccer,
                    travelIcon: Icons.flight,
                    objectIcon: Icons.lightbulb_outline,
                    symbolIcon: Icons.tag,
                    flagIcon: Icons.flag,
                  ),
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false, // ← This hides the bottom bar
                ),
                searchViewConfig: const SearchViewConfig(),
              ),
            ),
          ),

          // Quick Emoji Reactions (Bottom)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              border: Border(
                top: BorderSide(color: Colors.grey[800]!, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickEmoji('❤️'),
                _buildQuickEmoji('😂'),
                _buildQuickEmoji('😍'),
                _buildQuickEmoji('😮'),
                _buildQuickEmoji('😢'),
                _buildQuickEmoji('🔥'),
                _buildQuickEmoji('👏'),
                _buildQuickEmoji('💯'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickEmoji(String emoji) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context, emoji);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}