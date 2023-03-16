import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
//import 'package:flutter_number_picker/flutter_number_picker.dart';
//import 'package:flutter/rendering.dart' show debugPaintSizeEnabled;

void main() {
  //debugPaintSizeEnabled = true;
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _tempo = 120;
  int _lastTapMS = 0;
  int _beatMS = 500;
  late int _resetMS;

  int _tapsInChain = 0;
  final List<int> _tapDurations = [0, 0, 0, 0, 0];
  int _tapDurationIndex = 0;
  bool _lastTapSkipped = false;

  bool _metroRunning = false;
  int _metroBeats = 4;
  int _currentBeat = 1;

  int _targetTempo = 120;
  bool _gameActive = false;
  double _gameScore = 100;
  String _gameDescription = "";
  double _lastArea = 0;
  final scoreDots = <FlSpot>[FlSpot.nullSpot];

  Timer metroTimer = Timer(Duration(milliseconds: 0), () => {});

  late DateTime chartStart = DateTime.now();

  final tempoDots = <FlSpot>[FlSpot.nullSpot];

  final SKIPPED_TAP_THRESHOLD_LOW = 1.75;
  final SKIPPED_TAP_THRESHOLD_HIGH = 2.75;
  final MS_UNTIL_CHAIN_RESET = 2000;
  final CHART_VIEWPORT_MAXWIDTH = 60; // in seconds
  final GAME_COLOR = Colors.red;
  final GOOD_THRESHOLD = 5.0;
  final GOOD_REWARD = 3;
  final CLOSE_THRESHOLD = 8.0;
  final CLOSE_PENALTY = 5;
  final BAD_THRESHOLD = 12.0;
  final BAD_PENALTY = 10.0;
  final HORRIBLE_FACTOR = 1.0;
  final RAMPUP_TAPS = 8;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _resetMS = now.millisecondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context) {
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
        lineBarsData: [tempoLine(tempoDots), scoreLine(scoreDots)],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: _targetTempo.toDouble(),
              color: _gameActive ? GAME_COLOR : Colors.transparent,
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
            onPressed: resetChart,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Reset Chart'),
          ),
        ),
      ],
    );

    final tempoCore = Column(
      children: [
        Row(
          children: [
            OutlinedButton(
              onPressed: () =>
                  setState(() => _metroBeats = max(1, _metroBeats - 1)),
              child: const Text("-"),
            ),
            for (int i = 0; i < _metroBeats; i++)
              Icon(
                Icons.circle,
                color: (i + 1 == _currentBeat)
                    ? Colors.red
                    : Colors.lightBlueAccent,
              ),
            OutlinedButton(
              onPressed: () => setState(() => _metroBeats++),
              child: const Text("+"),
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => toggleMetronome(),
              style: ButtonStyle(
                  backgroundColor: MaterialStatePropertyAll(
                      _metroRunning ? Colors.red : Colors.green),
                  shape: MaterialStatePropertyAll(CircleBorder()),
                  iconSize: MaterialStatePropertyAll(30)),
              child: _metroRunning
                  ? const Icon(
                      Icons.stop,
                    )
                  : const Icon(
                      Icons.play_arrow,
                    ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          setState(() => _tempo = max(40, _tempo - 1)),
                      child: const Text("-"),
                    ),
                    Text(
                      '$_tempo',
                      style: const TextStyle(fontSize: 60),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          setState(() => _tempo = min(300, _tempo + 1)),
                      child: const Text("+"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _tapped,
                  child: const Text('Tap Tempo or press any key'),
                ),
              ],
            ),
            ElevatedButton(
                onPressed: () {
                  setState(() {
                    _gameActive = !_gameActive;
                    _targetTempo = _tempo;
                  });
                },
                style: ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll(
                        _gameActive ? Colors.red : Colors.grey),
                    shape: MaterialStatePropertyAll(CircleBorder()),
                    iconSize: MaterialStatePropertyAll(30)),
                child: const Icon(Icons.sports_esports)),
          ],
        )
      ],
    );

    final gameSection = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          children: [
            Visibility(
              visible: _gameActive,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Row(
                children: [
                  Text(
                    "Target: $_targetTempo",
                    style: const TextStyle(fontSize: 20),
                  ),
                  /*CustomNumberPicker(
                    onValue: (num v) =>
                        setState(() => _targetTempo = v.toInt()),
                    initialValue: _targetTempo,
                    maxValue: 300,
                    minValue: 40,
                    step: 1,
                  ),*/
                  const SizedBox(width: 20),
                  Text(
                    "Score: $_gameScore",
                    style: const TextStyle(fontSize: 20),
                  ),
                  Text(
                    "$_gameDescription ($_lastArea)",
                  ),
                ],
              ),
            )
          ],
        ),
      ],
    );

    final app = MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Metronome App'),
        ),
        body: LayoutBuilder(builder: (ctx, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                tempoCore,
                SizedBox(
                  width: constraints.maxWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AspectRatio(aspectRatio: 1.5, child: chartStack),
                  ),
                ),
                gameSection,
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  tempoCore,
                  SizedBox(
                    width: 600,
                    child: AspectRatio(aspectRatio: 1.5, child: chartStack),
                  ),
                  gameSection
                ],
              ),
            ],
          );
        }),
      ),
    );

    return Focus(
      autofocus: true,
      child: RawKeyboardListener(
          focusNode: FocusNode(),
          onKey: (RawKeyEvent event) {
            if (event is RawKeyDownEvent) {
              if (event.repeat) {
                resetChart();
              } else {
                _tapped();
              }
            }
          },
          child: app),
    );
  }

  void nextBeat() {
    final millis = 60000 / _tempo;
    final newTimer =
        Timer(Duration(milliseconds: millis.toInt()), () => nextBeat());
    setState(() {
      _currentBeat = _currentBeat % _metroBeats + 1;
      metroTimer = newTimer;
    });
  }

  void toggleMetronome() {
    setState(() {
      _metroRunning = !_metroRunning;
    });
    if (_metroRunning) {
      nextBeat();
    } else {
      metroTimer.cancel();
      setState(() {
        _currentBeat = 1;
      });
    }
  }

  LineChartBarData tempoLine(List<FlSpot> points) {
    final backgroundColor = GAME_COLOR.withAlpha(30);
    return LineChartBarData(
      spots: points,
      dotData: FlDotData(show: false),
      barWidth: 5,
      isCurved: true,
      belowBarData: BarAreaData(
          show: _gameActive,
          color: backgroundColor,
          cutOffY: _targetTempo.toDouble(),
          applyCutOffY: _gameActive),
      aboveBarData: BarAreaData(
          show: _gameActive,
          color: backgroundColor,
          cutOffY: _targetTempo.toDouble(),
          applyCutOffY: _gameActive),
    );
  }

  LineChartBarData scoreLine(List<FlSpot> points) {
    return LineChartBarData(
      spots: points,
      dotData: FlDotData(show: false),
      color: Colors.yellow,
      barWidth: 5,
      show: _gameActive,
    );
  }

  void _tapped() {
    final dtnow = DateTime.now();
    final now = dtnow.millisecondsSinceEpoch;
    final prevTap = _lastTapMS;

    if (_lastTapMS + MS_UNTIL_CHAIN_RESET < now) {
      _resetTapChain(now);
    }
    setState(() {
      _tapsInChain++;
      _lastTapMS = now;
    });
    if (_tapsInChain == 1) {
      return;
    }

    var duration = now - prevTap;
    final skip = _tapsInChain > 1 &&
        !_lastTapSkipped &&
        duration > _beatMS * SKIPPED_TAP_THRESHOLD_LOW &&
        duration < _beatMS * SKIPPED_TAP_THRESHOLD_HIGH;
    if (skip) {
      duration = (duration * 0.5).floor();
    }
    setState(() {
      _lastTapSkipped = skip;
      _tapDurations[_tapDurationIndex] = duration;
      _tapDurationIndex = (_tapDurationIndex + 1) % _tapDurations.length;
    });

    final taps = min(_tapsInChain - 1, _tapDurations.length);
    final total = _tapDurations.fold(
        0, (previousValue, element) => previousValue + element);
    final averageDuration = (total / taps).floor();

    final msSinceStart = dtnow.difference(chartStart).inMilliseconds;
    setState(() {
      _beatMS = averageDuration;
      _tempo = (60000 / averageDuration).ceil();

      tempoDots.add(FlSpot(msSinceStart / 1000.0, _tempo * 1.0));
      tempoDots.removeWhere((element) =>
          msSinceStart / 1000.0 - element.x > CHART_VIEWPORT_MAXWIDTH);
    });
    updateScore();
  }

  void updateScore() {
    if (tempoDots.length < 3) {
      return;
    }
    final threshold = _targetTempo;
    final p1 = tempoDots[tempoDots.length - 2];
    final p2 = tempoDots[tempoDots.length - 1];
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    final slope = dy / dx;

    final bigY = max(p1.y, p2.y);
    final smallY = min(p1.y, p2.y);

    late final double fullArea;
    if (smallY < threshold && bigY > threshold) {
      // line crosses the threshold: calculate 2 smaller triangles
      final posY = bigY - threshold;
      final negY = threshold - smallY;
      final xIntersect = posY / slope;

      final areaUpper = 0.5 * posY * xIntersect;
      final areaLower = 0.5 * negY * xIntersect;
      fullArea = areaUpper.abs() + areaLower.abs();
    } else {
      final rectHeight =
          (smallY < threshold) ? (threshold - bigY) : (smallY - threshold);
      final areaTri = 0.5 * dx * dy;
      final areaRect = dx * rectHeight;
      fullArea = areaTri.abs() + areaRect.abs();
    }
    final areaPerLength = fullArea / dx;

    final rampupWeight =
        pow(min(RAMPUP_TAPS, tempoDots.length - 1) / RAMPUP_TAPS, 2);
    final scoreArea = areaPerLength * rampupWeight;

    double newScore = 0;
    String descr =
        rampupWeight < 1 ? "(${tempoDots.length - 1}/$RAMPUP_TAPS)" : "";
    if (scoreArea <= GOOD_THRESHOLD) {
      descr = "Good $descr";
      newScore = min(100, _gameScore + GOOD_REWARD);
    } else if (scoreArea <= CLOSE_THRESHOLD) {
      descr = "Close $descr";
      newScore = max(0, _gameScore - CLOSE_PENALTY);
    } else if (scoreArea <= BAD_THRESHOLD) {
      descr = "Bad $descr";
      newScore = max(0, _gameScore - BAD_PENALTY);
    } else {
      descr = "HORRIBLE! $descr";
      newScore = max(0, _gameScore - HORRIBLE_FACTOR * scoreArea);
    }

    setState(() {
      _gameScore = newScore;
      _gameDescription = descr;
      _lastArea = areaPerLength;
      scoreDots.add(FlSpot(p2.x, _gameScore));
    });
  }

  void _resetTapChain(int now) {
    setState(() {
      _tapsInChain = 0;
      _tapDurationIndex = 0;
      _resetMS = now;
      for (var i = 0; i < _tapDurations.length; i++) {
        _tapDurations[i] = 0;
      }
    });
  }

  void resetChart() {
    setState(() {
      tempoDots.clear();
      tempoDots.add(FlSpot.nullSpot);
      scoreDots.clear();
      scoreDots.add(FlSpot.nullSpot);
      _gameScore = 100;
      chartStart = DateTime.now();
    });
  }
}
