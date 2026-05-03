import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BirthdayEditScreen extends StatefulWidget {
  final String currentBirthday;

  const BirthdayEditScreen({
    super.key,
    required this.currentBirthday,
  });

  @override
  State<BirthdayEditScreen> createState() => _BirthdayEditScreenState();
}

class _BirthdayEditScreenState extends State<BirthdayEditScreen> {
  bool isSaving = false;
  bool showBirthdayTag = true;
  bool showAge = true;
  bool _pickerVisible = false;

  late int selectedYear;
  late int selectedMonth;
  late int selectedDay;

  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<int> years =
  List.generate(DateTime.now().year - 1900 + 1, (i) => DateTime.now().year - i);
  final List<int> months = List.generate(12, (i) => i + 1);

  List<int> get days {
    final count = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
    return List.generate(count, (i) => i + 1);
  }

  @override
  void initState() {
    super.initState();
    _parseBirthday(widget.currentBirthday);
    _initControllers();
    _loadSettings();
  }

  void _parseBirthday(String birthday) {
    try {
      final parts = birthday.split('-');
      if (parts.length == 3) {
        selectedYear = int.parse(parts[0]);
        selectedMonth = int.parse(parts[1]);
        selectedDay = int.parse(parts[2]);
        return;
      }
    } catch (_) {}
    selectedYear = 1999;
    selectedMonth = 9;
    selectedDay = 19;
  }

  void _initControllers() {
    final yi = years.indexOf(selectedYear);
    _yearController = FixedExtentScrollController(initialItem: yi < 0 ? 0 : yi);
    _monthController = FixedExtentScrollController(initialItem: selectedMonth - 1);
    _dayController = FixedExtentScrollController(initialItem: selectedDay - 1);
  }

  Future<void> _loadSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final d = doc.data()!;
        setState(() {
          showBirthdayTag = d['show_birthday_tag'] ?? true;
          showAge = d['show_age'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading birthday settings: $e');
    }
  }

  String get formattedBirthday {
    final m = selectedMonth.toString().padLeft(2, '0');
    final d = selectedDay.toString().padLeft(2, '0');
    return '$selectedYear-$m-$d';
  }

  Future<void> _handleSave() async {
    final user = _auth.currentUser;
    if (user == null) return;
    HapticFeedback.mediumImpact();
    setState(() => isSaving = true);
    try {
      // ✅ Firestore users collection එකෙ birthday, show_birthday_tag, show_age save වෙනවා
      await _firestore.collection('users').doc(user.uid).update({
        'birthday': formattedBirthday,
        'show_birthday_tag': showBirthdayTag,
        'show_age': showAge,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, formattedBirthday);
    } catch (e) {
      debugPrint('Error saving birthday: $e');
      if (mounted) {
        _showError('Failed to save birthday');
        setState(() => isSaving = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: const Color(0xFFE53935),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBirthdayCard(),
                        _buildSectionHeader('Display on profile'),
                        _buildDisplayCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_pickerVisible) _buildPickerOverlay(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 24, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  padding: const EdgeInsets.all(4),
                ),
                const Expanded(
                  child: Text(
                    'Edit birthday',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: isSaving
                      ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFFF3B5C)),
                    ),
                  )
                      : TextButton(
                    onPressed: _handleSave,
                    child: const Text('Save',
                        style: TextStyle(
                            color: Color(0xFFFF3B5C),
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
            color: Color(0xFF888888), fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildBirthdayCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _pickerVisible = true);
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                const Text('Birthday',
                    style: TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(formattedBirthday,
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 15)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Color(0xFF888888), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Show birthday tag – toggle switch
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Text('Show birthday tag',
                    style: TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => showBirthdayTag = !showBirthdayTag);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 52,
                    height: 32,
                    decoration: BoxDecoration(
                      color: showBirthdayTag
                          ? const Color(0xFFFF3B5C)
                          : const Color(0xFF3A3A3A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: showBirthdayTag
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildDivider(),
          // Show age – checkmark
          _buildCheckRow(
              label: 'Show age',
              selected: showAge,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => showAge = !showAge);
              }),
        ],
      ),
    );
  }

  Widget _buildCheckRow(
      {required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            const Spacer(),
            if (selected)
              const Icon(Icons.check, color: Color(0xFFFF3B5C), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 1,
        color: const Color(0xFF2C2C2C));
  }

  Widget _buildPickerOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _pickerVisible = false),
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _pickerVisible = false);
                            },
                            child: const Text('Cancel',
                                style: TextStyle(color: Color(0xFF888888), fontSize: 16)),
                          ),
                          const Expanded(
                            child: Text('Select birth date',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final maxDay = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
                              if (selectedDay > maxDay) {
                                setState(() => selectedDay = maxDay);
                              }
                              setState(() => _pickerVisible = false);
                            },
                            child: const Text('Save',
                                style: TextStyle(
                                    color: Color(0xFFFF3B5C),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 220,
                      child: Stack(
                        children: [
                          Center(
                            child: Container(
                              height: 44,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2C),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildWheel(
                                  controller: _yearController,
                                  items: years,
                                  onChanged: (i) => setState(() => selectedYear = years[i]),
                                  label: (v) => v.toString(),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: _buildWheel(
                                  controller: _monthController,
                                  items: months,
                                  onChanged: (i) {
                                    setState(() => selectedMonth = months[i]);
                                    final max = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
                                    if (selectedDay > max) {
                                      setState(() => selectedDay = max);
                                      _dayController.jumpToItem(max - 1);
                                    }
                                  },
                                  label: (v) => v.toString().padLeft(2, '0'),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: _buildWheel(
                                  controller: _dayController,
                                  items: days,
                                  onChanged: (i) => setState(() => selectedDay = days[i]),
                                  label: (v) => v.toString().padLeft(2, '0'),
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 0, left: 0, right: 0, height: 72,
                            child: IgnorePointer(
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFF1A1A1A), Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0, left: 0, right: 0, height: 72,
                            child: IgnorePointer(
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Color(0xFF1A1A1A), Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWheel<T>({
    required FixedExtentScrollController controller,
    required List<T> items,
    required void Function(int) onChanged,
    required String Function(T) label,
  }) {
    return NotificationListener<ScrollNotification>(
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 44,
        perspective: 0.003,
        diameterRatio: 2.5,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: items.length,
          builder: (context, index) {
            final sel = controller.selectedItem == index;
            return Center(
              child: Text(
                label(items[index]),
                style: TextStyle(
                  color: sel ? Colors.white : const Color(0xFF4A4A4A),
                  fontSize: sel ? 22 : 17,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}