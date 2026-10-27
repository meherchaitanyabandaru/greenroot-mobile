// The Terms & Conditions screen shows the published document (all 30
// sections), readable before sign-up.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/profile/legal_document_screen.dart';
import 'package:greenroot_mobile/features/profile/markdown_view.dart';

void main() {
  test('the bundled terms are the published version, with all 30 sections', () {
    final app = File('assets/legal/terms-and-conditions.md').readAsStringSync();
    expect(RegExp(r'^## \d+\. ', multiLine: true).allMatches(app).length, 30);
    final published =
        File('../greenroot-infra/docs/legal/terms-and-conditions.md');
    if (published.existsSync()) {
      expect(app, published.readAsStringSync(), reason: 'keep the copies in sync');
    }
  });

  testWidgets('markdown: headings, lists and bold', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
            body: MarkdownView(
                source:
                    '# T\n## 1. INTRO\n- a point\n1. first\n**Bold** text',),),
      ),
    );
    expect(find.text('T'), findsOneWidget);
    expect(find.text('1. INTRO'), findsOneWidget);
    expect(find.text('a point'), findsOneWidget);
    expect(find.text('first'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.textContaining('Bold', findRichText: true), findsOneWidget);
  });

  testWidgets('the terms screen renders the document', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: LegalDocumentScreen(type: LegalDocumentType.termsOfService),),);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),);
    await tester.pump();
    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.text('1. INTRODUCTION AND ACCEPTANCE'), findsOneWidget);
  });
}
