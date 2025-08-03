import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:setup/features/energy/controllers/energy_view_model.dart';
import 'package:setup/features/energy/models/energy_point.dart';

class LineChartSample4 extends StatelessWidget {
  final List<EnergyPoint> energyPoints;
  final Color mainLineColor;
  final Color belowLineColor;
  final Color aboveLineColor;

  LineChartSample4({
    super.key,
    required this.energyPoints,
    Color? mainLineColor,
    Color? belowLineColor,
    Color? aboveLineColor,
  }) : mainLineColor = mainLineColor ?? Colors.yellow.withValues(alpha: 1),
       belowLineColor = belowLineColor ?? Colors.white.withValues(alpha: 0.2),
       aboveLineColor = aboveLineColor ?? Colors.purple.withValues(alpha: 0.7);

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    String text;
    switch (value.toInt()) {
      case 0:
        text = 'Morning';
        break;
      case 1:
        text = '';
        break;
      case 2:
        text = 'Noon';
        break;
      case 3:
        text = '';
        break;
      case 4:
        text = 'Evening';
        break;

      default:
        return Container();
    }

    return SideTitleWidget(
      meta: meta,
      space: 2,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: mainLineColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(color: Colors.black, fontSize: 12);
    return SideTitleWidget(
      meta: meta,
      child: Text(value == 0 ? 'Low' : 'Peak', style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    const cutOffYValue = 0.0;

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.only(left: 0, right: 0, top: 22, bottom: 12),
        child: LineChart(
          LineChartData(
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots:
                    energyPoints
                        .map((e) => FlSpot(e.hour.toDouble(), e.energy))
                        .toList(),
                isCurved: true,
                barWidth: 4,
                color: mainLineColor,
                belowBarData: BarAreaData(
                  show: true,
                  color: belowLineColor,
                  cutOffY: cutOffYValue,
                  applyCutOffY: true,
                ),
                aboveBarData: BarAreaData(
                  show: true,
                  color: aboveLineColor,
                  cutOffY: cutOffYValue,
                  applyCutOffY: true,
                ),
                dotData: const FlDotData(show: false),
              ),
            ],
            minY: 0,
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: false,
                  reservedSize: 18,
                  interval: 1,
                  getTitlesWidget: bottomTitleWidgets,
                ),
              ),
              leftTitles: AxisTitles(
                axisNameSize: 10,
                axisNameWidget: const Text(
                  'Value',
                  style: TextStyle(color: Colors.white),
                ),
                sideTitles: SideTitles(
                  showTitles: false,
                  interval: 4,
                  reservedSize: 40,
                  getTitlesWidget: leftTitleWidgets,
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.symmetric(
                horizontal: BorderSide(color: Colors.black, width: 1),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              checkToShowHorizontalLine: (double value) {
                return value == 3 || value == 2 || value == 1;
              },
            ),
          ),
        ),
      ),
    );
  }
}
