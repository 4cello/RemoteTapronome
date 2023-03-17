import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:metronome/appstate.dart';
import 'package:metronome/tempochart.dart';
import "package:provider/provider.dart";
import "globals.dart" as globals;
//import 'package:flutter_number_picker/flutter_number_picker.dart';
//import 'package:flutter/rendering.dart' show debugPaintSizeEnabled;

void main() {
  //debugPaintSizeEnabled = true;
  runApp(ChangeNotifierProvider(
    create: (ctx) => MetronomeModel(),
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _lastTapMS = 0;
  int _beatMS = 500;

  int _tapsInChain = 0;
  final List<int> _tapDurations = [0, 0, 0, 0, 0];
  int _tapDurationIndex = 0;
  bool _lastTapSkipped = false;

  bool _metroRunning = false;
  int _metroBeats = 4;
  int _currentBeat = 1;

  String _gameDescription = "";
  double _lastArea = 0;

  Timer metroTimer = Timer(const Duration(milliseconds: 0), () => {});
  final onBeat = AudioPlayer();
  final offBeat = AudioPlayer();

  @override
  void initState() {
    super.initState();

    final onBeatAsset = AssetSource("audio/metronome-beat.mp3");
    final offBeatAsset = AssetSource("audio/metronome-offbeat.mp3");
    onBeat.setSource(onBeatAsset);
    offBeat.setSource(offBeatAsset);
    onBeat.setPlayerMode(PlayerMode.lowLatency);
    offBeat.setPlayerMode(PlayerMode.lowLatency);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<MetronomeModel>();
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
                  shape: const MaterialStatePropertyAll(CircleBorder()),
                  iconSize: const MaterialStatePropertyAll(30)),
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
                          state.currentTempo = max(40, state.currentTempo - 1),
                      child: const Text("-"),
                    ),
                    Text(
                      '${context.select((MetronomeModel m) => m.currentTempo.toInt())}',
                      style: const TextStyle(fontSize: 60),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          state.currentTempo = min(300, state.currentTempo + 1),
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
                  state.gameActive = !state.gameActive;
                  state.targetTempo = state.currentTempo.toInt();
                },
                style: ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll(
                        state.gameActive ? Colors.red : Colors.grey),
                    shape: const MaterialStatePropertyAll(CircleBorder()),
                    iconSize: const MaterialStatePropertyAll(30)),
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
              visible: context.select((MetronomeModel m) => m.gameActive),
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Row(
                children: [
                  Text(
                    "Target: ${state.targetTempo}",
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
                    "Score: ${state.scoreList.isNotEmpty ? state.scoreList.last.y : 100}",
                    style: const TextStyle(fontSize: 20),
                  ),
                  Text(
                    "$_gameDescription (${_lastArea.toStringAsFixed(2)})",
                  ),
                ],
              ),
            )
          ],
        ),
      ],
    );

    final chartStack = ChangeNotifierProvider(
        create: (ctx) => ctx.read<MetronomeModel>(), child: TempoChart());

    final app = MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Metronome App'),
        ),
        body: LayoutBuilder(builder: (ctx, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  tempoCore,
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 600,
                    child: AspectRatio(aspectRatio: 1.5, child: chartStack),
                  ),
                  const SizedBox(height: 20),
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
                context.select((MetronomeModel m) => m.reset());
              } else {
                _tapped();
              }
            }
          },
          child: app),
    );
  }

  void nextBeat() {
    final millis = 60000 / context.read<MetronomeModel>().currentTempo;
    final newTimer =
        Timer(Duration(milliseconds: millis.toInt()), () => nextBeat());
    setState(() {
      _currentBeat = _currentBeat % _metroBeats + 1;
      metroTimer = newTimer;
    });
    final audioPlayer = _currentBeat == 1 ? onBeat : offBeat;
    audioPlayer.stop();
    audioPlayer.resume();
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

  void _tapped() {
    final dtnow = DateTime.now();
    final now = dtnow.millisecondsSinceEpoch;
    final prevTap = _lastTapMS;

    if (_lastTapMS + globals.MS_UNTIL_CHAIN_RESET < now) {
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
        duration > _beatMS * globals.SKIPPED_TAP_THRESHOLD_LOW &&
        duration < _beatMS * globals.SKIPPED_TAP_THRESHOLD_HIGH;
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

    final appState = context.read<MetronomeModel>();
    final msSinceStart = dtnow.difference(appState.startTime).inMilliseconds;
    setState(() {
      _beatMS = averageDuration;
    });

    appState.addTempo(
        msSinceStart / 1000, (60000 / averageDuration).ceilToDouble());
    updateScore();
  }

  void updateScore() {
    final state = context.read<MetronomeModel>();
    final tempoDots = state.tempoList;
    if (tempoDots.length < 2 || !state.gameActive) {
      return;
    }
    final oldScore = state.scoreList.last.y.toDouble();
    final threshold = state.targetTempo;
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

    final rampupWeight = pow(
        min(globals.RAMPUP_TAPS, tempoDots.length - 1) / globals.RAMPUP_TAPS,
        2);
    final scoreArea = areaPerLength * rampupWeight;

    double newScore = 0;
    String descr = rampupWeight < 1
        ? "(${tempoDots.length - 1}/${globals.RAMPUP_TAPS})"
        : "";
    if (scoreArea <= globals.GOOD_THRESHOLD) {
      descr = "Good $descr";
      newScore = min(100, oldScore + globals.GOOD_REWARD);
    } else if (scoreArea <= globals.CLOSE_THRESHOLD) {
      descr = "Close $descr";
      newScore = max(0, oldScore - globals.CLOSE_PENALTY);
    } else if (scoreArea <= globals.BAD_THRESHOLD) {
      descr = "Bad $descr";
      newScore = max(0, oldScore - globals.BAD_PENALTY);
    } else {
      descr = "HORRIBLE! $descr";
      newScore = max(0, oldScore - globals.HORRIBLE_FACTOR * scoreArea);
    }

    setState(() {
      _gameDescription = descr;
      _lastArea = areaPerLength;
    });
    state.addScore(p2.x.toDouble(), newScore);
  }

  void _resetTapChain(int now) {
    setState(() {
      _tapsInChain = 0;
      _tapDurationIndex = 0;
      for (var i = 0; i < _tapDurations.length; i++) {
        _tapDurations[i] = 0;
      }
    });
  }
}
