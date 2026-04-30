import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../models/earnings_data.dart';

/// Weekly earnings bar chart widget with animated bars and touch tooltips
class WeeklyChart extends StatefulWidget {
  final List<DailyEarnings> data;

  const WeeklyChart({super.key, required this.data});

  @override
  State<WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<WeeklyChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _barAnimation;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppConstants.durationLong,
    );
    _barAnimation = CurvedAnimation(
      parent: _animController,
      curve: AppConstants.curveEnter,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppConstants.borderRadiusXL,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Breakdown',
                style: AppTypography.titleStyle(
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.goldenMustard.withValues(alpha: 0.1),
                  borderRadius: AppConstants.borderRadiusCircular,
                ),
                child: Text(
                  'This Week',
                  style: AppTypography.captionStyle(
                    color: AppColors.goldenMustard,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart
          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _barAnimation,
              builder: (context, child) {
                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxY(),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchCallback: (event, response) {
                        setState(() {
                          if (response == null ||
                              response.spot == null ||
                              event is! FlTapUpEvent) {
                            _touchedIndex = -1;
                          } else {
                            _touchedIndex =
                                response.spot!.touchedBarGroupIndex;
                          }
                        });
                      },
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: isDark
                            ? AppColors.darkSurface
                            : Colors.white,
                        tooltipRoundedRadius: 10,
                        tooltipBorder: BorderSide(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderSubtle,
                        ),
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '₹${rod.toY.toInt()}',
                            AppTypography.bodyStyle(
                              color: AppColors.goldenMustard,
                              weight: FontWeight.w700,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 &&
                                value.toInt() < widget.data.length) {
                              final isToday =
                                  value.toInt() == widget.data.length - 1;
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  widget.data[value.toInt()].day,
                                  style: AppTypography.captionStyle(
                                    color: isToday
                                        ? AppColors.emeraldGreen
                                        : (isDark
                                            ? AppColors.textLightSecondary
                                            : AppColors.textSecondary),
                                    weight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _getMaxY() / 4,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.05),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: _buildBarGroups(isDark),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxY() {
    double max = 0;
    for (var item in widget.data) {
      if (item.amount > max) max = item.amount;
    }
    return max == 0 ? 100 : (max * 1.3).ceilToDouble();
  }

  List<BarChartGroupData> _buildBarGroups(bool isDark) {
    return List.generate(widget.data.length, (index) {
      final isToday = index == widget.data.length - 1;
      final isTouched = index == _touchedIndex;
      final animatedValue = widget.data[index].amount * _barAnimation.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: animatedValue,
            width: isTouched ? 28 : 22,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(8),
            ),
            gradient: isToday
                ? const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFF2da832),
                      Color(0xFF4CAF50),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.goldenMustard
                          .withValues(alpha: isTouched ? 1.0 : 0.7),
                      AppColors.goldenMustard
                          .withValues(alpha: isTouched ? 0.8 : 0.5),
                    ],
                  ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _getMaxY(),
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.04),
            ),
          ),
        ],
      );
    });
  }
}
