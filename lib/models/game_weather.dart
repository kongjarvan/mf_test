import 'game_role.dart';



/// 낮마다 사회자가 고르는 날씨.

enum GameWeather {

  unspecified,



  /// 맑은 날 — 시민팀 유리(세부 조건 추후).

  clearDay,



  /// 눈 — 중립 유리(생존 중립 ≥1 & 마피아×2 ≥ 비마피아 합).

  snow,



  /// 비 — 마피아 유리(중립 0 & 마피아×2 ≥ 시민+좀비).

  rain,



  /// 안개 — 좀비 세력 유리((마+중)≤2 & 좀비×2 ≥ 마+중+시).

  fog,

}



extension GameWeatherX on GameWeather {

  String get label => switch (this) {

        GameWeather.unspecified => '(내부용·수동 선택 없음)',

        GameWeather.clearDay => '맑은 날',

        GameWeather.snow => '눈이 옴',

        GameWeather.rain => '비가 옴',

        GameWeather.fog => '안개',

      };



  String get biasHint => switch (this) {

        GameWeather.unspecified =>
          '자동 날씨에서는 사용하지 않습니다.',

        GameWeather.clearDay => '시민팀에 유리 (발동 조건 추후 정의)',

        GameWeather.snow => '중립에 유리 — 생존 중립 ≥1명, 마피아×2 ≥ (중립+시민+좀비)',

        GameWeather.rain => '마피아에 유리 — 생존 중립 0명, 마피아×2 ≥ (시민+좀비)',

        GameWeather.fog => '좀비 세력에 유리 — (마피아+중립)≤2, 좀비×2 ≥ (마+중+시)',

      };



  Faction? get favoredFactionHint => switch (this) {

        GameWeather.clearDay => Faction.citizen,

        GameWeather.snow => Faction.neutral,

        GameWeather.rain => Faction.mafia,

        GameWeather.fog => Faction.zombie,

        GameWeather.unspecified => null,

      };

}



const List<GameWeather> kGameWeatherPickerOrder = [

  GameWeather.unspecified,

  GameWeather.clearDay,

  GameWeather.snow,

  GameWeather.rain,

  GameWeather.fog,

];

