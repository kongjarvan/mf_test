import 'package:flutter/material.dart';

import '../models/game_role.dart';
import '../models/host_game.dart';
import '../models/player.dart';

/// 낮: 인원 현황, 날씨(플레이스홀더), 처형 대상 선택, 밤으로 이동.
class DayScreen extends StatefulWidget {
  const DayScreen({
    super.key,
    required this.game,
    required this.onGameChanged,
    required this.onToNight,
    required this.onBackToSetup,
    required this.onReset,
  });

  final HostGame game;
  final VoidCallback onGameChanged;
  final VoidCallback onToNight;
  final Future<void> Function() onBackToSetup;
  final Future<void> Function() onReset;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  late final TextEditingController _weatherCtrl;

  HostGame get _g => widget.game;

  @override
  void initState() {
    super.initState();
    _weatherCtrl = TextEditingController(text: _g.weatherNote);
    _weatherCtrl.addListener(() {
      _g.weatherNote = _weatherCtrl.text;
    });
  }

  @override
  void dispose() {
    _weatherCtrl.dispose();
    super.dispose();
  }

  void _invalidateExecutionIfDead() {
    final c = _g.executionDayChoice;
    if (c > 0 && !_g.players.any((p) => p.slot == c && p.alive)) {
      _g.executionDayChoice = 0;
    }
  }

  void _setAlive(Player p, bool v) {
    setState(() {
      p.alive = v;
      _invalidateExecutionIfDead();
    });
    widget.onGameChanged();
  }

  void _toggleRoleVisibility() {
    setState(() {
      _g.revealRolesDuringGame = !_g.revealRolesDuringGame;
    });
    widget.onGameChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = _g.countAliveByFaction(Faction.mafia);
    final c = _g.countAliveByFaction(Faction.citizen);
    final n = _g.countAliveByFaction(Faction.neutral);

    final aliveSlots = _g.players.where((p) => p.alive).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('낮 · ${_g.day}일차'),
        leading: IconButton(
          icon: const Icon(Icons.settings),
          tooltip: '설정으로',
          onPressed: widget.onBackToSetup,
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
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.groups, size: 18),
                label: Text('생존 ${_g.aliveCount}/${_g.players.length}'),
              ),
              Chip(label: Text('마피아 $m')),
              Chip(label: Text('시민 $c')),
              Chip(label: Text('중립 $n')),
            ],
          ),
          const SizedBox(height: 16),
          Text('인원 현황', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._g.players.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${p.slot}')),
                  title: Text(
                    p.name.trim().isEmpty ? '${p.slot}번' : p.name,
                    style: TextStyle(
                      decoration:
                          p.alive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(_g.formatRoleLabel(p.role)),
                  trailing: Switch(
                    value: p.alive,
                    onChanged: (v) => _setAlive(p, v),
                  ),
                ),
              )),
          const SizedBox(height: 16),
          Text('날씨', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '날씨 규칙이 정해지면 여기에 연결할 예정입니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _weatherCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: '임시 메모 (규칙 확정 후 대체)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('처형 대상', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '밤으로 가기 전에 반드시 선택합니다. 아무도 처형되지 않는 날은 「처형 없음」을 고르세요.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: ValueKey(
              'exec_${_g.executionDayChoice}_${aliveSlots.map((p) => p.slot).join(',')}',
            ),
            initialValue: _g.executionDayChoice == 0
                ? null
                : _g.executionDayChoice,
            hint: const Text('처형 대상을 선택하세요'),
            decoration: const InputDecoration(
              labelText: '오늘 처형 (필수)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int>(
                value: -1,
                child: Text('처형 없음 (아무도 처형되지 않음)'),
              ),
              ...aliveSlots.map(
                (p) => DropdownMenuItem<int>(
                  value: p.slot,
                  child: Text(
                    '${p.slot}번 ${p.name.trim().isEmpty ? '' : '· ${p.name}'} (${_g.formatRoleLabel(p.role)})',
                  ),
                ),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _g.executionDayChoice = v);
              widget.onGameChanged();
            },
          ),
          if (_g.executionDayChoice == 0) ...[
            const SizedBox(height: 8),
            Text(
              '선택하지 않으면 밤으로 이동할 수 없습니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_g.nightNotes.isNotEmpty) ...[
            const SizedBox(height: 20),
            ExpansionTile(
              title: const Text('누적 밤 기록'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      _g.nightNotes,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed:
                _g.canGoToNightFromDay ? widget.onToNight : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('밤으로'),
            ),
          ),
        ],
      ),
    );
  }
}
