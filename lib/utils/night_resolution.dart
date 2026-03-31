import '../models/game_role.dart';
import '../models/host_game.dart';
import '../models/player.dart';

/// [applyNightResolution] 결과 — 낮 전환 시 팝업·밤 기록에 사용.
class NightResolutionReport {
  NightResolutionReport({
    required this.paragraphs,
    required this.actionLogBlock,
  });

  /// 빈이면 팝업 생략 가능
  final List<String> paragraphs;

  /// [야간 킬 행동] 등, nightNotes에 붙일 블록(빈 문자열 가능)
  final String actionLogBlock;

  bool get hasPopupContent => paragraphs.isNotEmpty;
}

/// 밤 종료 시 야간 킬·의사·중복 킬·대부 면역·군인 동귀어진을 반영해 [Player.alive]를 갱신한다.
NightResolutionReport applyNightResolution(HostGame game) {
  final players = game.players;
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

  List<int> parseTargets(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }

  final busSwaps = <List<int>>[];
  for (final bus in players.where((p) => p.alive && p.role == GameRole.busDriver)) {
    final t = parseTargets(game.nightActionTargets[bus.slot]);
    if (t.length >= 2) {
      busSwaps.add([t[0], t[1]]);
    }
  }

  int mapSlot(int slot) {
    var m = slot;
    for (final pair in busSwaps) {
      final a = pair[0];
      final b = pair[1];
      if (m == a) {
        m = b;
      } else if (m == b) {
        m = a;
      }
    }
    return m;
  }

  final aliveMafiaMemberCount =
      players.where((p) => p.alive && p.role == GameRole.mafiaMember).length;

  final sealedSlots = <int>{};
  for (final h in players.where(
    (p) => p.alive && (p.role == GameRole.hostess || p.role == GameRole.prostitute),
  )) {
    final t = parseTargets(game.nightActionTargets[h.slot]);
    if (t.isNotEmpty) {
      sealedSlots.add(mapSlot(t.first));
    }
  }

  bool isSealed(Player p) {
    if (p.role == GameRole.busDriver) return false;
    if (p.role == GameRole.mafiaMember && aliveMafiaMemberCount >= 2) return false;
    return sealedSlots.contains(p.slot);
  }

  /// --- 야간 킬 행동 로그 (마피아 / 자경 / 연살) ---
  final logLines = <String>[];

  void logKillRole(GameRole role, Player? actor) {
    if (actor == null) {
      logLines.add('${role.label}: 해당 직업 없음');
      return;
    }
    final raw = parseTargets(game.nightActionTargets[actor.slot]);
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
    final resolved = mapSlot(raw.first);
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

  final actionLogBlock = logLines.isEmpty
      ? ''
      : '[야간 킬 행동]\n${logLines.join('\n')}';

  /// (해결된 피해 슬롯, 공격자 플레이어 슬롯)
  final killEvents = <List<int>>[];

  void tryAddKill(Player attacker, GameRole attackKind) {
    if (!attacker.alive) return;
    if (isSealed(attacker)) return;
    if (attackKind == GameRole.vigilante && attacker.vigilanteKillsLeft <= 0) return;

    final raw = parseTargets(game.nightActionTargets[attacker.slot]);
    if (raw.isEmpty) return;
    final resolved = mapSlot(raw.first);
    final target = bySlot(resolved);
    if (target == null || !target.alive) return;
    if (target.role == GameRole.don) return;

    killEvents.add([resolved, attacker.slot]);
    if (attackKind == GameRole.vigilante) {
      attacker.vigilanteKillsLeft =
          (attacker.vigilanteKillsLeft - 1).clamp(0, 999);
    }
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
    final raw = parseTargets(game.nightActionTargets[doc.slot]);
    if (raw.isEmpty) continue;
    doctorHealSlot = mapSlot(raw.first);
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

  /// 피해자 서술 (사망 처리 전 상태 기준 이름)
  final victimParagraphs = <String>[];
  final victimSlotsOrdered = killCount.keys.toList()..sort();

  for (final slot in victimSlotsOrdered) {
    final count = killCount[slot]!;
    final target = bySlot(slot);
    if (target == null || !target.alive) continue;
    if (target.role == GameRole.don) continue;

    final name = displayName(target);
    final healedHere = doctorHealSlot == slot;

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

    // count == 1
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

  /// 군인 동귀어진: 군인이 킬로 사망하면 공격자도 사망(마피아 1명만). 의사가 공격자를 치료하면 공격자 생존.
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

  for (final entry in pendingDeaths.entries) {
    final p = bySlot(entry.key);
    if (p != null && p.alive) {
      p.deathCause = entry.value;
      p.alive = false;
    }
  }

  final allParagraphs = [...victimParagraphs, ...soldierMutualParagraphs];

  return NightResolutionReport(
    paragraphs: allParagraphs,
    actionLogBlock: actionLogBlock,
  );
}
