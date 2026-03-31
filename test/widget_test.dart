import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mf_test/main.dart';

void main() {
  testWidgets('설정 화면이 뜬다', (WidgetTester tester) async {
    await tester.pumpWidget(const MafiaHostApp());
    await tester.pumpAndSettle();

    expect(find.text('게임 설정'), findsOneWidget);
    expect(find.byKey(const Key('setup_complete')), findsOneWidget);
  });
}
