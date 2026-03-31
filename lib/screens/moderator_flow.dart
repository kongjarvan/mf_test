import 'package:flutter/material.dart';

import '../models/host_game.dart';
import 'day_screen.dart';
import 'night_screen.dart';
import 'setup_screen.dart';

enum ModeratorPhase { setup, day, night }

/// 설정 → 낮 → 밤 순으로 전환한다. 밤 종료 시 일차가 올라가고 다시 낮으로 간다.
class ModeratorFlow extends StatefulWidget {
  const ModeratorFlow({super.key});

  @override
  State<ModeratorFlow> createState() => _ModeratorFlowState();
}

class _ModeratorFlowState extends State<ModeratorFlow> {
  late HostGame _game;
  ModeratorPhase _phase = ModeratorPhase.setup;

  @override
  void initState() {
    super.initState();
    _game = HostGame();
  }

  void _tick() => setState(() {});

  void _goToDayFromSetup() {
    setState(() => _phase = ModeratorPhase.day);
  }

  void _goToNightFromDay() {
    setState(() {
      _game.nightActionTargets.clear();
      _game.nightGuidanceText = '';
      _phase = ModeratorPhase.night;
    });
  }

  void _goToDayFromNight() {
    setState(() {
      final d = _game.day;
      final targetLines = _game.nightActionTargets.entries
          .where((e) => e.value.trim().isNotEmpty)
          .map((e) => '${e.key}번 → ${e.value.trim()}')
          .toList();
      final g = _game.nightGuidanceText.trim();
      if (targetLines.isNotEmpty || g.isNotEmpty) {
        final lines = <String>['[$d밤]', ...targetLines];
        if (g.isNotEmpty) lines.add('안내: $g');
        final block = lines.join('\n');
        _game.nightNotes = _game.nightNotes.isEmpty
            ? block
            : '${_game.nightNotes}\n\n$block';
      }
      _game.nightActionTargets.clear();
      _game.nightGuidanceText = '';
      _game.day++;
      _game.executionDayChoice = 0;
      _game.weatherNote = '';
      _phase = ModeratorPhase.day;
    });
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 초기화'),
        content: const Text('설정·낮·밤 기록을 모두 지우고 설정 화면으로 돌아갑니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        _game.reset();
        _phase = ModeratorPhase.setup;
      });
    }
  }

  Future<void> _confirmBackToSetup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('설정으로 돌아가기'),
        content: const Text('현재 낮·밤 입력은 유지되지 않을 수 있습니다. 설정으로 돌아갈까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('설정으로'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => _phase = ModeratorPhase.setup);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      ModeratorPhase.setup => SetupScreen(
          game: _game,
          onGameChanged: _tick,
          onComplete: _goToDayFromSetup,
          onReset: _confirmReset,
        ),
      ModeratorPhase.day => DayScreen(
          game: _game,
          onGameChanged: _tick,
          onToNight: _goToNightFromDay,
          onBackToSetup: _confirmBackToSetup,
          onReset: _confirmReset,
        ),
      ModeratorPhase.night => NightScreen(
          game: _game,
          onGameChanged: _tick,
          onToDay: _goToDayFromNight,
          onBackToDay: () => setState(() => _phase = ModeratorPhase.day),
          onReset: _confirmReset,
        ),
    };
  }
}
