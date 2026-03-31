import 'game_role.dart';
import 'player.dart';

/// 사회자 기록용 세션 상태. 영속 저장은 하지 않는다.
class HostGame {
  HostGame({
    List<Player>? players,
    this.day = 1,
    this.isNight = false,
    this.nightNotes = '',
    this.dayNotes = '',
  }) : players = players ?? Player.createTable();

  List<Player> players;
  int day;
  bool isNight;
  String nightNotes;
  String dayNotes;

  void reset() {
    players = Player.createTable();
    day = 1;
    isNight = false;
    nightNotes = '';
    dayNotes = '';
  }

  int countAliveByFaction(Faction f) {
    return players.where((p) => p.alive && p.role.faction == f).length;
  }

  int get aliveCount => players.where((p) => p.alive).length;
}
