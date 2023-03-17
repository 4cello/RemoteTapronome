import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

class MetronomeModel extends ChangeNotifier {
  final List<Point> _tempoList = [];
  final List<Point> _scoreList = [const Point(0, 100)];

  bool _gameActive = false;
  int _targetTempo = 120;
  double _currentTempo = 120;
  var _startTime = DateTime.now();

  bool get gameActive => _gameActive;
  int get targetTempo => _targetTempo;
  double get currentTempo => _currentTempo;
  DateTime get startTime => _startTime;

  set targetTempo(int t) {
    _targetTempo = t;
    notifyListeners();
  }

  set currentTempo(double t) {
    _currentTempo = t;
    notifyListeners();
  }

  set gameActive(bool a) {
    _gameActive = a;
    notifyListeners();
  }

  UnmodifiableListView<Point> get tempoList => UnmodifiableListView(_tempoList);
  UnmodifiableListView<Point> get scoreList => UnmodifiableListView(_scoreList);

  void addTempo(double time, double tempo) {
    _tempoList.add(Point(time, tempo));
    _currentTempo = tempo;
    notifyListeners();
  }

  void addScore(double time, double score) {
    _scoreList.add(Point(time, score));
    notifyListeners();
  }

  void reset() {
    _startTime = DateTime.now();
    _tempoList.clear();
    _scoreList.clear();
    _scoreList.add(const Point(0, 100));
    notifyListeners();
  }
}
