import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yuan/main.dart';

void main() {
  testWidgets('App launches and bottom nav has 5 tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const YuanApp());
    await tester.pumpAndSettle();

    // 底部导航 5 个模块
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('收支'), findsOneWidget);
    expect(find.text('资债'), findsOneWidget);
    expect(find.text('账户'), findsOneWidget);
    expect(find.text('分析'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('Entry screen has expense/income tabs and keypad', (WidgetTester tester) async {
    await tester.pumpWidget(const YuanApp());
    await tester.pumpAndSettle();

    // 默认停在第一个 Tab = 收支
    expect(find.text('支出金额'), findsOneWidget);
    expect(find.text('收入金额'), findsNothing);

    // 切换到"收入"
    await tester.tap(find.text('收入金额').hitTestable().first);
    await tester.pumpAndSettle();
  });
}
