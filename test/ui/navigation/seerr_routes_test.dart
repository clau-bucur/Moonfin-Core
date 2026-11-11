import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/navigation/app_router.dart';
import 'package:moonfin/util/video_app_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TV Seerr links resolve to registered screens', () {
    for (final path in [
      '/seerr/discover',
      '/seerr/requests?tab=issues',
      '/seerr/browse?filterType=movie',
      '/seerr/media/8844?mediaType=movie',
      '/seerr/person/31',
      '/seerr/collection/84',
    ]) {
      final uri = Uri.parse(path);
      expect(VideoAppProfile.allowsRoute(uri.path), isTrue, reason: path);
      final matches = appRouter.configuration.findMatch(uri);
      expect(matches.isError, isFalse, reason: path);
      expect(matches.matches, isNotEmpty, reason: path);
    }
  });
}
