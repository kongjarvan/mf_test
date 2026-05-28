import 'dart:math';

import '../models/game_role.dart';
import '../models/host_game.dart';

/// 12인 구성(README): 마피아 3 + 시민 8 + 중립 1 — 서로 겹치지 않는 12직.
const List<GameRole> kStandardTwelveUniqueRoles = [
  GameRole.don,
  GameRole.underboss,
  GameRole.mafiaMember,
  GameRole.detective,
  GameRole.courier,
  GameRole.doctor,
  GameRole.soldier,
  GameRole.hostess,
  GameRole.vigilante,
  GameRole.recruit,
  GameRole.busDriver,
  GameRole.serialKiller,
];

/// 13인 랜덤 배정: 12인 직업 + 좀비 (서로 겹치지 않는 13직).
const List<GameRole> kStandardThirteenUniqueRoles = [
  ...kStandardTwelveUniqueRoles,
  GameRole.zombie,
];

/// 14인 랜덤 배정: 13인 직업 + 마녀 (서로 겹치지 않는 14직).
const List<GameRole> kStandardFourteenUniqueRoles = [
  ...kStandardThirteenUniqueRoles,
  GameRole.witch,
];

/// 인원이 해당 일반 풀보다 많거나·미배정 슬롯이 풀 소진 후일 때 중복 허용용 풀.
const List<GameRole> kDuplicateExtraRoles = [
  GameRole.mafiaMember,
  GameRole.mafiaMember,
  GameRole.recruit,
  GameRole.detective,
  GameRole.courier,
  GameRole.busDriver,
  GameRole.doctor,
  GameRole.soldier,
];

const List<String> _kRandomNamePool = [
  '민준', '서연', '도윤', '하은', '예준', '지우', '시우', '서준',
  '하준', '지안', '유준', '채원', '은우', '다은', '이준', '수빈',
  '준서', '지유', '건우', '서윤', '우진', '예은', '선우', '유진',
  '시윤', '지호', '주원', '소율', '연우', '민서', '정우', '하율',
  '윤서', '현우', '서진', '지원', '태양', '가은', '승우', '나연',
];

/// 이름이 비었거나 직업이 미배정인 슬롯에 랜덤 이름·직업을 채운다.
/// 직업: 인원에 따라 고유 풀에서 겹치지 않게 배분한다.
/// - **12명 이하**: [kStandardTwelveUniqueRoles]
/// - **13명**: [kStandardThirteenUniqueRoles] (12직 + 좀비)
/// - **14명**: [kStandardFourteenUniqueRoles] (13직 + 마녀)
/// 풀을 다 쓴 뒤 남는 슬롯은 [kDuplicateExtraRoles]에서 무작위(중복 가능).
void applyRandomSetup(HostGame game, [Random? random]) {
  final rng = random ?? Random();

  final usedNames = <String>{
    for (final p in game.players)
      if (p.name.trim().isNotEmpty) p.name.trim(),
  };

  for (final p in game.players) {
    if (p.name.trim().isEmpty) {
      p.name = _pickName(rng, usedNames);
      usedNames.add(p.name);
    }
  }

  final alreadyTaken = <GameRole>{
    for (final p in game.players)
      if (p.role != GameRole.unassigned) p.role,
  };

  final need = game.players.where((p) => p.role == GameRole.unassigned).toList()
    ..sort((a, b) => a.slot.compareTo(b.slot));

  final playerCount = game.players.length;
  final List<GameRole> uniquePoolSource = playerCount >= 14
      ? kStandardFourteenUniqueRoles
      : playerCount == 13
          ? kStandardThirteenUniqueRoles
          : kStandardTwelveUniqueRoles;

  var pool = uniquePoolSource
      .where((r) => !alreadyTaken.contains(r))
      .toList()
    ..shuffle(rng);

  for (final p in need) {
    if (pool.isNotEmpty) {
      p.role = pool.removeAt(0);
    } else {
      p.role = kDuplicateExtraRoles[rng.nextInt(kDuplicateExtraRoles.length)];
    }
    if (p.role == GameRole.vigilante) {
      p.vigilanteKillsLeft = 2;
    }
  }
}

String _pickName(Random rng, Set<String> used) {
  final shuffled = List<String>.from(_kRandomNamePool)..shuffle(rng);
  for (final base in shuffled) {
    final candidate = base;
    if (!used.contains(candidate)) return candidate;
  }
  for (var i = 1; i < 1000; i++) {
    final candidate = '참가자$i';
    if (!used.contains(candidate)) return candidate;
  }
  return '참가자_${rng.nextInt(1 << 30)}';
}

/// 랜덤이 필요한지(이름 공백 또는 직업 미배정).
bool needsRandomFill(HostGame game) {
  return game.players.any(
    (p) => p.name.trim().isEmpty || p.role == GameRole.unassigned,
  );
}
