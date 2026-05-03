import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityAnalytics extends StatefulWidget {
  const ActivityAnalytics({Key? key}) : super(key: key);

  @override
  State<ActivityAnalytics> createState() => _ActivityAnalyticsState();
}

class _ActivityAnalyticsState extends State<ActivityAnalytics>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _analyticsEnabled = false;
  bool _isLoading = false;

  // Analytics data
  int _totalViews = 0;
  int _totalLikes = 0;
  int _totalComments = 0;
  int _viralVideos = 0;
  int _malePercentage = 50;
  int _femalePercentage = 50;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadAnalyticsPreference();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsPreference() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final doc = await _db.collection('users').doc(currentUser.uid).get();
      if (doc.exists) {
        final enabled = doc.data()?['analytics_enabled'] ?? false;
        setState(() {
          _analyticsEnabled = enabled;
        });
        if (enabled) {
          _loadAnalyticsData();
        }
      }
    } catch (e) {
      debugPrint('Error loading analytics preference: $e');
    }
  }

  Future<void> _handleAnalyticsToggle(bool value) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      await _db.collection('users').doc(currentUser.uid).update({
        'analytics_enabled': value,
        'analytics_enabled_date': FieldValue.serverTimestamp(),
      });

      setState(() {
        _analyticsEnabled = value;
        _isLoading = false;
      });

      if (value) {
        _animationController.forward();
        await _loadAnalyticsData();
      } else {
        _animationController.reverse();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Analytics enabled' : 'Analytics disabled'),
          backgroundColor: value ? Colors.green : Colors.grey,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating analytics')),
      );
    }
  }

  Future<void> _loadAnalyticsData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      // Simulate loading analytics data
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _totalViews = 125430;
        _totalLikes = 8542;
        _totalComments = 1234;
        _viralVideos = 3;
        _malePercentage = 45;
        _femalePercentage = 55;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading analytics data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildAnalyticsToggle(),
                if (_analyticsEnabled) ...[
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(50),
                      child: CircularProgressIndicator(),
                    )
                  else
                    _buildAnalyticsContent(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF0F0F0F),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Analytics',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildAnalyticsToggle() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B4CE6), Color(0xFF9B59D0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track your performance metrics',
                  style: TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _analyticsEnabled,
            onChanged: _handleAnalyticsToggle,
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return FadeTransition(
      opacity: _animationController,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 20),
            _buildWeeklyChart(),
            const SizedBox(height: 20),
            _buildGenderChart(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard('Total Views', _totalViews, Icons.visibility,
            const Color(0xFF6B4CE6)),
        _buildStatCard('Total Likes', _totalLikes, Icons.favorite,
            const Color(0xFFEC4899)),
        _buildStatCard('Comments', _totalComments, Icons.comment,
            const Color(0xFF3B82F6)),
        _buildStatCard('Viral Videos', _viralVideos, Icons.rocket_launch,
            const Color(0xFFF59E0B)),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatNumber(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Views',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1000,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFF2A2A2A),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              days[value.toInt()],
                              style: const TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${(value / 1000).toStringAsFixed(0)}K',
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 5000,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 2500),
                      const FlSpot(1, 3200),
                      const FlSpot(2, 2800),
                      const FlSpot(3, 4100),
                      const FlSpot(4, 3500),
                      const FlSpot(5, 4500),
                      const FlSpot(6, 3800),
                    ],
                    isCurved: true,
                    color: const Color(0xFF6B4CE6),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF6B4CE6).withOpacity(0.1),
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

  Widget _buildGenderChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audience Demographics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: [
                        PieChartSectionData(
                          color: const Color(0xFF3B82F6),
                          value: _malePercentage.toDouble(),
                          title: '$_malePercentage%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: const Color(0xFFEC4899),
                          value: _femalePercentage.toDouble(),
                          title: '$_femalePercentage%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem('Male', const Color(0xFF3B82F6), _malePercentage),
                  const SizedBox(height: 12),
                  _buildLegendItem('Female', const Color(0xFFEC4899), _femalePercentage),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int percentage) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$percentage%',
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}