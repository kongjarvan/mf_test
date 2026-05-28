import '../models/game_role.dart';
import '../models/host_game.dart';
import '../models/player.dart';
import 'night_targets.dart';

/// [applyNightResolution] 결과 — 낮 전환 시 팝업·밤 기록에 사용.
class NightResolutionReport {
  NightResolutionReport({
    required this.paragraphs,
    required this.actionLogBlock,
  });

  /// 빈이면 팝업 생략 가능
  final List<String> paragraphs;

  /// [야간 행동] 등, nightNotes에 붙일 블록(빈 문자열 가능)
  final String actionLogBlock;

  bool get hasPopupContent => paragraphs.isNotEmpty;
}

class _NightComputed {
  _NightComputed({
    required this.actionLogBlock,
    required this.paragraphs,
    required this.pendingDeaths,
    required this.reviveAsZombieSlots,
    required this.vigilanteKillsAfter,
  });

  final String actionLogBlock;
  final List<String> paragraphs;
  final Map<int, String> pendingDeaths;
  final Set<int> reviveAsZombieSlots;
  final Map<int, int> vigilanteKillsAfter;
}

/// 플레이어 상태를 바꾸지 않고 밤 해소를 계산한다. [applyNightResolution]과 동일 규칙.
_NightComputed _computeNight(HostGame game) {
  final players = game.players;
  final plan = buildNightTargetPlan(game);

  Player? bySlot(int slot) {
    for (final p in players) {
      if (p.slot == slot) return p;
    }
    return null;
  }

  String displayName(Player p) {
    final n = p.name.trim();
    return n.isEmpty ? '${p.slot}번' : n;
  }

  String displayNameSlot(int slot) {
    final p = bySlot(slot);
    return p == null ? '$slot번' : displayName(p);
  }

  final aliveMafiaMemberCount =
      players.where((p) => p.alive && p.role == GameRole.mafiaMember).length;

  bool isSealed(Player p) {
    if (p.role == GameRole.busDriver) return false;
    if (p.role == GameRole.mafiaMember && aliveMafiaMemberCount >= 2) return false;
    return plan.sealedSlots.contains(p.slot);
  }

  final logLines = <String>[];

  if (plan.witchControlledActorSlot != null &&
      plan.witchForcedAbilityTargetRaw != null) {
    logLines.add(
      '마녀: ${displayNameSlot(plan.witchControlledActorSlot!)}의 단일 대상 능력 첫 지목을 '
      '${displayNameSlot(plan.witchForcedAbilityTargetRaw!)}(으)로 강제함',
    );
  }

  void logKillRole(GameRole role, Player? actor) {
    if (actor == null) {
      logLines.add('${role.label}: 해당 직업 없음');
      return;
    }
    final raw = plan.effectiveTargetsForSlot(actor.slot, actor.role);
    if (raw.isEmpty) {
      logLines.add('${role.label}: 대상 미지정(시도 없음)');
      return;
    }
    if (isSealed(actor)) {
      logLines.add('${role.label}: 시도했으나 봉인 등으로 무효');
      return;
    }
    if (role == GameRole.vigilante && actor.vigilanteKillsLeft <= 0) {
      logLines.add('${role.label}: 잔여 횟수 없음(시도 없음)');
      return;
    }
    final resolved = plan.mapSlot(raw.first);
    logLines.add('${role.label}: 시도함 → 대상 ${displayNameSlot(resolved)}');
  }

  final mafiaActor = () {
    for (final p in players) {
      if (p.alive && p.role == GameRole.mafiaMember) return p;
    }
    return null;
  }();
  logKillRole(GameRole.mafiaMember, mafiaActor);

  Player? skActor;
  for (final p in players.where((x) => x.alive && x.role == GameRole.serialKiller)) {
    skActor = p;
    break;
  }
  logKillRole(GameRole.serialKiller, skActor);

  Player? vigActor;
  for (final p in players.where((x) => x.alive && x.role == GameRole.vigilante)) {
    vigActor = p;
    break;
  }
  logKillRole(GameRole.vigilante, vigActor);

  Player? zombieActor;
  int? zombieMarkResolved;
  for (final z in players.where((x) => x.alive && x.role == GameRole.zombie)) {
    if (isSealed(z)) continue;
    final raw = plan.effectiveTargetsForSlot(z.slot, z.role);
    if (raw.isEmpty) continue;
    zombieActor = z;
    zombieMarkResolved = plan.mapSlot(raw.first);
    logLines.add(
      '좀비: ${displayNameSlot(zombieMarkResolved)}에게 표식(사망 시 좀비로 부활)',
    );
    break;
  }

  final actionLogBlock = logLines.isEmpty
      ? ''
      : '[야간 행동]\n${logLines.join('\n')}';

  final vigSim = <int, int>{
    for (final p in players.where((x) => x.alive && x.role == GameRole.vigilante))
      p.slot: p.vigilanteKillsLeft,
  };

  final killEvents = <List<int>>[];

  void tryAddKill(Player attacker, GameRole attackKind) {
    if (!attacker.alive) return;
    if (isSealed(attacker)) return;

    final raw = plan.effectiveTargetsForSlot(attacker.slot, attacker.role);
    if (raw.isEmpty) return;
    final resolved = plan.mapSlot(raw.first);
    final target = bySlot(resolved);
    if (target == null || !target.alive) return;
    if (target.role == GameRole.don) return;

    if (attackKind == GameRole.vigilante) {
      final left = vigSim[attacker.slot] ?? 0;
      if (left <= 0) return;
      killEvents.add([resolved, attacker.slot]);
      vigSim[attacker.slot] = (left - 1).clamp(0, 999);
      return;
    }

    killEvents.add([resolved, attacker.slot]);
  }

  if (mafiaActor != null) {
    tryAddKill(mafiaActor, GameRole.mafiaMember);
  }
  for (final p in players.where((x) => x.alive && x.role == GameRole.serialKiller)) {
    tryAddKill(p, GameRole.serialKiller);
  }
  for (final p in players.where((x) => x.alive && x.role == GameRole.vigilante)) {
    tryAddKill(p, GameRole.vigilante);
  }

  final killCount = <int, int>{};
  for (final e in killEvents) {
    final slot = e[0];
    killCount[slot] = (killCount[slot] ?? 0) + 1;
  }

  int? doctorHealSlot;
  for (final doc in players.where((p) => p.alive && p.role == GameRole.doctor)) {
    if (isSealed(doc)) continue;
    final raw = plan.effectiveTargetsForSlot(doc.slot, doc.role);
    if (raw.isEmpty) continue;
    doctorHealSlot = plan.mapSlot(raw.first);
    break;
  }

  String reasonForKillVictim(int victimSlot, int count) {
    if (count >= 2) {
      return '여러 야간 공격이 겹쳐 사망했습니다.';
    }
    for (final e in killEvents) {
      if (e[0] != victimSlot) continue;
      final attacker = bySlot(e[1]);
      if (attacker == null) return '야간 킬로 사망했습니다.';
      switch (attacker.role) {
        case GameRole.mafiaMember:
          return '마피아의 야간 킬로 사망했습니다.';
        case GameRole.serialKiller:
          return '연쇄 살인마의 야간 킬로 사망했습니다.';
        case GameRole.vigilante:
          return '자경단원의 야간 킬로 사망했습니다.';
        default:
          return '야간 킬로 사망했습니다.';
      }
    }
    return '야간 킬로 사망했습니다.';
  }

  final pendingDeaths = <int, String>{};

  for (final entry in killCount.entries) {
    final slot = entry.key;
    final count = entry.value;
    final target = bySlot(slot);
    if (target == null || !target.alive) continue;
    if (target.role == GameRole.don) continue;

    if (count >= 2) {
      pendingDeaths[slot] = reasonForKillVictim(slot, count);
    } else if (count == 1) {
      if (doctorHealSlot != slot) {
        pendingDeaths[slot] = reasonForKillVictim(slot, count);
      }
    }
  }

  final soldierMutualParagraphs = <String>[];
  if (pendingDeaths.keys.any((s) => bySlot(s)?.role == GameRole.soldier)) {
    var mafiaAdded = false;
    for (final e in killEvents) {
      final victimSlot = e[0];
      final attackerSlot = e[1];
      if (!pendingDeaths.containsKey(victimSlot)) continue;
      final victim = bySlot(victimSlot);
      if (victim == null || victim.role != GameRole.soldier) continue;

      final attacker = bySlot(attackerSlot);
      if (attacker == null || !attacker.alive) continue;

      if (attacker.role == GameRole.mafiaMember) {
        if (mafiaAdded) continue;
        mafiaAdded = true;
      }

      final attackerName = displayName(attacker);
      final doctorSavedAttacker = doctorHealSlot == attacker.slot;

      if (doctorSavedAttacker) {
        soldierMutualParagraphs.add(
          '$attackerName은 상대와의 치열한 몸싸움 끝에 위기에 처했습니다.\n'
          '그러나 의사의 도움으로 $attackerName은 살아남았습니다.',
        );
        continue;
      }

      pendingDeaths[attacker.slot] = '군인의 동귀어진으로 사망했습니다.';
      soldierMutualParagraphs.add(
        '$attackerName은 상대와의 치열한 몸싸움 끝에\n쓰러졌습니다.',
      );
    }
  }

  // 좀비 부활은 킬 1건일 때만 유효 — 의사 규칙과 동일.
  // 같은 밤 자경단원·연쇄살인마 등 추가 킬이 겹치면 사망 처리.
  final reviveAsZombieSlots = <int>{};
  if (zombieMarkResolved != null &&
      pendingDeaths.containsKey(zombieMarkResolved) &&
      (killCount[zombieMarkResolved] ?? 0) == 1) {
    reviveAsZombieSlots.add(zombieMarkResolved);
    pendingDeaths.remove(zombieMarkResolved);
  }

  final victimParagraphs = <String>[];
  final victimSlotsOrdered = killCount.keys.toList()..sort();

  for (final slot in victimSlotsOrdered) {
    final count = killCount[slot]!;
    final target = bySlot(slot);
    if (target == null || !target.alive) continue;
    if (target.role == GameRole.don) continue;

    final name = displayName(target);
    final healedHere = doctorHealSlot == slot;

    if (reviveAsZombieSlots.contains(slot)) {
      final marker = zombieActor == null ? '좀비' : displayName(zombieActor);
      victimParagraphs.add(
        '$name이 습격 당하였습니다.\n그러나 의사의 도움으로 $name은 살아남았습니다.',
      );
      continue;
    }

    if (count >= 2) {
      if (healedHere) {
        victimParagraphs.add(
          '$name이 여러번 습격 당하였습니다.\n의사의 노력에도 $name은 사망하였습니다.',
        );
      } else {
        victimParagraphs.add(
          '$name이 여러번 습격 당하였습니다.\n대상은 사망하였습니다.',
        );
      }
      continue;
    }

    if (healedHere) {
      victimParagraphs.add(
        '$name이 습격 당하였습니다.\n그러나 의사의 도움으로 $name은 살아남았습니다.',
      );
    } else {
      victimParagraphs.add(
        '$name이 습격 당하였습니다.\n대상은 사망하였습니다.',
      );
    }
  }

  final allParagraphs = [...victimParagraphs, ...soldierMutualParagraphs];

  return _NightComputed(
    actionLogBlock: actionLogBlock,
    paragraphs: allParagraphs,
    pendingDeaths: pendingDeaths,
    reviveAsZombieSlots: reviveAsZombieSlots,
    vigilanteKillsAfter: vigSim,
  );
}

