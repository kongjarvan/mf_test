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
    this.deathCause,
  });

  final int slot;
  String name;
  GameRole role;
  bool alive;
  String notes;

  /// 사망 시 사유(야간 해석 등). 생존이면 null.
  String? deathCause;

  /// 자경단원 전용. 직업이 자경이 아니면 무시해도 된다.
  int vigilanteKillsLeft;

  Player copyWith({
    String? name,
    GameRole? role,
    bool? alive,
    String? notes,
    int? vigilanteKillsLeft,
    String? deathCause,
  }) {
    return Player(
      slot: slot,
      name: name ?? this.name,
      role: role ?? this.role,
      alive: alive ?? this.alive,
      notes: notes ?? this.notes,
      vigilanteKillsLeft: vigilanteKillsLeft ?? this.vigilanteKillsLeft,
      deathCause: deathCause ?? this.deathCause,
    );
  }

  /// 슬롯은 1부터 연속 번호.
  static List<Player> createTable(int count) {
    final n = count.clamp(minCount, maxCount);
    return List.generate(n, (i) => Player(slot: i + 1));
  }

  static const int minCount = 4;
  static const int maxCount = 14;
  static const int defaultCount = 12;
}
