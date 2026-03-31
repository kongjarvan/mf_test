import 'package:flutter/material.dart';

import '../models/game_role.dart';
import '../models/host_game.dart';
import '../models/player.dart';

/// 사회자 전용: 플레이어·직업·생존·밤·낮 메모를 기록한다.
class HostRecordScreen extends StatefulWidget {
  const HostRecordScreen({super.key});

  @override
  State<HostRecordScreen> createState() => _HostRecordScreenState();
}

class _HostRecordScreenState extends State<HostRecordScreen> {
  late HostGame _game;
  final Map<int, TextEditingController> _nameCtrls = {};
  final Map<int, TextEditingController> _notesCtrls = {};
  late final TextEditingController _nightCtrl;
  late final TextEditingController _dayCtrl;

  @override
  void initState() {
    super.initState();
    _game = HostGame();
    _nightCtrl = TextEditingController(text: _game.nightNotes);
    _dayCtrl = TextEditingController(text: _game.dayNotes);
    for (final p in _game.players) {
      _nameCtrls[p.slot] = TextEditingController(text: p.name);
      _notesCtrls[p.slot] = TextEditingController(text: p.notes);
    }
    _nightCtrl.addListener(() => _game.nightNotes = _nightCtrl.text);
    _dayCtrl.addListener(() => _game.dayNotes = _dayCtrl.text);
  }

  @override
  void dispose() {
    for (final c in _nameCtrls.values) {
      c.dispose();
    }
    for (final c in _notesCtrls.values) {
      c.dispose();
    }
    _nightCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  void _syncControllersFromGame() {
    for (final p in _game.players) {
      _nameCtrls[p.slot]!.text = p.name;
      _notesCtrls[p.slot]!.text = p.notes;
    }
    _nightCtrl.text = _game.nightNotes;
    _dayCtrl.text = _game.dayNotes;
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 초기화'),
        content: const Text('플레이어·메모를 모두 지웁니다. 계속할까요?'),
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
        _syncControllersFromGame();
      });
    }
  }

  void _setPlayer(int slot, Player Function(Player) fn) {
    final i = _game.players.indexWhere((p) => p.slot == slot);
    if (i < 0) return;
    setState(() {
      _game.players[i] = fn(_game.players[i]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = _game.countAliveByFaction(Faction.mafia);
    final c = _game.countAliveByFaction(Faction.citizen);
    final n = _game.countAliveByFaction(Faction.neutral);

    return Scaffold(
      appBar: AppBar(
        title: const Text('사회자 기록'),
        actions: [
          IconButton(
            tooltip: '전체 초기화',
            onPressed: _confirmReset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('라운드', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => setState(() {
                          if (_game.day > 1) _game.day--;
                        }),
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${_game.day}일차',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () =>
                            setState(() => _game.day++),
                        icon: const Icon(Icons.add),
                      ),
                      const Spacer(),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('낮')),
                          ButtonSegment(value: true, label: Text('밤')),
                        ],
                        selected: {_game.isNight},
                        onSelectionChanged: (s) =>
                            setState(() => _game.isNight = s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.groups, size: 18),
                        label: Text('생존 ${_game.aliveCount}/12'),
                      ),
                      Chip(label: Text('마피아 $m')),
                      Chip(label: Text('시민 $c')),
                      Chip(label: Text('중립 $n')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('플레이어', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._game.players.map((p) => _PlayerCard(
                player: p,
                nameController: _nameCtrls[p.slot]!,
                notesController: _notesCtrls[p.slot]!,
                onNameChanged: (v) => setState(() => p.name = v),
                onRoleChanged: (r) {
                  _setPlayer(p.slot, (old) {
                    var next = old.copyWith(role: r);
                    if (r == GameRole.vigilante) {
                      next = next.copyWith(vigilanteKillsLeft: 2);
                    }
                    return next;
                  });
                },
                onAliveChanged: (a) =>
                    _setPlayer(p.slot, (old) => old.copyWith(alive: a)),
                onNotesChanged: (v) => setState(() => p.notes = v),
                onVigKillsChanged: (k) => _setPlayer(
                  p.slot,
                  (old) => old.copyWith(vigilanteKillsLeft: k),
                ),
              )),
          const SizedBox(height: 24),
          Text('밤 메모', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _nightCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '킬, 조사, 버스, 봉인 등 그날 밤 정리',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('낮 메모', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _dayCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '처형, 발언 요약 등',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.nameController,
    required this.notesController,
    required this.onNameChanged,
    required this.onRoleChanged,
    required this.onAliveChanged,
    required this.onNotesChanged,
    required this.onVigKillsChanged,
  });

  final Player player;
  final TextEditingController nameController;
  final TextEditingController notesController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<GameRole> onRoleChanged;
  final ValueChanged<bool> onAliveChanged;
  final ValueChanged<String> onNotesChanged;
  final ValueChanged<int> onVigKillsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: player.alive
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Text(
            '${player.slot}',
            style: TextStyle(
              color: player.alive
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        title: Text(
          player.name.trim().isEmpty ? '${player.slot}번' : player.name,
          style: TextStyle(
            decoration:
                player.alive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(player.role.label),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: onNameChanged,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<GameRole>(
                  key: ValueKey('role_${player.slot}_${player.role}'),
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
                          child: Text(r.label),
                        ),
                      )
                      .toList(),
                  onChanged: (r) {
                    if (r != null) onRoleChanged(r);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('생존'),
                        value: player.alive,
                        onChanged: onAliveChanged,
                      ),
                    ),
                    if (player.role == GameRole.vigilante) ...[
                      Text('자경 킬', style: theme.textTheme.labelLarge),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: player.vigilanteKillsLeft.clamp(0, 2),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('0')),
                          DropdownMenuItem(value: 1, child: Text('1')),
                          DropdownMenuItem(value: 2, child: Text('2')),
                        ],
                        onChanged: (v) {
                          if (v != null) onVigKillsChanged(v);
                        },
                      ),
                    ],
                  ],
                ),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '개별 메모',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: onNotesChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
