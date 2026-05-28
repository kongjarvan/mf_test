import 'package:flutter/material.dart';

/// 인원 현황 원형 좌석 라벨 표시 방식(번호·이름 ↔ 직업 전환).
enum RosterSeatDisplayMode {
  slotAndName,
  roleLabel;

  RosterSeatDisplayMode get next => switch (this) {
        RosterSeatDisplayMode.slotAndName => RosterSeatDisplayMode.roleLabel,
        RosterSeatDisplayMode.roleLabel => RosterSeatDisplayMode.slotAndName,
      };

  /// 버튼 툴팁: 한 번 탭했을 때 바뀔 모드 안내.
  String get tooltipNext => switch (this) {
        RosterSeatDisplayMode.slotAndName => '직업으로 보기',
        RosterSeatDisplayMode.roleLabel => '번호·이름으로 보기',
      };

  IconData get icon => switch (this) {
        RosterSeatDisplayMode.slotAndName => Icons.badge_outlined,
        RosterSeatDisplayMode.roleLabel => Icons.work_outline,
      };
}
