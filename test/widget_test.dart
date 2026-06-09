import 'package:flutter_test/flutter_test.dart';

import 'package:notespot/main.dart';

void main() {
  testWidgets('App builds', (tester) async {
    await tester.pumpWidget(const NoteSpotApp());
    expect(find.byType(NoteSpotApp), findsOneWidget);
  });
}