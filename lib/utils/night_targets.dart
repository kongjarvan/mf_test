import '../models/game_role.dart';
import '../models/host_game.dart';

/// 버스 스왑·마녀 강제 지목·기생 봉인(해석 기준)까지 반영한 야간 지목 계획.
/// [applyNightResolution]과 낮·밤 미리보기가 동일 규칙을 쓰도록 한다.
class NightTargetPlan {
  NightTargetPlan({
    required this.busSwaps,
    required this.witchControlledActorSlot,
    required this.witchForcedAbilityTargetRaw,
    required this.sealedSlots,
    required this.parseTargets,
    required this.mapSlot,
    required this.effectiveTargetsForSlot,
  });

  final List<List<int>> busSwaps;

  /// 마녀가 조종하는 플레이어 좌석(버스 스왑 전). 둘 다 있어야 강제 적용.
  final int? witchControlledActorSlot;

  /// 조종 대상이 향해야 할 **능력 첫 지목** 좌석(버스 스왑 전).
  final int? witchForcedAbilityTargetRaw;

  /// 기생·매춘부가 막는 **좌석**(버스 반영 후).
  final Set<int> sealedSlots;

  final List<int> Function(String? raw) parseTargets;

  final int Function(int slot) mapSlot;

  /// [actorSlot] 플레이어의 이번 밤 해석용 지목 목록(버스 적용 전 단계에서 마녀 치환 반영).
  List<int> Function(int actorSlot, GameRole role) effectiveTargetsForSlot;
}

List<int> parseNightTargetsRaw(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .split(',')
      .map((e) => int.tryParse(e.trim()))
      .whereType<int>()
      .toList();
}

/// [game]의 현재 밤 입력 기준으로 계획을 만든다.
NightTargetPlan buildNightTargetPlan(HostGame game) {
  final players = game.players;

  final busSwaps = <List<int>>[];
  for (final bus in players.where((p) => p.alive && p.role == GameRole.busDriver)) {
    final t = parseNightTargetsRaw(game.nightActionTargets[bus.slot]);
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

  /// 마녀 능력 발동 여부 판정용: 마녀 본인 좌석만 보고 **강제 적용 전** 기생 지목이 닿았는지.
  final sealedSlotsPreWitch = <int>{};
  for (final h in players.where(
    (p) => p.alive && (p.role == GameRole.hostess || p.role == GameRole.prostitute),
  )) {
    final t = parseNightTargetsRaw(game.nightActionTargets[h.slot]);
    if (t.isNotEmpty) {
      sealedSlotsPreWitch.add(mapSlot(t.first));
    }
  }

  int? witchControlled;
  int? witchForcedTarget;
  for (final w in players.where((p) => p.alive && p.role == GameRole.witch)) {
    if (sealedSlotsPreWitch.contains(w.slot)) continue;
    final t = parseNightTargetsRaw(game.nightActionTargets[w.slot]);
    if (t.length < 2) continue;
    witchControlled = t[0];
    witchForcedTarget = t[1];
    break;
  }

  List<int> effectiveTargetsForSlot(int actorSlot, GameRole role) {
    final raw = parseNightTargetsRaw(game.nightActionTargets[actorSlot]);
    final wc = witchControlled;
    final wf = witchForcedTarget;

    bool witchOverridesControlledActor() =>
        wc != null && wf != null && actorSlot == wc && raw.isNotEmpty;

    // 마녀 본인 행: 치환하지 않음.
    if (role == GameRole.witch) return raw;

    if (role == GameRole.busDriver) {
      if (witchOverridesControlledActor()) {
        if (raw.length >= 2) return [wf!, raw[1]];
        return [wf!];
      }
      return raw;
    }

    if (witchOverridesControlledActor()) {
      return [wf!, ...raw.skip(1)];
    }

    return raw;
  }

  final sealedSlots = <int>{};
  for (final h in players.where(
    (p) => p.alive && (p.role == GameRole.hostess || p.role == GameRole.prostitute),
  )) {
    final eff = effectiveTargetsForSlot(h.slot, h.role);
    if (eff.isNotEmpty) {
      sealedSlots.add(mapSlot(eff.first));
    }
  }

  return NightTargetPlan(
    busSwaps: busSwaps,
    witchControlledActorSlot: witchControlled,
    witchForcedAbilityTargetRaw: witchForcedTarget,
    sealedSlots: sealedSlots,
    parseTargets: parseNightTargetsRaw,
    mapSlot: mapSlot,
    effectiveTargetsForSlot: effectiveTargetsForSlot,
  );
}
