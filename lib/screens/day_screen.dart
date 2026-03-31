import 'dart:math' as math;

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
    required this.onReset,
  });

  final HostGame game;
  final VoidCallback onGameChanged;
  final VoidCallback onToNight;
  final Future<void> Function() onReset; 

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  late final TextEditingController _weatherCtrl;
  bool _showNamesOnSeats = false;

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

  String _seatLabel(Player p) {
    if (!_showNamesOnSeats) return '${p.slot}';
    final name = p.name.trim();
    return name.isEmpty ? '${p.slot}번' : name;
  }

  Color _roleColor(Player p, ThemeData theme) {
    if (p.role == GameRole.serialKiller) {
      return Colors.pink;
    }
    if (p.role.faction == Faction.mafia) {
      return Colors.red;
    }
    if (p.role.faction == Faction.citizen) {
      return Colors.green;
    }
    return theme.colorScheme.onSurface;
  }

  Future<void> _showPlayerDetail(Player p) async {
    final roleLabel = _g.formatRoleLabel(p.role);
    final name = p.name.trim().isEmpty ? '${p.slot}번' : p.name;
    final theme = Theme.of(context);
    final roleColor = _roleColor(p, theme);
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${p.slot}번 · $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 20,
                    color: theme.colorScheme.onSurface,
                  ),
                  children: [
                    TextSpan(
                      text: '직업: ',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: roleLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: roleColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (!p.alive) ...[
                const SizedBox(height: 12),
                Text(
                  p.deathCause != null && p.deathCause!.trim().isNotEmpty
                      ? '사망: ${p.deathCause}'
                      : '사망 사유가 기록되지 않았습니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLastNightKillPopup() {
    final text = _g.lastNightKillPopupText;
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('표시할 전날 밤 킬 기록이 없습니다.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('밤 킬 현황'),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aliveSlots = _g.players.where((p) => p.alive).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('낮 · ${_g.day}일차'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: '전체 초기화',
            onPressed: widget.onReset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 24),
        children: [
          Row(
            children: [
              Text('인원 현황', style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: '전날 밤 킬 현황',
                onPressed: _showLastNightKillPopup,
                icon: const Icon(Icons.article_outlined),
              ),
              IconButton(
                tooltip: _showNamesOnSeats ? '번호로 보기' : '이름으로 보기',
                onPressed: () {
                  setState(() => _showNamesOnSeats = !_showNamesOnSeats);
                },
                icon: Icon(
                  _showNamesOnSeats ? Icons.tag : Icons.badge_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    final center = Offset(size.width / 2, size.height / 2);
                    final playerCount = _g.players.length;
                    final seatRadius = math.min(size.width, size.height) * 0.075;
                    final tableRadius = math.min(size.width, size.height) * 0.31;
                    final chairDistance = tableRadius + seatRadius * 1.2;

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RoundTablePainter(
                              center: center,
                              radius: tableRadius,
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderColor: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        ...List.generate(playerCount, (index) {
                          final p = _g.players[index];
                          final angle =
                              (-math.pi / 2) + (2 * math.pi * index / playerCount);
                          final position = Offset(
                            center.dx + chairDistance * math.cos(angle),
                            center.dy + chairDistance * math.sin(angle),
                          );
                          final left = position.dx - seatRadius;
                          final top = position.dy - seatRadius;

                          return Positioned(
                            left: left,
                            top: top,
                            child: GestureDetector(
                              onTap: () => _showPlayerDetail(p),
                              child: Container(
                                width: seatRadius * 2,
                                height: seatRadius * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: p.alive
                                      ? theme.colorScheme.primaryContainer
                                      : const Color(0xFFBDBDBD),
                                  border: Border.all(
                                    color: p.alive
                                        ? theme.colorScheme.primary
                                        : const Color(0xFF9E9E9E),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _seatLabel(p),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: p.alive
                                            ? theme.colorScheme.onPrimaryContainer
                                            : const Color(0xFF616161),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          
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

class _RoundTablePainter extends CustomPainter {
  _RoundTablePainter({
    required this.center,
    required this.radius,
    required this.color,
    required this.borderColor,
  });

  final Offset center;
  final double radius;
  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = borderColor;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _RoundTablePainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor;
  }
}
