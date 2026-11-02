import 'package:playback_silo/playback_silo.dart';
import 'package:server_core/server_core.dart';

import '../auth/services/silo_token_storage.dart';

/// The Silo plugin for the app's [client].
///
/// Its resolver and session service share the same client and session registry.
SiloPlugin siloPluginFor(
  MediaServerClient client, {
  SiloPlaybackEnvironment Function()? environment,
}) => SiloPlugin(siloClientOf(client) ?? client, environment: environment);
