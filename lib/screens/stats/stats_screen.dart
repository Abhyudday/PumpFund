import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Stats & Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Algo Stats
            const Text(
              'Algo Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(child: _buildStatBox('Average ROI', '+24.5%', Icons.trending_up)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatBox('Tokens Found', '127', Icons.token)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatBox('Win Rate', '68%', Icons.verified)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatBox('Total Trades', '342', Icons.swap_horiz)),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Performance Chart
            const Text(
              '7-Day Performance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              height: 250,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: _buildPerformanceChart(),
            ),
            
            const SizedBox(height: 32),
            
            // Top Performing Wallets
            const Text(
              'Top Performing Wallets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildWalletLeaderboard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.white, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.gray,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.divider,
              strokeWidth: 0.5,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      days[value.toInt()],
                      style: const TextStyle(
                        color: AppColors.gray,
                        fontSize: 10,
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
              interval: 10,
              reservedSize: 40,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(
                    color: AppColors.gray,
                    fontSize: 10,
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
        maxY: 30,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 8),
              FlSpot(1, 12),
              FlSpot(2, 15),
              FlSpot(3, 18),
              FlSpot(4, 20),
              FlSpot(5, 22),
              FlSpot(6, 25),
            ],
            isCurved: true,
            color: AppColors.white,
            barWidth: 1.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.white,
                  strokeWidth: 1,
                  strokeColor: AppColors.black,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletLeaderboard() {
    final wallets = [
      {'address': '7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs', 'roi': 45.2},
      {'address': 'A8KqpzQjuGdJsFHJk9WZGpdJPNdkSsrXnEm8tVUKTfUZ', 'roi': 38.7},
      {'address': 'HN7cABqLq46Es1jh92dQQisAq662SmxELLLsHHe4YWrH', 'roi': 32.1},
      {'address': '9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM', 'roi': 28.5},
      {'address': 'GDfnEsia2WLAW5t8yx2X5j2mkfA74i6JxqQDJk3FjjKKp', 'roi': 24.3},
    ];

    return Column(
      children: wallets.asMap().entries.map((entry) {
        final index = entry.key;
        final wallet = entry.value;
        return _buildWalletItem(
          index + 1,
          wallet['address'] as String,
          wallet['roi'] as double,
        );
      }).toList(),
    );
  }

  Widget _buildWalletItem(int rank, String address, double roi) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: rank == 1 ? AppColors.white : AppColors.border,
          width: rank == 1 ? 1 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(
                color: rank <= 3 ? AppColors.white : AppColors.border,
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: rank <= 3 ? AppColors.white : AppColors.gray,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${address.substring(0, 8)}...${address.substring(address.length - 8)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.white,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Text(
            '+${roi.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
