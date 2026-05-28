import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_role.dart';
import '../models/host_game.dart';
import '../models/player.dart';
import '../utils/night_resolution.dart';
import '../utils/night_targets.dart';
import '../widgets/roster_seat_display_mode.dart';

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
  RosterSeatDisplayMode _seatDisplayMode = RosterSeatDisplayMode.slotAndName;

  HostGame get _g => widget.game;

  Color _roleColor(Player p) {
    switch (p.role.faction) {
      case Faction.mafia: return Colors.red;
      case Faction.citizen: return Colors.lightGreen;
      case Faction.neutral: return Colors.deepPurple[200]!;
      case Faction.zombie: return Colors.grey[400]!;
      case Faction.none: return Colors.white70;
    }
  }

  Color _roleTextColor(GameRole role) {
    switch (role.faction) {
      case Faction.mafia: return Colors.red;
      case Faction.citizen: return Colors.lightGreen;
      case Faction.neutral: return Colors.deepPurple[200]!;
      case Faction.zombie: return Colors.grey[400]!;
      case Faction.none: return Colors.white;
    }
  }

  List<int> _parseNightTargets(Player p) {
    final raw = _g.nightActionTargets[p.slot];
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }

  void _saveNightTargets(Player p, List<int?> targets) {
    final cleaned = targets.whereType<int>().toList();
    if (cleaned.isEmpty) {
      _g.nightActionTargets.remove(p.slot);
    } else {
      _g.nightActionTargets[p.slot] = cleaned.join(', ');
    }
    widget.onGameChanged();
  }

  bool _canSelectNightTarget(Player p) {
    if (!p.alive) return false;
    if (p.role == GameRole.recruit || p.role == GameRole.soldier) return false;
    if (p.role == GameRole.vigilante && p.vigilanteKillsLeft <= 0) return false;
    return true;
  }

  String _seatLabel(Player p) {
    switch (_seatDisplayMode) {
      case RosterSeatDisplayMode.slotAndName:
        final name = p.name.trim();
        return name.isEmpty ? '${p.slot}번' : '${p.slot}번 $name';
      case RosterSeatDisplayMode.roleLabel:
        return _g.formatRoleLabel(p.role);
    }
  }

  String _playerDisplayNameBySlot(int slot) {
    final p = _g.players.firstWhere((x) => x.slot == slot);
    final name = p.name.trim();
    return name.isEmpty ? '$slot번' : name;
  }

  GameRole _playerRoleBySlot(int slot) => _g.players.firstWhere((x) => x.slot == slot).role;

  String _actionSummary(_NightActionPreview action) {
    final actorName = _playerDisplayNameBySlot(action.actorSlot);
    final targetNames = action.targetSlots.map(_playerDisplayNameBySlot).toList();

    final isKillRole = action.role == GameRole.mafiaMember ||
        action.role == GameRole.vigilante ||
        action.role == GameRole.serialKiller;
    if (isKillRole) {
      if (targetNames.isEmpty) {
        return '${action.order}. ${action.role.label} 행동하지 않음';
      }
      return '${action.order}. ${action.role.label}이 ${targetNames.first}에게 능력 사용';
    }
    if (action.role == GameRole.busDriver && targetNames.length >= 2) {
      return '${action.order}. ${action.role.label}가 ${targetNames[0]} ${targetNames[1]}에게 능력 사용';
    }
    if (targetNames.isEmpty) {
      return '${action.order}. ${action.role.label}($actorName) 행동 없음';
    }
    return '${action.order}. ${action.role.label}이 ${targetNames.first}에게 능력 사용';
  }

  InlineSpan _actionPopupContentSpan(_NightActionPreview action, BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) + 1,
      color: Theme.of(context).colorScheme.onSurface,
    );
    if (action.role == GameRole.witch) {
      if (action.targetSlots.length < 2) {
        return TextSpan(
          text: '(비공개 · 플레이어에게 불공개)\n'
              '마녀의 행동은 플레이어에게 알려지지 않습니다.\n'
              '조종할 플레이어와 능력 사용 대상을 모두 선택해야 합니다.',
          style: baseStyle,
        );
      }
      final controlled = _playerDisplayNameBySlot(action.targetSlots[0]);
      final forced = _playerDisplayNameBySlot(action.targetSlots[1]);
      return TextSpan(
        text: '(비공개 · 플레이어에게 불공개)\n'
            '마녀의 행동은 플레이어에게 알려지지 않습니다.\n\n'
            '사회자 참고: $controlled가 사용하는 단일 대상 능력의 첫 지목을 $forced(으)로 강제합니다.',
        style: baseStyle,
      );
    }
    if (action.role == GameRole.zombie) {
      if (action.targetSlots.isEmpty) {
        return TextSpan(text: '', style: baseStyle);
      }
      final marked = action.targetSlots.first;
      if (!zombieMarkedVictimRevivesTonight(_g, marked)) {
        return TextSpan(
          text: '(비공개 · 플레이어에게 전달하지 않음)\n'
              '표식 대상은 이번 밤 야간 킬로 사망하지 않았습니다. 좀비 부활 안내 문구는 읽어주지 않습니다.',
          style: baseStyle,
        );
      }
      return TextSpan(
        text: '(지정된 대상에게 전달)\n'
            '당신은 사망 후 좀비로 되살아났습니다.\n'
            '당신의 직업은 이제 좀비 입니다',
        style: baseStyle,
      );
    }
    if (action.role == GameRole.mafiaMember ||
        action.role == GameRole.vigilante ||
        action.role == GameRole.serialKiller) {
      if (action.targetSlots.isEmpty) {
        return TextSpan(
          text: '(모두에게 전달)\n오늘밤 ${action.role.label}은 행동하지 않았습니다.',
          style: baseStyle,
        );
      }
      if (_playerRoleBySlot(action.targetSlots.first) == GameRole.don) {
        final donName = _playerDisplayNameBySlot(action.targetSlots.first);
        final attackerName = _playerDisplayNameBySlot(action.actorSlot);
        return TextSpan(
          text: '${action.role.label}는 대부를 습격하였습니다.\n'
              '대부는 도주하는데 성공하였으나 자신의 정체를 들키고 말았습니다.\n'
              '대부: $donName / ${action.role.label}: $attackerName',
          style: baseStyle,
        );
      }
      return TextSpan(
        text: '(모두에게 전달)\n오늘밤 ${action.role.label}이 암살을 시도했습니다.',
        style: baseStyle,
      );
    }
    if (action.role == GameRole.hostess || action.role == GameRole.prostitute) {
      if (action.targetSlots.isNotEmpty &&
          _playerRoleBySlot(action.targetSlots.first) == GameRole.busDriver) {
        final busDriverName = _playerDisplayNameBySlot(action.targetSlots.first);
        return TextSpan(
          text: '($busDriverName에게 전달)\n'
              '기생(혹은 매춘부)가 당신을 찾아왔으나 당신은 그녀를 쫓아냈습니다.',
          style: baseStyle,
        );
      }
      final sealTargetName = action.targetSlots.isNotEmpty
          ? _playerDisplayNameBySlot(action.targetSlots.first)
          : '';
      return TextSpan(
        text: sealTargetName.isEmpty
            ? '(행동대상에게 전달)\n기생(혹은 매춘부)에 의해 오늘 밤 당신의 능력은 봉인됩니다.'
            : '($sealTargetName에게 전달)\n'
                '기생(혹은 매춘부)에 의해 오늘 밤 당신의 능력은 봉인됩니다.',
        style: baseStyle,
      );
    }
    if (action.role == GameRole.busDriver) {
      return TextSpan(
        text: '(탑승대상에게 전달)\n당신은 오늘밤 버스에 탑승하였습니다.',
        style: baseStyle,
      );
    }
    if ((action.role == GameRole.detective || action.role == GameRole.underboss) &&
        action.targetSlots.isNotEmpty) {
      final targetSlot = action.targetSlots.first;
      final actorName = _playerDisplayNameBySlot(action.actorSlot);
      return TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: '($actorName에게 전달)\n'),
          TextSpan(text: '${_playerDisplayNameBySlot(targetSlot)} 의 직업은 '),
          TextSpan(
            text: _g.formatRoleLabel(_playerRoleBySlot(targetSlot)),
            style: TextStyle(
              color: _roleTextColor(_playerRoleBySlot(targetSlot)),
              fontWeight: FontWeight.bold,
            ),
          ),
          const TextSpan(text: ' 입니다.'),
        ],
      );
    }
    if (action.role == GameRole.courier && action.targetSlots.isNotEmpty) {
      final courierName = _playerDisplayNameBySlot(action.actorSlot);
      final observedSlot = action.targetSlots.first;
      final observedName = _playerDisplayNameBySlot(observedSlot);
      final observed = _g.players.firstWhere((p) => p.slot == observedSlot);
      if (observed.role == GameRole.mafiaMember) {
        return TextSpan(
          text: '($courierName에게 전달)\n$observedName은 오늘밤 움직이지 않았습니다.',
          style: baseStyle,
        );
      }

      final plan = buildNightTargetPlan(_g);
      final sealedSlots = plan.sealedSlots;
      final aliveMafiaMemberCount = _g.players
          .where((p) => p.alive && p.role == GameRole.mafiaMember)
          .length;
      final isHostessImmuneMafiaMember =
          observed.role == GameRole.mafiaMember && aliveMafiaMemberCount >= 2;
      final blockedByHostess = sealedSlots.contains(observed.slot) &&
          observed.role != GameRole.busDriver &&
          !isHostessImmuneMafiaMember;

      List<int> visited = const [];
      if (!blockedByHostess &&
          observed.alive &&
          observed.role != GameRole.recruit &&
          observed.role != GameRole.soldier &&
          !(observed.role == GameRole.vigilante && observed.vigilanteKillsLeft <= 0)) {
        final raw = plan.effectiveTargetsForSlot(observed.slot, observed.role);
        if (observed.role == GameRole.busDriver) {
          if (raw.isNotEmpty) {
            visited = [raw.first];
          }
        } else {
          visited = raw.map(plan.mapSlot).toList();
        }
      }

      if (visited.isEmpty) {
        return TextSpan(
          text: '($courierName에게 전달)\n$observedName은 오늘밤 움직이지 않았습니다.',
          style: baseStyle,
        );
      }
      final visitedNames = visited.map(_playerDisplayNameBySlot).toList();
      final visitedText = visitedNames.length == 1
          ? '${visitedNames.first}을'
          : '${visitedNames.join('와 ')}을';
      return TextSpan(
        text: '($courierName에게 전달)\n$observedName은 오늘밤 $visitedText 방문했습니다.',
        style: baseStyle,
      );
    }
    if (action.role == GameRole.don && action.targetSlots.isNotEmpty) {
      final targetSlot = action.targetSlots.first;
      final targetRole = _playerRoleBySlot(targetSlot);
      final donName = _playerDisplayNameBySlot(action.actorSlot);
      final targetName = _playerDisplayNameBySlot(targetSlot);
      if (targetRole == GameRole.detective) {
        return TextSpan(
          text: '($donName과 $targetName에게 전달)\n'
              '$donName은 $targetName에게 영입권유를 했습니다.\n'
              '$targetName은 당신의 정체를 간파하였습니다!\n'
              '대부: $donName / 탐정: $targetName',
          style: baseStyle,
        );
      }
      if (targetRole == GameRole.recruit || targetRole == GameRole.hostess) {
        final newRoleLabel = targetRole == GameRole.recruit ? '마피아 멤버' : '매춘부';
        return TextSpan(
          text: '(영입 가능 대상에게 전달)\n'
              '당신은 대부의 영입 권유를 받아들였습니다.\n'
              '당신은 지금부터 $newRoleLabel로서 마피아 팀에 합류 합니다.',
          style: baseStyle,
        );
      }
      return TextSpan(
        text: '(영입 불가능 대상에게 전달)\n'
            '당신은 대부의 영입 권유를 거절했습니다',
        style: baseStyle,
      );
    }
    if (action.role == GameRole.doctor) {
      return TextSpan(text: '', style: baseStyle);
    }
    return TextSpan(text: _actionSummary(action), style: baseStyle);
  }

  List<_NightActionPreview> _buildNightActionPreviews() {
    final plan = buildNightTargetPlan(_g);
    const actionOrder = <GameRole, int>{
      GameRole.witch: 1,
      GameRole.busDriver: 2,
      GameRole.hostess: 3,
      GameRole.prostitute: 3,
      GameRole.don: 4,
      GameRole.detective: 4,
      GameRole.underboss: 4,
      GameRole.doctor: 5,
      GameRole.zombie: 6,
      GameRole.mafiaMember: 7,
      GameRole.vigilante: 8,
      GameRole.serialKiller: 9,
      GameRole.courier: 10,
    };
    final list = <_NightActionPreview>[];

    final aliveMafiaMemberCount = _g.players
        .where((p) => p.alive && p.role == GameRole.mafiaMember)
        .length;

    bool isSealed(Player p) {
      if (p.role == GameRole.busDriver) return false;
      if (p.role == GameRole.mafiaMember && aliveMafiaMemberCount >= 2) return false;
      return plan.sealedSlots.contains(p.slot);
    }

    for (final p in _g.players.where((x) => x.alive)) {
      final order = actionOrder[p.role];
      if (order == null) continue;
      final isHostessImmuneMafiaMember =
          p.role == GameRole.mafiaMember && aliveMafiaMemberCount >= 2;
      if (isSealed(p) &&
          p.role != GameRole.busDriver &&
          !isHostessImmuneMafiaMember) {
        continue;
      }
      final rawTargets = plan.effectiveTargetsForSlot(p.slot, p.role);
      final dualTargetRole =
          p.role == GameRole.busDriver || p.role == GameRole.witch;
      final targets = dualTargetRole
          ? rawTargets
          : rawTargets.map(plan.mapSlot).toList();
      if (dualTargetRole && targets.length < 2) continue;
      if (!dualTargetRole && targets.isEmpty) continue;
      list.add(
        _NightActionPreview(
          order: order,
          actorSlot: p.slot,
          role: p.role,
          targetSlots:
              dualTargetRole ? targets.take(2).toList() : [targets.first],
        ),
      );
    }
    list.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.actorSlot.compareTo(b.actorSlot);
    });
    return list;
  }

  Future<void> _showActionSentencePopup(_NightActionPreview action) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RichText(text: _actionPopupContentSpan(action, context)),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('닫기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showNightPlayerDetail(Player p) async {
    final roleLabel = _g.formatRoleLabel(p.role);
    final name = p.name.trim().isEmpty ? '${p.slot}번' : p.name;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${p.slot}번 · $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  children: [
                    TextSpan(
                      text: '직업: ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: roleLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _roleColor(p),
                      ),
                    ),
                  ],
                ),
              ),
              if (p.role == GameRole.vigilante) ...[
                const SizedBox(height: 10),
                Text(
                  '남은 행동 횟수: ${p.vigilanteKillsLeft}회',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_canSelectNightTarget(p)) ...[
                const SizedBox(height: 12),
                if (p.role == GameRole.busDriver) ...[
                  DropdownButtonFormField<int?>(
                    key: ValueKey(
                      'night_target_a_${p.slot}_${_g.nightActionTargets[p.slot] ?? ''}',
                    ),
                    initialValue:
                        _parseNightTargets(p).isNotEmpty ? _parseNightTargets(p)[0] : null,
                    decoration: const InputDecoration(
                      labelText: '행동 대상 1',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('선택 안 함')),
                      ..._g.players.where((t) => t.alive).map(
                        (target) => DropdownMenuItem<int?>(
                          value: target.slot,
                          child: Text(
                            '${target.slot}번 ${target.name.trim().isEmpty ? '' : '· ${target.name}'}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (first) {
                      final parsed = _parseNightTargets(p);
                      final second = parsed.length >= 2 ? parsed[1] : null;
                      final normalizedSecond = second == first ? null : second;
                      _saveNightTargets(p, [first, normalizedSecond]);
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    key: ValueKey(
                      'night_target_b_${p.slot}_${_g.nightActionTargets[p.slot] ?? ''}',
                    ),
                    initialValue: _parseNightTargets(p).length >= 2
                        ? _parseNightTargets(p)[1]
                        : null,
                    decoration: const InputDecoration(
                      labelText: '행동 대상 2',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('선택 안 함')),
                      ..._g.players.where((t) => t.alive).map(
                        (target) => DropdownMenuItem<int?>(
                          value: target.slot,
                          enabled: target.slot !=
                              (_parseNightTargets(p).isNotEmpty ? _parseNightTargets(p)[0] : null),
                          child: Text(
                            '${target.slot}번 ${target.name.trim().isEmpty ? '' : '· ${target.name}'}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (second) {
                      final parsed = _parseNightTargets(p);
                      final first = parsed.isNotEmpty ? parsed[0] : null;
                      final normalizedSecond = second == first ? null : second;
                      _saveNightTargets(p, [first, normalizedSecond]);
                      setDialogState(() {});
                    },
                  ),
                ] else if (p.role == GameRole.witch) ...[
                  DropdownButtonFormField<int?>(
                    key: ValueKey(
                      'night_witch_a_${p.slot}_${_g.nightActionTargets[p.slot] ?? ''}',
                    ),
                    initialValue:
                        _parseNightTargets(p).isNotEmpty ? _parseNightTargets(p)[0] : null,
                    decoration: const InputDecoration(
                      labelText: '조종할 플레이어',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('선택 안 함')),
                      ..._g.players.where((t) => t.alive).map(
                        (target) => DropdownMenuItem<int?>(
                          value: target.slot,
                          child: Text(
                            '${target.slot}번 ${target.name.trim().isEmpty ? '' : '· ${target.name}'}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (first) {
                      final parsed = _parseNightTargets(p);
                      final second = parsed.length >= 2 ? parsed[1] : null;
                      final normalizedSecond = second == first ? null : second;
                      _saveNightTargets(p, [first, normalizedSecond]);
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    key: ValueKey(
                      'night_witch_b_${p.slot}_${_g.nightActionTargets[p.slot] ?? ''}',
                    ),
                    initialValue: _parseNightTargets(p).length >= 2
                        ? _parseNightTargets(p)[1]
                        : null,
                    decoration: const InputDecoration(
                      labelText: '능력 사용 대상',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('선택 안 함')),
                      ..._g.players.where((t) => t.alive).map(
                        (target) => DropdownMenuItem<int?>(
                          value: target.slot,
                          enabled: target.slot !=
                              (_parseNightTargets(p).isNotEmpty ? _parseNightTargets(p)[0] : null),
                          child: Text(
                            '${target.slot}번 ${target.name.trim().isEmpty ? '' : '· ${target.name}'}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (second) {
                      final parsed = _parseNightTargets(p);
                      final first = parsed.isNotEmpty ? parsed[0] : null;
                      final normalizedSecond = second == first ? null : second;
                      _saveNightTargets(p, [first, normalizedSecond]);
                      setDialogState(() {});
                    },
                  ),
                ] else
                  DropdownButtonFormField<int?>(
                    key: ValueKey(
                      'night_target_${p.slot}_${_g.nightActionTargets[p.slot] ?? ''}',
                    ),
                    initialValue:
                        _parseNightTargets(p).isNotEmpty ? _parseNightTargets(p).first : null,
                    decoration: const InputDecoration(
                      labelText: '행동 대상',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('선택 안 함')),
                      ..._g.players.where((t) => t.alive).map(
                        (target) => DropdownMenuItem<int?>(
                          value: target.slot,
                          child: Text(
                            '${target.slot}번 ${target.name.trim().isEmpty ? '' : '· ${target.name}'}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (int? selectedSlot) {
                      _saveNightTargets(p, [selectedSlot]);
                      setDialogState(() {});
                    },
                  ),
              ] else if (p.role == GameRole.vigilante && p.alive) ...[
                const SizedBox(height: 10),
                Text(
                  '행동 횟수를 모두 사용했습니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
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

  void _finishNight() {
    _g.nightGuidanceText = '';
    widget.onToDay();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alive = _g.players.where((p) => p.alive).toList();
    final actionPreviews = _buildNightActionPreviews();
    const darkBg = Color(0xFF11131A);
    const darkSurface = Color(0xFF1A1E28);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        title: Text('밤 · ${_g.day}일차'),
        leading: IconButton(
          icon: const Icon(Icons.wb_sunny_outlined),
          tooltip: '낮 화면으로(같은 일차)',
          onPressed: widget.onBackToDay,
        ),
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
              Text(
                '인원 현황',
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                tooltip: _seatDisplayMode.tooltipNext,
                onPressed: () {
                  setState(() => _seatDisplayMode = _seatDisplayMode.next);
                },
                icon: Icon(
                  _seatDisplayMode.icon,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: darkSurface,
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
                              color: const Color(0xFF232938),
                              borderColor: const Color(0xFF3B4258),
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
                              onTap: () => _showNightPlayerDetail(p),
                              child: Container(
                                width: seatRadius * 2,
                                height: seatRadius * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: p.alive
                                      ? const Color(0xFF2F5D9A)
                                      : const Color(0xFF3A3F4D),
                                  border: Border.all(
                                    color: p.alive
                                        ? const Color(0xFF8BB6FF)
                                        : const Color(0xFF5B6070),
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
                                        color: _seatDisplayMode == RosterSeatDisplayMode.roleLabel && p.alive
                                            ? _roleColor(p)
                                            : Colors.white,
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
          const SizedBox(height: 6),
          Text(
            '12시 방향부터 시계 방향으로 1번, 2번, 3번 순서입니다. 원을 탭하면 상세 팝업이 열립니다.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          if (alive.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '생존자가 없습니다. 낮 화면에서 생존을 확인하세요.',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            '행동 순서 미리보기',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          if (actionPreviews.isEmpty)
            Text(
              '아직 선택된 밤 행동이 없습니다.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            )
          else
            ...actionPreviews.map((action) {
              final summary = _actionSummary(action);
              return Card(
                color: darkSurface,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    summary,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => _showActionSentencePopup(action),
                    child: const Text('문구 출력'),
                  ),
                ),
              );
            }),
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

class _NightActionPreview {
  const _NightActionPreview({
    required this.order,
    required this.actorSlot,
    required this.role,
    required this.targetSlots,
  });

  final int order;
  final int actorSlot;
  final GameRole role;
  final List<int> targetSlots;
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