/// 좀비 표식이 실제로 부활까지 이어지는지(이번 밤 킬로 해당 슬롯이 사망 처리되는지).
/// [resolvedMarkedSlot]은 버스 등 반영 후 슬롯([buildNightTargetPlan]과 동일).
bool zombieMarkedVictimRevivesTonight(HostGame game, int resolvedMarkedSlot) {
  final c = _computeNight(game);
  return c.reviveAsZombieSlots.contains(resolvedMarkedSlot);
}

/// 밤 종료 시 야간 킬·의사·좀비 부활·중복 킬·대부 면역·군인 동귀어진을 반영해 [Player.alive]·직업을 갱신한다.
NightResolutionReport applyNightResolution(HostGame game) {
  final c = _computeNight(game);
  final players = game.players;

  Player? bySlot(int slot) {
    for (final p in players) {
      if (p.slot == slot) return p;
    }
    return null;
  }

  for (final entry in c.pendingDeaths.entries) {
    final p = bySlot(entry.key);
    if (p != null && p.alive) {
      p.deathCause = entry.value;
      p.alive = false;
    }
  }

  for (final slot in c.reviveAsZombieSlots) {
    final p = bySlot(slot);
    if (p != null && p.alive) {
      p.role = GameRole.zombie;
      p.deathCause = null;
    }
  }

  for (final entry in c.vigilanteKillsAfter.entries) {
    final p = bySlot(entry.key);
    if (p != null && p.role == GameRole.vigilante) {
      p.vigilanteKillsLeft = entry.value;
    }
  }

  return NightResolutionReport(
    paragraphs: c.paragraphs,
    actionLogBlock: c.actionLogBlock,
  );
}
