import 'game_role.dart';

/// 한 슬롯(참가자 1명). 이름·직업·생존·메모는 사회자가 기록한다.
class Player {
  Player({
    required this.slot,
    this.name = '',
    this.role = GameRole.unassigned,
    this.alive = true,
    this.notes = '',
    this.vigilanteKillsLeft = 2,
  });

  final int slot;
  String name;
  GameRole role;
  bool alive;
  String notes;

  /// 자경단원 전용. 직업이 자경이 아니면 무시해도 된다.
  int vigilanteKillsLeft;

  Player copyWith({
    String? name,
    GameRole? role,
    bool? alive,
    String? notes,
    int? vigilanteKillsLeft,
  }) {
    return Player(
      slot: slot,
      name: name ?? this.name,
      role: role ?? this.role,
      alive: alive ?? this.alive,
      notes: notes ?? this.notes,
      vigilanteKillsLeft: vigilanteKillsLeft ?? this.vigilanteKillsLeft,
    );
  }

  static List<Player> createTable() =>
      List.generate(12, (i) => Player(slot: i + 1));
}
