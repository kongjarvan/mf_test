import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_role.dart';
import '../models/host_game.dart';
import '../models/player.dart';
import '../utils/setup_random.dart';

/// 인원·이름·직업 배정 후 낮 화면으로 넘어간다.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.game,
    required this.onGameChanged,
    required this.onComplete,
    required this.onReset,
  });

  final HostGame game;
  final VoidCallback onGameChanged;
  final VoidCallback onComplete;
  final Future<void> Function() onReset;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final Map<int, TextEditingController> _nameCtrls = {};

  HostGame get _g => widget.game;

  @override
  void initState() {
    super.initState();
    _ensureNameControllers();
  }

  @override
  void dispose() {
    for (final c in _nameCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureNameControllers() {
    final slots = _g.players.map((p) => p.slot).toSet();
    for (final key in _nameCtrls.keys.toList()) {
      if (!slots.contains(key)) {
        _nameCtrls[key]!.dispose();
        _nameCtrls.remove(key);
      }
    }
    for (final p in _g.players) {
      _nameCtrls.putIfAbsent(
        p.slot,
        () => TextEditingController(text: p.name),
      );
    }
  }

  void _applyCountDelta(int delta) {
    final next = _g.players.length + delta;
    if (next < Player.minCount || next > Player.maxCount) return;
    setState(() {
      _g.resizePlayerCount(next);
      _ensureNameControllers();
    });
    widget.onGameChanged();
  }

  void _setRole(Player p, GameRole r) {
    setState(() {
      p.role = r;
      if (r == GameRole.vigilante) {
        p.vigilanteKillsLeft = 2;
      }
    });
    widget.onGameChanged();
  }

  Future<void> _tryComplete() async {
    if (needsRandomFill(_g)) {
      applyRandomSetup(_g, Random());
      for (final p in _g.players) {
        _nameCtrls[p.slot]!.text = p.name;
      }
      setState(() {});
      widget.onGameChanged();
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('게임 설정'),
        actions: [
          IconButton(
            tooltip: '전체 초기화',
            onPressed: widget.onReset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text(
            '플레이어 인원과 직업을 맞춘 뒤 완료를 누르세요. '
            '이름·직업이 비어 있으면 완료 시 자동 배정됩니다(12인까지 직업 중복 없음).',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('인원', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: _g.players.length <= Player.minCount
                        ? null
                        : () => _applyCountDelta(-1),
                    icon: const Icon(Icons.remove),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${_g.players.length}명',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _g.players.length >= Player.maxCount
                        ? null
                        : () => _applyCountDelta(1),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${Player.minCount}~${Player.maxCount}명 · 줄이면 뒷번호부터 제거',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ..._g.players.map((p) => _SetupPlayerRow(
                player: p,
                nameController: _nameCtrls[p.slot]!,
                onNameChanged: (v) {
                  p.name = v;
                  widget.onGameChanged();
                },
                onRoleChanged: _setRole,
              )),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('setup_complete'),
            onPressed: _tryComplete,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('완료 · 낮 화면으로'),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _SetupPlayerRow extends StatelessWidget {
  const _SetupPlayerRow({
    required this.player,
    required this.nameController,
    required this.onNameChanged,
    required this.onRoleChanged,
  });

  final Player player;
  final TextEditingController nameController;
  final ValueChanged<String> onNameChanged;
  final void Function(Player p, GameRole r) onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              child: Text('${player.slot}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: onNameChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<GameRole>(
                key: ValueKey('setup_role_${player.slot}_${player.role}'),
                initialValue: player.role,
                decoration: const InputDecoration(
                  labelText: '직업',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: kGameRolePickerOrder
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(
                          r.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (r) {
                  if (r != null) onRoleChanged(player, r);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
