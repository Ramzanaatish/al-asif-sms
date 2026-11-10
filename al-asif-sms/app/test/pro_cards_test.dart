import 'package:alasif_sms/widgets/pro_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StatCard shows label and value without overflow',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 100,
            child: StatCard(
              label: 'Total Students',
              value: '227',
              icon: Icons.people,
              color: Colors.indigo,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Total Students'), findsOneWidget);
    expect(find.text('227'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ReportTile shows title and subtitle and taps',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 76,
            child: ReportTile(
              title: 'Fee Collection Report',
              subtitle: 'Month-wise fee collection summary',
              icon: Icons.bar_chart,
              color: Colors.indigo,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Fee Collection Report'), findsOneWidget);
    expect(find.text('Month-wise fee collection summary'), findsOneWidget);
    await tester.tap(find.byType(ReportTile));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('statColumns adapts to width', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Text('${statColumns(context)}'),
        ),
      ),
    );
    expect(find.text('4'), findsOneWidget);
  });
}
