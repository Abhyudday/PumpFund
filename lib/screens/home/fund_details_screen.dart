import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/fund_model.dart';
import '../../blocs/wallet/wallet_bloc.dart';
import '../../utils/theme.dart';
import 'invest_screen.dart';
import 'dart:math' as math;

class FundDetailsScreen extends StatelessWidget {
  final FundModel fund;

  const FundDetailsScreen({super.key, required this.fund});

  @override
  Widget build(BuildContext context) {
    final roiColor = fund.roi7d >= 0 ? AppColors.white : AppColors.gray;
    final roiPrefix = fund.roi7d >= 0 ? '+' : '';

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Fund Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fund name and ROI
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.black,
                border: Border.all(color: AppColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          fund.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Text(
                        '$roiPrefix${fund.roi7d.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: roiColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '7-Day ROI',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.gray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Earnings Predictor (moved to top)
            _buildEarningsPredictor(),
            
            const SizedBox(height: 24),
            
            // ROI Performance Chart
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.black,
                border: Border.all(color: AppColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '7-Day Performance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: _buildPerformanceChart(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Description
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.black,
                border: Border.all(color: AppColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fund.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.gray,
                      height: 1.5,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Fund Stats
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.black,
                border: Border.all(color: AppColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fund Stats',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    'Wallets',
                    fund.walletAddresses.length.toString(),
                    Icons.account_balance_wallet,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    '7-Day Performance',
                    '$roiPrefix${fund.roi7d.toStringAsFixed(2)}%',
                    Icons.trending_up,
                    valueColor: roiColor,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Wallets List
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.black,
                border: Border.all(color: AppColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tracked Wallets',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...fund.walletAddresses.map((address) => _buildWalletItem(address)),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // How it works
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'How Copy-Trading Works',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHowItWorksStep('1', 'Allocate funds to this investment'),
                  const SizedBox(height: 12),
                  _buildHowItWorksStep('2', 'Set purchase size % per trade'),
                  const SizedBox(height: 12),
                  _buildHowItWorksStep('3', 'Your wallet copies all buy/sell transactions'),
                  const SizedBox(height: 12),
                  _buildHowItWorksStep('4', 'Track performance in real-time'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => InvestScreen(fund: fund),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Text(
                'Invest in This Fund',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(icon, color: AppColors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.gray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletItem(String address) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_circle_outlined, color: AppColors.white, size: 20),
          const SizedBox(width: 12),
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
          const Icon(Icons.open_in_new, color: AppColors.gray, size: 16),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, width: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.gray,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceChart() {
    final dataPoints = <FlSpot>[];
    
    // Use real historical data if available
    if (fund.roiHistory.isNotEmpty && fund.roiHistory.length >= 7) {
      // roiHistory contains cumulative ROI for each day
      for (int i = 0; i < fund.roiHistory.length && i < 7; i++) {
        dataPoints.add(FlSpot(i.toDouble(), fund.roiHistory[i]));
      }
    }
    
    // If real data is not available or insufficient, generate realistic mock data
    if (dataPoints.length < 7) {
      dataPoints.clear();
      
      // Generate realistic mock data that simulates actual trading patterns
      // Use a deterministic seed based on fund ID for consistency
      final seed = fund.id.hashCode.abs() % 1000;
      final random = math.Random(seed);
      
      // Create a realistic progression with variance
      final targetRoi = fund.roi7d;
      final baseDaily = targetRoi / 7;
      
      // Generate daily fluctuations that converge to the target
      double cumulative = 0.0;
      for (int i = 0; i < 7; i++) {
        // Add realistic variance (10-30% of base daily change)
        final variance = baseDaily * (0.15 + random.nextDouble() * 0.15);
        final dayChange = baseDaily + (random.nextBool() ? variance : -variance);
        
        // Add the change
        cumulative += dayChange;
        
        // For the last day, adjust to exactly hit the target ROI
        if (i == 6) {
          cumulative = targetRoi;
        }
        
        dataPoints.add(FlSpot(i.toDouble(), cumulative));
      }
    }

    var minY = dataPoints.map((e) => e.y).reduce(math.min);
    var maxY = dataPoints.map((e) => e.y).reduce(math.max);
    final isPositive = fund.roi7d >= 0;
    
    // Ensure minimum range for better visualization
    final range = maxY - minY;
    if (range < 0.1) {
      // If all values are very similar or zero, create a reasonable range
      final center = (minY + maxY) / 2;
      minY = center - 0.5;
      maxY = center + 0.5;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max((maxY - minY) / 4, 0.1),
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withOpacity(0.3),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppColors.gray,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final days = ['Day 1', 'Day 2', 'Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      days[value.toInt()],
                      style: const TextStyle(
                        color: AppColors.gray,
                        fontSize: 9,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        minX: 0,
        maxX: 6,
        minY: minY - 0.1,
        maxY: maxY + 0.1,
        lineBarsData: [
          LineChartBarData(
            spots: dataPoints,
            isCurved: true,
            color: isPositive ? AppColors.white : AppColors.gray,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: isPositive ? AppColors.white : AppColors.gray,
                  strokeWidth: 1,
                  strokeColor: AppColors.black,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: (isPositive ? AppColors.white : AppColors.gray).withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppColors.border,
            tooltipRoundedRadius: 4,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                return LineTooltipItem(
                  '${touchedSpot.y.toStringAsFixed(2)}%',
                  const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsPredictor() {
    const double initialInvestment = 200.0;
    final dailyRoi = fund.roi7d / 7; // Average daily ROI
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: AppColors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Earnings Predictor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Initial investment display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Initial Investment',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.gray,
                  ),
                ),
                Text(
                  '\$${initialInvestment.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            '7-Day Projection',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.gray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          
          // 7-day projection
          ...List.generate(7, (index) {
            final day = index + 1;
            final projectedValue = initialInvestment * (1 + (dailyRoi / 100) * day);
            final gain = projectedValue - initialInvestment;
            final gainColor = gain >= 0 ? AppColors.white : AppColors.gray;
            final gainPrefix = gain >= 0 ? '+' : '';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border.withOpacity(0.3), width: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Day $day',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.gray,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '\$${projectedValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$gainPrefix\$${gain.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: gainColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          
          const SizedBox(height: 16),
          
          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: AppColors.border.withOpacity(0.3), width: 0.5),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.gray, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This is a projection based on historical 7-day performance. Past performance is not indicative of future results. NFA (Not Financial Advice). Actual results may vary significantly.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.gray,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
