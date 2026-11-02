import 'package:get_it/get_it.dart';

import '../data/services/connectivity_service.dart';

/// Reachability gates server actions; there is no downloaded-media fallback.
bool canReachActiveServer() =>
    !GetIt.instance.isRegistered<ConnectivityService>() ||
    GetIt.instance<ConnectivityService>().canReachServer;
