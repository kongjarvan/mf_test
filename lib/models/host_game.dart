import 'game_role.dart';
import 'player.dart';

/// 사회자 기록용 세션 상태. 영속 저장은 하지 않는다.
class HostGame {
  HostGame({
    List<Player>? players,
    this.day = 1,
    this.nightNotes = '',
    this.dayNotes = '',
    this.weatherNote = '',
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

  /// 낮 화면 — 날씨(규칙 확정 후 연결 예정)
  String weatherNote;

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
    weatherNote = '';
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

  /// 밤으로 갈 수 있는지(처형 결정이 확정되었는지).
  bool get canGoToNightFromDay {
    if (executionDayChoice == 0) return false;
    if (executionDayChoice == -1) return true;
    return players.any((p) => p.slot == executionDayChoice && p.alive);
  }
}
