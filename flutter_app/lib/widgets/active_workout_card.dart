import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ActiveWorkoutCard extends StatefulWidget {
  const ActiveWorkoutCard({super.key});

  @override
  State<ActiveWorkoutCard> createState() => _ActiveWorkoutCardState();
}

class _ActiveWorkoutCardState extends State<ActiveWorkoutCard> {
  Timer? _timer;
  double _phase = 0;
  double _heartRate = 78;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      setState(() {
        _phase += 0.4;
        _heartRate = 70 + (sin(_phase) * 20) + 15;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientForHr(_heartRate);
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: Colors.white10,
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Workout', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            barWidth: 3,
                            color: const Color(0xFFCCFF00),
                            spots: [
                              FlSpot(0, _heartRate - 12),
                              FlSpot(1, _heartRate - 5),
                              FlSpot(2, _heartRate + 2),
                              FlSpot(3, _heartRate + 8),
                              FlSpot(4, _heartRate - 4),
                              FlSpot(5, _heartRate + 5),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCCFF00), width: 2),
                  color: Colors.black54,
                ),
                child: const Icon(Icons.check, size: 36),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6200EA), width: 1),
              ),
              child: Text('HR ${_heartRate.toStringAsFixed(0)} bpm'),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _gradientForHr(double hr) {
    if (hr < 90) {
      return const [Color(0xFF14202B), Color(0xFF0F141A)];
    }
    if (hr < 120) {
      return const [Color(0xFF1E1C2D), Color(0xFF0F141A)];
    }
    return const [Color(0xFF3A1B1B), Color(0xFF120F12)];
  }
}
