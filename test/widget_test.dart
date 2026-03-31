import 'package:flutter_test/flutter_test.dart';

import 'package:mf_test/main.dart';

void main() {
  testWidgets('사회자 기록 화면이 뜬다', (WidgetTester tester) async {
    await tester.pumpWidget(const MafiaHostApp());

    expect(find.text('사회자 기록'), findsOneWidget);
    expect(find.text('플레이어'), findsOneWidget);
  });
}
