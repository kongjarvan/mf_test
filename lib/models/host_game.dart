import 'game_role.dart';
import 'player.dart';

class VictoryResult {
  const VictoryResult({required this.winners});

  /// 동시 승리 우선순위 순으로 정렬된 승리 세력 이름 목록.
  final List<String> winners;
}

/// 사회자 기록용 세션 상태. 영속 저장은 하지 않는다.
class HostGame {
  HostGame({
    List<Player>? players,
    this.day = 1,
    this.nightNotes = '',
    this.dayNotes = '',
    this.executionDayChoice = 0,
    this.nightGuidanceText = '',
    Map<int, String>? nightActionTargets,
    this.revealRolesDuringGame = false,
  })  : nightActionTargets = nightActionTargets ?? {},
        players = players ?? Player.createTable(Player.defaultCount);

  List<Player> players;

  /// 기존 호환용 플래그(현재는 직업을 항상 표시).
  bool revealRolesDuringGame;
  int day;
  String nightNotes;
  String dayNotes;

  /// 낮 처형 결정. **0** = 아직 선택 안 함(밤으로 불가), **-1** = 처형 없음, **양수** = 처형 슬롯.
  int executionDayChoice;

  /// 처형 대상 슬롯(없거나 미선택·처형 없음이면 null).
  int? get executionSlot =>
      executionDayChoice > 0 ? executionDayChoice : null;

  /// 밤 화면 — 안내 문구 초안(추후 자동 생성 등)
  String nightGuidanceText;

  /// 밤 행동 대상 기록: 슬롯 → 자유 입력(이름·번호 등)
  Map<int, String> nightActionTargets;

  /// 직전 밤→낮 전환 시 표시했던 「밤 킬 현황」 팝업 본문(낮에서 다시 보기용).
  String? lastNightKillPopupText;

  void reset() {
    final savedNames = players.map((p) => p.name).toList();
    players = Player.createTable(players.length);
    for (var i = 0; i < players.length; i++) {
      if (i < savedNames.length) {
        players[i].name = savedNames[i];
      }
    }
    day = 1;
    nightNotes = '';
    dayNotes = '';
    executionDayChoice = 0;
    nightGuidanceText = '';
    nightActionTargets.clear();
    revealRolesDuringGame = false;
    lastNightKillPopupText = null;
  }

  /// 직업 문자열은 항상 표시.
  String formatRoleLabel(GameRole role) {
    return role.label;
  }

  /// 인원을 바꾼다. 줄이면 **맨 뒤 슬롯**부터 제거된다.
  void resizePlayerCount(int newCount) {
    final n = newCount.clamp(Player.minCount, Player.maxCount);
    if (n == players.length) return;
    if (n > players.length) {
      for (var s = players.length + 1; s <= n; s++) {
        players.add(Player(slot: s));
      }
    } else {
      players.removeRange(n, players.length);
    }
  }

  int countAliveByFaction(Faction f) {
    return players.where((p) => p.alive && p.role.faction == f).length;
  }

  int get aliveCount => players.where((p) => p.alive).length;

  /// 현재 생존 상태 기준으로 승리 조건을 판정한다.
  /// 아직 게임이 끝나지 않았으면 null 반환.
  VictoryResult? checkVictory() {
    final aliveMafia = countAliveByFaction(Faction.mafia);
    final aliveCitizen = countAliveByFaction(Faction.citizen);
    final aliveNeutral = countAliveByFaction(Faction.neutral);
    final aliveZombie = countAliveByFaction(Faction.zombie);
    final total = aliveCount;

    // 시민팀: 마피아·중립·좀비 전원 사망
    final citizenWins = aliveMafia == 0 && aliveNeutral == 0 && aliveZombie == 0;
    // 마피아팀: 생존 마피아 수 ≥ 시민·중립 합 (좀비는 별도 진영 — 계산 제외)
    final mafiaWins =
        aliveMafia > 0 && aliveMafia >= (aliveCitizen + aliveNeutral);

    // 좀비는 최우선: 조건 충족 시 단독 승리(연쇄살인마·마녀·마피아·시민 모두 제침).
    // 연쇄살인마·마녀는 좀비가 없을 때 트리거 세력과 공동 승리.
    final zombieWins = aliveZombie > 0 && aliveZombie * 2 >= total;

    if (!citizenWins && !mafiaWins && !zombieWins) return null;

    final winners = <String>[];
    if (zombieWins) {
      winners.add('좀비 세력');
    } else {
      final skWins = players.any((p) => p.alive && p.role == GameRole.serialKiller);
      final witchWins = players.any((p) => p.alive && p.role == GameRole.witch);
      if (skWins || witchWins) {
        if (skWins) winners.add('연쇄 살인마');
        if (witchWins) winners.add('마녀');
      } else {
        if (mafiaWins) winners.add('마피아팀');
        if (citizenWins) winners.add('시민팀');
      }
    }

    return VictoryResult(winners: winners);
  }

  /// 밤으로 갈 수 있는지(처형 결정이 확정되었는지).
  bool get canGoToNightFromDay {
    if (executionDayChoice == 0) return false;
    if (executionDayChoice == -1) return true;
    return players.any((p) => p.slot == executionDayChoice && p.alive);
  }
}
