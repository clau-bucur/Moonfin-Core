import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

import '../../auth/repositories/session_repository.dart';
import '../../util/platform_detection.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _recheckDebounce;

  /// Startup, a network flip and the retry below can all ask at once, and two
  /// probes would each open a connection and each read the verdict from before
  /// either answered.
  Future<void>? _inFlightProbe;

  /// Retry an unreachable server with a growing delay, even when the network
  /// interface itself has not changed.
  Timer? _retryTimer;
  int _retryAttempt = 0;
  final Duration _retryBase;
  static const _retryCap = Duration(seconds: 30);

  static const _probeAttempts = 2;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  bool _serverReachable = true;
  bool get serverReachable => _serverReachable;

  bool get canReachServer => _isOnline && _serverReachable;


  /// Whether the only link is mobile data. Read by prefetchers that should
  /// not spend a metered connection on artwork the user may never scroll to.
  /// False until the first probe answers, and false on a link the platform
  /// can't classify, since holding back on a healthy Wi-Fi costs more than
  /// warming a few posters on a plan.
  bool get isCellularOnly => _isCellularOnly;
  bool _isCellularOnly = false;

  static bool _cellularOnly(List<ConnectivityResult> results) {
    final live = results.where((r) => r != ConnectivityResult.none).toList();
    return live.isNotEmpty &&
        live.every((r) => r == ConnectivityResult.mobile);
  }

  /// Whether the initial connectivity check has completed.
  /// Stream events are ignored until this is true to prevent
  /// a false "offline" flash at boot.
  bool _initialCheckDone = false;

  ConnectivityService({
    @visibleForTesting Connectivity? connectivity,
    @visibleForTesting Duration retryBase = const Duration(seconds: 5),
  }) : _connectivity = connectivity ?? Connectivity(),
       _retryBase = retryBase;

  void initialize() {
    if (!PlatformDetection.isAppleTV) {
      _subscription =
          _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    }
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    if (PlatformDetection.isAppleTV) {
      _isOnline = true;
      await _checkServerReachability();
      if (_serverReachable) {
        _nudgeSocket();
      }
      _initialCheckDone = true;
      notifyListeners();
      return;
    }
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    _isCellularOnly = _cellularOnly(results);
    if (_isOnline) {
      await _checkServerReachability();
      if (_serverReachable) {
        _nudgeSocket();
      }
    } else {
      _serverReachable = false;
    }
    _initialCheckDone = true;
    notifyListeners();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!_initialCheckDone) return;

    final wasOnline = _isOnline;
    final wasReachable = _serverReachable;
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    _isCellularOnly = _cellularOnly(results);

    if (!_isOnline) {
      _retryTimer?.cancel();
      if (wasOnline) {
        _serverReachable = false;
        notifyListeners();
      }
      return;
    }

    if (!wasOnline) {
      notifyListeners();
    }

    _recheckDebounce?.cancel();
    _recheckDebounce = Timer(const Duration(seconds: 2), () {
      _checkServerReachability().then((_) {
        if (_serverReachable && !wasReachable) {
          _nudgeSocket();
        }
      });
    });
  }

  /// Called when the app returns to the foreground. Runs a sync that was
  /// deferred while the app was backgrounded.


  void onAppResumed() {
    if (_isOnline) unawaited(_checkServerReachability());
  }

  /// Every path that reports the network came back lands here, and that is
  /// the moment a socket part way through its backoff should stop waiting.
  void _nudgeSocket() {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<SessionRepository>()) return;
    getIt<SessionRepository>().onNetworkRegained();
  }

  /// A server client was just registered for [serverId] (session restore,
  /// sign-in, account or server switch). The boot-time check runs before any
  /// client exists, so sign-in must trigger a fresh reachability check.
  Future<void> onServerClientReady(String serverId) async {
    if (!_isOnline) return;
    // Straight to the probe rather than recheckNow, which would add a
    // connectivity_plus call on Apple TV, where the service never makes one.
    await _checkServerReachability();
    if (_serverReachable) _nudgeSocket();
  }

  Future<void> _checkServerReachability() => _inFlightProbe ??= _probeServer()
      .whenComplete(() => _inFlightProbe = null);

  Future<void> _probeServer() async {
    if (!GetIt.instance.isRegistered<MediaServerClient>()) return;
    final client = GetIt.instance<MediaServerClient>();
    final wasReachable = _serverReachable;
    var reachable = false;
    // A pooled connection the server already dropped fails exactly like a
    // server that went away. Retry before declaring it unreachable. The failure takes
    // the bad connection with it, so the second try needs no wait in front.
    // Each server type pings its own route (Silo has no /System/Ping), and
    // the client's ping counts a 401 as an answer (see SystemApi.ping).
    for (var attempt = 0; attempt < _probeAttempts && !reachable; attempt++) {
      try {
        reachable = await client.systemApi.ping();
      } catch (_) {
        // Ping shouldn't throw, but a client that does still means no answer.
      }
    }
    _serverReachable = reachable;
    if (!_serverReachable && wasReachable) {
      ServerLog.network(
        'Server marked unreachable, every probe failed',
        level: ServerLogLevel.warning,
      );
    }
    if (_serverReachable) {
      if (!wasReachable) ServerLog.network('Server reachable again');
      _retryAttempt = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
    } else if (_isOnline) {
      _scheduleRetry();
    }
    notifyListeners();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final delay = _retryBase * (1 << _retryAttempt);
    _retryTimer = Timer(delay < _retryCap ? delay : _retryCap, () {
      _retryTimer = null;
      if (!_isOnline || _serverReachable) return;
      if (_retryAttempt < 6) _retryAttempt++;
      _checkServerReachability().then((_) {
        if (_serverReachable) _nudgeSocket();
      });
    });
  }

  /// Resolves true as soon as the device reports online, or false after
  /// [timeout]. Lets cold-boot startup wait out the Wi-Fi association window
  /// before reporting that the server is unavailable.
  Future<bool> waitForOnline(Duration timeout) async {
    if (_isOnline && _initialCheckDone) return true;
    final completer = Completer<bool>();
    void onChange() {
      if (_isOnline && !completer.isCompleted) {
        completer.complete(true);
      }
    }

    addListener(onChange);
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(_isOnline);
    });
    final result = await completer.future;
    timer.cancel();
    removeListener(onChange);
    return result;
  }

  Future<void> recheckNow() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    _isCellularOnly = _cellularOnly(results);
    if (_isOnline) {
      await _checkServerReachability();
    } else {
      _retryTimer?.cancel();
      _serverReachable = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _recheckDebounce?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
