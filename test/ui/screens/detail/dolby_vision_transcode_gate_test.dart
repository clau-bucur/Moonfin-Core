
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/detail/item_detail_screen.dart';
import 'package:moonfin/util/platform_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Streaming Dolby Vision fallback on devices without HDR support.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserPreferences prefs;

  const serverId = 'http://server';
  const itemId = 'episode-dv';

  // A 4K Dolby Vision episode as the server reports it: the original media
  // source carries a DOVI video stream, regardless of what was downloaded.
  AggregatedItem dvItem() => AggregatedItem(
    id: itemId,
    serverId: serverId,
    rawData: {
      'Id': itemId,
      'Type': 'Episode',
      'Name': 'DV Episode',
      'MediaSources': [
        {
          'Id': 'source-1',
          'MediaStreams': [
            {'Type': 'Video', 'Codec': 'hevc', 'VideoRangeType': 'DOVI'},
          ],
        },
      ],
    },
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    final store = PreferenceStore();
    await store.init();
    prefs = UserPreferences(store);


    final getIt = GetIt.instance;
    getIt.registerSingleton<UserPreferences>(prefs);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    PlatformDetection.setDisplayHdrTypes(null);
    PlatformDetection.setTvMode(false);
    PlatformDetection.setInterfaceLayout(InterfaceLayout.automatic);
  });

  // The TV the bug was seen on: Android, TV mode, display reports no HDR at
  // all, so the gate's HDR checks would otherwise force a transcode.
  void setUpNoHdrAndroidTv() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    PlatformDetection.setTvMode(true);
    PlatformDetection.setDisplayHdrTypes(null);
  }

  Future<BuildContext> mountContext(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    return tester.element(find.byType(Scaffold));
  }



  testWidgets(
    'an unsupported Dolby Vision episode forces streaming transcode',
    (tester) async {
      setUpNoHdrAndroidTv();

      final context = await mountContext(tester);
      final forceTranscode = await shouldForceTranscodeForDolbyVisionQueue(
        context,
        [dvItem()],
      );

      expect(
        forceTranscode,
        isTrue,
        reason: 'the no-HDR display needs the transcode',
      );

      debugDefaultTargetPlatformOverride = null;
    },
  );



  testWidgets('a non-TV platform never forces the transcode', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    PlatformDetection.setTvMode(false);
    PlatformDetection.setDisplayHdrTypes(null);

    final context = await mountContext(tester);
    final forceTranscode = await shouldForceTranscodeForDolbyVisionQueue(
      context,
      [dvItem()],
    );

    expect(forceTranscode, isFalse);

    debugDefaultTargetPlatformOverride = null;
  });
}
