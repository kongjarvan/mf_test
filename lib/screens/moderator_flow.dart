import 'package:flutter/material.dart';

import '../models/game_role.dart';
import '../models/host_game.dart';
import '../models/player.dart';
import '../utils/night_resolution.dart';
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
      final exec = _game.executionDayChoice;
      if (exec > 0) {
        for (final p in _game.players) {
          if (p.slot == exec && p.alive) {
            p.alive = false;
            p.deathCause = '낮 처형으로 사망했습니다.';
            break;
          }
        }
      }
      _game.nightActionTargets.clear();
      _game.nightGuidanceText = '';
      _phase = ModeratorPhase.night;
    });
  }

  void _goToDayFromNight() {
    late NightResolutionReport nightReport;
    setState(() {
      nightReport = applyNightResolution(_game);

      // 대부가 신병/기생(현재 hostess)을 지목하면 다음 낮에 전향 처리한다.
      for (final don in _game.players.where((p) => p.role == GameRole.don)) {
        final raw = _game.nightActionTargets[don.slot];
        final targetSlot = int.tryParse((raw ?? '').trim());
        if (targetSlot == null) continue;
        Player? target;
        for (final p in _game.players) {
          if (p.slot == targetSlot) {
            target = p;
            break;
          }
        }
        if (target == null || !target.alive) continue;
        if (target.role == GameRole.recruit) {
          target.role = GameRole.mafiaMember;
        } else if (target.role == GameRole.hostess) {
          target.role = GameRole.prostitute;
        }
      }

      final d = _game.day;
      final targetLines = _game.nightActionTargets.entries
          .where((e) => e.value.trim().isNotEmpty)
          .map((e) => '${e.key}번 → ${e.value.trim()}')
          .toList();
      final g = _game.nightGuidanceText.trim();
      if (targetLines.isNotEmpty ||
          g.isNotEmpty ||
          nightReport.actionLogBlock.isNotEmpty) {
        final lines = <String>['[$d밤]', ...targetLines];
        if (g.isNotEmpty) lines.add('안내: $g');
        if (nightReport.actionLogBlock.isNotEmpty) {
          lines.add(nightReport.actionLogBlock);
        }
        final block = lines.join('\n');
        _game.nightNotes = _game.nightNotes.isEmpty
            ? block
            : '${_game.nightNotes}\n\n$block';
      }
      _game.nightActionTargets.clear();
      _game.nightGuidanceText = '';
      _game.day++;
      _game.executionDayChoice = 0;
      _phase = ModeratorPhase.day;
    });

    final String nightKillPopupText;
    if (nightReport.paragraphs.isNotEmpty) {
      nightKillPopupText = nightReport.paragraphs.join('\n\n');
    } else if (nightReport.actionLogBlock.isNotEmpty) {
      nightKillPopupText =
          '${nightReport.actionLogBlock}\n\n이번 밤 야간 킬로 인한 사망·부상 없음.';
    } else {
      nightKillPopupText = '이번 밤 야간 킬로 인한 습격 보고는 없습니다.';
    }
    _game.lastNightKillPopupText = nightKillPopupText;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('밤 킬 현황'),
          content: SingleChildScrollView(
            child: Text(nightKillPopupText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
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
