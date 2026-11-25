import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/services/api.dart';
import 'package:flutter_app/widgets/app_logo.dart';

void main() {
  test('App version and Play Store parsers work properly', () {
    // Verify pubspec version parser strips +build number
    expect(
      SupabaseAPI.parsePubspecVersion('name: flutter_app\nversion: 2.4.5+19\n'),
      '2.4.5',
    );

    // Verify Google Play Store version HTML parser extracts app version and ignores reviews
    const samplePlayHtml =
        'data collection"]]],1],null,null,null,[[["1.18.2"]],[[[37]],[[[24,"7.0"]]]]],'
        '["11.5.5",null,[[["vaf_phase1"]]]]';
    expect(SupabaseAPI.parsePlayStoreVersion(samplePlayHtml), '1.18.2');
    expect(
      SupabaseAPI.parsePlayStoreVersion('[[["Varies with device"]],[[[37]]]]'),
      isNull,
    );
  });

  testWidgets('App smoke test and AppLogo asset verification', (WidgetTester tester) async {
    // Verify logo assets paths for languages
    expect(AppLogo.assetForLanguage('en'), 'assets/images/logo_en.png');
    expect(AppLogo.assetForLanguage('ta'), 'assets/images/logo_ta.png');

    final loadedVersion = await tester.runAsync(() => SupabaseAPI.loadAppVersion());
    expect(loadedVersion, isNotNull);
    expect(loadedVersion!.contains('+'), isFalse);
    expect(SupabaseAPI.currentAppVersion, loadedVersion);

    // Build the app
    await tester.pumpWidget(const SriAashikaaApp());
    await tester.pump();

    // Verify MaterialApp mounts properly
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
