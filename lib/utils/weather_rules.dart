import '../models/game_role.dart';
import '../models/game_weather.dart';
import '../models/host_game.dart';

/// 생존 인원 수(진영별). 날씨 조건 판정용.
class WeatherFactionCounts {
  const WeatherFactionCounts({
    required this.mafia,
    required this.neutral,
    required this.citizen,
    required this.zombie,
  });

  final int mafia;
  final int neutral;
  final int citizen;
  final int zombie;

  factory WeatherFactionCounts.fromGame(HostGame game) {
    return WeatherFactionCounts(
      mafia: game.countAliveByFaction(Faction.mafia),
      neutral: game.countAliveByFaction(Faction.neutral),
      citizen: game.countAliveByFaction(Faction.citizen),
      zombie: game.countAliveByFaction(Faction.zombie),
    );
  }

  /// 마피아가 아닌 진영 합(중립+시민+좀비).
  int get sumNonMafia => neutral + citizen + zombie;

  /// 좀비가 아닌 진영 합(마피아+중립+시민).
  int get sumNonZombie => mafia + neutral + citizen;
}

/// 안개: (마+중)≤2 이고 좀비×2 ≥ (마+중+시).
bool fogBiasConditionMet(WeatherFactionCounts c) {
  if (c.mafia + c.neutral > 2) return false;
  if (c.zombie * 2 < c.sumNonZombie) return false;
  return true;
}

/// 눈(중립 유리): 생존 중립 ≥1, 마피아×2 ≥ (중립+시민+좀비).
bool neutralSnowBiasConditionMet(WeatherFactionCounts c) {
  if (c.neutral < 1) return false;
  if (c.mafia * 2 < c.sumNonMafia) return false;
  return true;
}

/// 비(마피아 유리): 중립 0, 마피아×2 ≥ (시민+좀비).
bool mafiaRainBiasConditionMet(WeatherFactionCounts c) {
  if (c.neutral != 0) return false;
  if (c.mafia * 2 < c.citizen + c.zombie) return false;
  return true;
}

/// 생존 진영 수로 오늘 날씨를 정한다. **안개 → 눈 → 비** 순으로 첫 번째로 맞는 조건을 쓰고,
/// 어느 것도 아니면 **맑은 날**이다.
GameWeather computeAutomaticWeather(WeatherFactionCounts c) {
  if (fogBiasConditionMet(c)) return GameWeather.fog;
  if (neutralSnowBiasConditionMet(c)) return GameWeather.snow;
  if (mafiaRainBiasConditionMet(c)) return GameWeather.rain;
  return GameWeather.clearDay;
}

extension HostGameWeatherX on HostGame {
  WeatherFactionCounts get weatherFactionCounts =>
      WeatherFactionCounts.fromGame(this);

  GameWeather get automaticWeather =>
      computeAutomaticWeather(weatherFactionCounts);
}

bool weatherBiasConditionMet(GameWeather weather, WeatherFactionCounts c) {
  return switch (weather) {
    GameWeather.unspecified => false,
    GameWeather.clearDay => false,
    GameWeather.fog => fogBiasConditionMet(c),
    GameWeather.snow => neutralSnowBiasConditionMet(c),
    GameWeather.rain => mafiaRainBiasConditionMet(c),
  };
}

/// 낮 화면 등에 쓸 조건 설명(줄바꿈 포함 가능).
String weatherBiasConditionSummary(GameWeather weather, WeatherFactionCounts c) {
  final head =
      '생존: 마피아 ${c.mafia} · 중립 ${c.neutral} · 시민 ${c.citizen} · 좀비 ${c.zombie}';
  switch (weather) {
    case GameWeather.unspecified:
      return '';
    case GameWeather.clearDay:
      return '$head\n'
          '맑은 날(시민 유리): 안개·눈·비 조건에 해당하지 않을 때 자동 적용됩니다.\n'
          '(맑은 날 전용 추가 규칙은 추후 정의)';
    case GameWeather.fog:
      final le2 = c.mafia + c.neutral <= 2;
      final z2 = c.zombie * 2 >= c.sumNonZombie;
      return '$head\n'
          '안개(좀비 유리)\n'
          '· 마피아+중립 ≤ 2: ${le2 ? "충족" : "미충족"} (현재 ${c.mafia + c.neutral}명)\n'
          '· 좀비×2 ≥ (마+중+시): ${z2 ? "충족" : "미충족"} (${c.zombie}×2 = ${c.zombie * 2}, 상대 합 ${c.sumNonZombie})\n'
          '→ ${le2 && z2 ? "유리 조건 충족" : "유리 조건 미충족"}';
    case GameWeather.snow:
      final n1 = c.neutral >= 1;
      final m2 = c.mafia * 2 >= c.sumNonMafia;
      return '$head\n'
          '눈(중립 유리)\n'
          '· 생존 중립 ≥ 1: ${n1 ? "충족" : "미충족"}\n'
          '· 마피아×2 ≥ (중+시+좀): ${m2 ? "충족" : "미충족"} (${c.mafia}×2 = ${c.mafia * 2}, 상대 합 ${c.sumNonMafia})\n'
          '→ ${n1 && m2 ? "유리 조건 충족" : "유리 조건 미충족"}';
    case GameWeather.rain:
      final n0 = c.neutral == 0;
      final m2 = c.mafia * 2 >= c.citizen + c.zombie;
      return '$head\n'
          '비(마피아 유리)\n'
          '· 생존 중립 0: ${n0 ? "충족" : "미충족"}\n'
          '· 마피아×2 ≥ (시+좀): ${m2 ? "충족" : "미충족"} (${c.mafia}×2 = ${c.mafia * 2}, 상대 합 ${c.citizen + c.zombie})\n'
          '→ ${n0 && m2 ? "유리 조건 충족" : "유리 조건 미충족"}';
  }
}

/// 날씨 효과 요약(야간 해석 등 연동용).
class WeatherResolution {
  const WeatherResolution({
    required this.weather,
    required this.biasActive,
    required this.messages,
  });

  final GameWeather weather;

  /// [weatherBiasConditionMet]와 동일한 의미.
  final bool biasActive;

  final List<String> messages;
}

WeatherResolution resolveWeatherEffects({
  required GameWeather weather,
  required WeatherFactionCounts counts,
}) {
  if (weather == GameWeather.unspecified) {
    return const WeatherResolution(
      weather: GameWeather.unspecified,
      biasActive: false,
      messages: [],
    );
  }
  final active = weatherBiasConditionMet(weather, counts);
  if (weather == GameWeather.clearDay) {
    return WeatherResolution(
      weather: weather,
      biasActive: true,
      messages: [
        '맑은 날(시민 유리): 안개·눈·비 조건 불충족 시 자동 적용',
        weatherBiasConditionSummary(weather, counts),
      ],
    );
  }
  final label = weather.label;
  final factionTag = switch (weather) {
    GameWeather.fog => '좀비 세력',
    GameWeather.snow => '중립',
    GameWeather.rain => '마피아',
    GameWeather.clearDay => '시민',
    GameWeather.unspecified => '',
  };
  return WeatherResolution(
    weather: weather,
    biasActive: active,
    messages: [
      '$label($factionTag 유리): 조건 ${active ? "충족" : "미충족"}',
      weatherBiasConditionSummary(weather, counts),
    ],
  );
}

/// [game] 생존자 기준 자동 날씨로 효과 요약.
WeatherResolution resolveWeatherEffectsForGame(HostGame game) {
  final counts = WeatherFactionCounts.fromGame(game);
  final weather = computeAutomaticWeather(counts);
  return resolveWeatherEffects(weather: weather, counts: counts);
}
