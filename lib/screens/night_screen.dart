import 'package:flutter/material.dart';

import '../models/host_game.dart';

/// 밤: 생존자별 행동 대상 입력, 안내 문구(플레이스홀더), 낮(다음 일차)으로.
class NightScreen extends StatefulWidget {
  const NightScreen({
    super.key,
    required this.game,
    required this.onGameChanged,
    required this.onToDay,
    required this.onBackToDay,
    required this.onReset,
  });

  final HostGame game;
  final VoidCallback onGameChanged;
  final VoidCallback onToDay;
  final VoidCallback onBackToDay;
  final Future<void> Function() onReset;

  @override
  State<NightScreen> createState() => _NightScreenState();
}

class _NightScreenState extends State<NightScreen> {
  final Map<int, TextEditingController> _targetCtrls = {};
  late final TextEditingController _guidanceCtrl;

  HostGame get _g => widget.game;

  @override
  void initState() {
    super.initState();
    _guidanceCtrl = TextEditingController(text: _g.nightGuidanceText);
    _guidanceCtrl.addListener(() {
      _g.nightGuidanceText = _guidanceCtrl.text;
      widget.onGameChanged();
    });
    _syncTargetControllers();
  }

  void _syncTargetControllers() {
    final alive = _g.players.where((p) => p.alive).map((p) => p.slot).toSet();
    for (final key in _targetCtrls.keys.toList()) {
      if (!alive.contains(key)) {
        _targetCtrls[key]!.dispose();
        _targetCtrls.remove(key);
      }
    }
    for (final p in _g.players.where((x) => x.alive)) {
      _targetCtrls.putIfAbsent(
        p.slot,
        () => TextEditingController(
          text: _g.nightActionTargets[p.slot] ?? '',
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _targetCtrls.values) {
      c.dispose();
    }
    _guidanceCtrl.dispose();
    super.dispose();
  }

  void _toggleRoleVisibility() {
    setState(() {
      _g.revealRolesDuringGame = !_g.revealRolesDuringGame;
    });
    widget.onGameChanged();
  }

  void _finishNight() {
    for (final e in _targetCtrls.entries) {
      _g.nightActionTargets[e.key] = e.value.text;
    }
    _g.nightGuidanceText = _guidanceCtrl.text;
    widget.onToDay();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alive = _g.players.where((p) => p.alive).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('밤 · ${_g.day}일차'),
        leading: IconButton(
          icon: const Icon(Icons.wb_sunny_outlined),
          tooltip: '낮 화면으로(같은 일차)',
          onPressed: widget.onBackToDay,
        ),
        actions: [
          IconButton(
            tooltip:
                _g.revealRolesDuringGame ? '직업 숨기기' : '직업 보기',
            onPressed: _toggleRoleVisibility,
            icon: Icon(
              _g.revealRolesDuringGame
                  ? Icons.visibility_off
                  : Icons.visibility,
            ),
          ),
          IconButton(
            tooltip: '전체 초기화',
            onPressed: widget.onReset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            '생존자가 누구에게 행동하는지 적습니다. (규칙 확정 후 안내 문구 자동 생성 등 연결 예정)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ...alive.map((p) {
            final ctrl = _targetCtrls[p.slot]!;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.slot}번 · ${p.name.trim().isEmpty ? '(이름 없음)' : p.name} · ${_g.formatRoleLabel(p.role)}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(
                        labelText: '행동 대상 (이름·번호 등)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => widget.onGameChanged(),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (alive.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '생존자가 없습니다. 낮 화면에서 생존을 확인하세요.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          const SizedBox(height: 16),
          Text('안내 문구', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '밤 처리 후 플레이어에게 보여줄 문구. 규칙이 정해지면 자동 생성 등으로 바꿀 수 있습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _guidanceCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '사회자 안내 초안',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _finishNight,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('낮으로 (다음 일차)'),
            ),
          ),
        ],
      ),
    );
  }
}
