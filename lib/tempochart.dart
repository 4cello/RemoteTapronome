import "package:flutter/material.dart";
import 'package:fl_chart/fl_chart.dart';
import 'package:metronome/appstate.dart';
import 'package:provider/provider.dart';

import "globals.dart" as globals;

class TempoChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.read<MetronomeModel>();

    final scoreDots = context
        .select((MetronomeModel m) => m.scoreList)
        .map((p) => FlSpot(p.x.toDouble(), p.y.toDouble()))
        .toList();
    final tempoDots = context
        .select((MetronomeModel m) => m.tempoList)
        .map((p) => FlSpot(p.x.toDouble(), p.y.toDouble()))
        .toList();

    final minX = tempoDots.length <= 1 ? 0 : (tempoDots[1].x - 1);
    final maxX =
        tempoDots.length <= 1 ? 1 : (tempoDots[tempoDots.length - 1].x + 1);
    final tempoChart = LineChart(
      LineChartData(
        minY: 0,
        maxY: 240,
        minX: minX.toDouble(),
        maxX: maxX.toDouble(),
        clipData: FlClipData.horizontal(),
        lineBarsData: [
          tempoLine(context, tempoDots),
          scoreLine(context, scoreDots)
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: state.targetTempo.toDouble(),
              color: state.gameActive ? globals.GAME_COLOR : Colors.transparent,
            )
          ],
          extraLinesOnTop: false,
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text(
              "Seconds",
              style: TextStyle(),
            ),
            sideTitles: SideTitles(showTitles: true),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text(
              "Tempo",
              style: TextStyle(),
            ),
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
        ),
      ),
    );

    final chartStack = Stack(
      children: [
        tempoChart,
        Align(
          alignment: Alignment.topRight,
          child: ElevatedButton(
            onPressed: () {
              context.read<MetronomeModel>().reset();
              scoreDots.clear();
              tempoDots.clear();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Reset Chart'),
          ),
        ),
      ],
    );
    return chartStack;
  }

  LineChartBarData tempoLine(BuildContext context, List<FlSpot> points) {
    final targetTempo = context.select((MetronomeModel m) => m.targetTempo);
    final gameActive = context.select((MetronomeModel m) => m.gameActive);
    final backgroundColor = globals.GAME_COLOR.withAlpha(30);
    return LineChartBarData(
      spots: points,
      dotData: FlDotData(show: false),
      barWidth: 5,
      isCurved: true,
      belowBarData: BarAreaData(
          show: context.read<MetronomeModel>().gameActive,
          color: backgroundColor,
          cutOffY: targetTempo.toDouble(),
          applyCutOffY: gameActive),
      aboveBarData: BarAreaData(
          show: gameActive,
          color: backgroundColor,
          cutOffY: targetTempo.toDouble(),
          applyCutOffY: gameActive),
    );
  }

  LineChartBarData scoreLine(BuildContext context, List<FlSpot> points) {
    final gameActive = context.select((MetronomeModel m) => m.gameActive);
    return LineChartBarData(
      spots: points,
      dotData: FlDotData(show: false),
      color: Colors.yellow,
      barWidth: 5,
      show: gameActive,
    );
  }
}
