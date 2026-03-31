/// 게임 규칙 README 기준 직업. 사회자가 배정·수정한다.
enum GameRole {
  unassigned,
  don,
  underboss,
  mafiaMember,
  detective,
  courier,
  doctor,
  soldier,
  parasite,
  prostitute,
  vigilante,
  recruit,
  busDriver,
  serialKiller,
}

enum Faction { none, mafia, citizen, neutral }

extension GameRoleX on GameRole {
  String get label => switch (this) {
        GameRole.unassigned => '미배정',
        GameRole.don => '대부',
        GameRole.underboss => '언더보스',
        GameRole.mafiaMember => '마피아 멤버',
        GameRole.detective => '탐정',
        GameRole.courier => '배달부',
        GameRole.doctor => '의사',
        GameRole.soldier => '군인',
        GameRole.parasite => '기생',
        GameRole.prostitute => '매춘부',
        GameRole.vigilante => '자경단원',
        GameRole.recruit => '신병',
        GameRole.busDriver => '버스기사',
        GameRole.serialKiller => '연쇄 살인마',
      };

  Faction get faction => switch (this) {
        GameRole.unassigned => Faction.none,
        GameRole.don ||
        GameRole.underboss ||
        GameRole.mafiaMember =>
          Faction.mafia,
        GameRole.serialKiller => Faction.neutral,
        _ => Faction.citizen,
      };
}

/// 직업 선택 드롭다운 순서
const List<GameRole> kGameRolePickerOrder = [
  GameRole.unassigned,
  GameRole.don,
  GameRole.underboss,
  GameRole.mafiaMember,
  GameRole.detective,
  GameRole.courier,
  GameRole.doctor,
  GameRole.soldier,
  GameRole.parasite,
  GameRole.prostitute,
  GameRole.vigilante,
  GameRole.recruit,
  GameRole.busDriver,
  GameRole.serialKiller,
];
