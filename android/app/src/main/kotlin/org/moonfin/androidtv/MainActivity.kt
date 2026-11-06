package org.moonfin.androidtv

import android.app.Activity
import android.app.ActivityManager
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.hardware.display.DisplayManager
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.PowerManager
import android.os.SystemClock
import android.util.Rational
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import com.ryanheise.audioservice.AudioServicePlugin
import com.ryanheise.audioservice.AudioServiceState
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread

import android.hardware.input.InputManager

class MainActivity : AudioServiceActivity() {

    private var methodChannel: MethodChannel? = null
    private var discoveryMulticastLock: android.net.wifi.WifiManager.MulticastLock? = null
    private var audioCapsEventsChannel: EventChannel? = null
    private var audioCapsSink: EventChannel.EventSink? = null
    private var audioDeviceCallback: AudioDeviceCallback? = null
    private var displayCapsEventsChannel: EventChannel? = null
    private var displayCapsSink: EventChannel.EventSink? = null
    private var displayListener: DisplayManager.DisplayListener? = null
    private var externalPlayerChannel: MethodChannel? = null
    private var externalPlayerPendingResult: MethodChannel.Result? = null
    private var gamepadChannel: MethodChannel? = null
    // GameInputRouter is deliberately Android-free, so the Activity owns the
    // registration and forwards.
    private val gameInputManager by lazy {
        getSystemService(Context.INPUT_SERVICE) as? InputManager
    }

    private val gameInputDeviceListener = object : InputManager.InputDeviceListener {
        override fun onInputDeviceAdded(deviceId: Int) {}

        override fun onInputDeviceRemoved(deviceId: Int) =
            gameInputRouter.onDeviceRemoved(deviceId)

        override fun onInputDeviceChanged(deviceId: Int) =
            gameInputRouter.onDeviceChanged(deviceId)
    }

    private val gameInputRouter = GameInputRouter(object : GameInputRouter.Callbacks {
        override fun onEmulatorButton(label: String, pressed: Boolean, device: Map<String, String>?) {
            // Game playback is not part of this TV video application.
        }

        override fun onEmulatorKeyboard(keyCode: Int) {}

        override fun onNavigate(axis: String, direction: String) = sendGamepadNavigate(axis, direction)
    })
    private var watchNextChannel: MethodChannel? = null
    private var watchNextPublisher: WatchNextPublisher? = null
    private var previewChannelPublisher: PreviewChannelPublisher? = null
    private var pendingDeepLink: String? = null
    private var pipEnabled = false
    private val handler = Handler(Looper.getMainLooper())
    private var dismissRunnable: Runnable? = null

    // The Handler half of a BurstCoalescer: one pending runnable, replaced on
    // every event, so the trigger that reaches the emit is the burst's last.
    private inner class DebouncedEmit(
        private val coalescer: BurstCoalescer,
        private val emit: (String) -> Unit,
    ) {
        private var pending: Runnable? = null

        fun schedule(trigger: String) {
            val at = coalescer.onEvent(SystemClock.uptimeMillis())
            pending?.let { handler.removeCallbacks(it) }
            val runnable = Runnable {
                pending = null
                coalescer.fired()
                emit(trigger)
            }
            pending = runnable
            handler.postAtTime(runnable, at)
        }

        fun cancel() {
            pending?.let { handler.removeCallbacks(it) }
            pending = null
            coalescer.fired()
        }
    }

    private val displayEmit = DebouncedEmit(
        BurstCoalescer(DISPLAY_EMIT_DEBOUNCE_MS, DISPLAY_EMIT_MAX_WAIT_MS),
    ) { trigger -> emitDisplayCapabilities(trigger) }

    private val audioEmit = DebouncedEmit(
        BurstCoalescer(AUDIO_EMIT_DEBOUNCE_MS, AUDIO_EMIT_MAX_WAIT_MS),
    ) { emitAudioCapabilities() }

    private fun emitAudioCapabilities() {
        audioCapsSink?.success(AudioCapabilities.query(this))
    }

    private fun unregisterAudioDeviceCallback() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioDeviceCallback?.let { callback ->
                (getSystemService(Context.AUDIO_SERVICE) as? AudioManager)
                    ?.unregisterAudioDeviceCallback(callback)
            }
        }
        audioDeviceCallback = null
        audioEmit.cancel()
    }

    companion object {
        private var engineHandedToActivity: FlutterEngine? = null
        private const val CHANNEL = "org.moonfin.androidtv/pip"
        private const val EXTERNAL_PLAYER_CHANNEL = "moonfin/external_player"
        private const val ACTION_PLAY_PAUSE = "org.moonfin.androidtv.ACTION_PIP_PLAY_PAUSE"
        private const val DISMISS_DELAY_MS = 300L
        private const val PLATFORM_CHANNEL = "org.moonfin.androidtv/platform"
        private const val GAMEPAD_CHANNEL = "org.moonfin.androidtv/gamepad"
        private const val WATCH_NEXT_CHANNEL = WatchNextWorker.CHANNEL
        private const val AUDIO_CAPS_EVENTS_CHANNEL =
            "org.moonfin.androidtv/audioCapabilitiesEvents"
        private const val DISPLAY_CAPS_EVENTS_CHANNEL =
            "org.moonfin.androidtv/displayCapabilitiesEvents"
        private const val DISPLAY_EMIT_DEBOUNCE_MS = 750L
        private const val DISPLAY_EMIT_MAX_WAIT_MS = 3_000L
        // The HDMI audio route drops and returns between 1.8 and 3.2 s apart
        // when the link renegotiates at playback start and stop, so the
        // debounce has to outlast that gap or the removal escapes on its own
        // as a stereo, no-passthrough answer.
        private const val AUDIO_EMIT_DEBOUNCE_MS = 4_000L
        private const val AUDIO_EMIT_MAX_WAIT_MS = 12_000L
        private const val EXTERNAL_PLAYER_PROXY_REQUEST_CODE = 17115
        private const val EXTRA_EXTERNAL_PLAYER_LAUNCH_INTENT = "moonfin.external_player.launch_intent"
        private const val EXTRA_EXTERNAL_PLAYER_ERROR_CODE = "moonfin.external_player.error_code"
        private const val EXTRA_EXTERNAL_PLAYER_ERROR_MESSAGE = "moonfin.external_player.error_message"
        private const val EXTERNAL_PLAYER_CHOOSER_TITLE = "Play with"
        private const val EXTERNAL_PLAYER_SAMPLE_URL = "http://127.0.0.1/sample.mp4"

        private const val API_MX_RESULT_ID = "com.mxtech.intent.result.VIEW"
        private const val API_MX_RESULT_END_BY = "end_by"
        private const val API_MX_RESULT_END_BY_PLAYBACK_COMPLETION = "playback_completion"
        private const val API_MX_RESULT_POSITION = "position"

        private const val API_VLC_RESULT_POSITION = "extra_position"

        private const val API_VIMU_RESULT_ID = "net.gtvbox.videoplayer.result"
        private const val API_VIMU_RESULT_ERROR = 4
        private const val API_VIMU_RESULT_PLAYBACK_COMPLETED = 1

        private const val API_MPV_RESULT_ID = "is.xyz.mpv.MPVActivity.result"
    }

    // Both facts are fixed for the life of the device, unlike availMem, which
    // would make a feature come and go between launches. totalMem stays a Long
    // on the wire: narrowing it to Int overflows to negative above 2 GB.
    private fun deviceMemory(): Map<String, Any> {
        val activityManager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(info)
        return mapOf(
            "totalMem" to info.totalMem,
            "lowRam" to activityManager.isLowRamDevice,
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun getDisplayHdrTypes(): List<String> {
        return DisplayCapabilities.query(this, "pull")["types"] as? List<String>
            ?: emptyList()
    }

    private fun emitDisplayCapabilities(trigger: String) {
        displayCapsSink?.success(DisplayCapabilities.query(this, trigger))
    }

    private fun unregisterDisplayListener() {
        displayListener?.let { listener ->
            (getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager)
                ?.unregisterDisplayListener(listener)
        }
        displayListener = null
        displayEmit.cancel()
    }

    private val pipReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_PLAY_PAUSE) {
                methodChannel?.invokeMethod("onPiPAction", "playPause")
            }
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF ->
                    methodChannel?.invokeMethod("onScreenLock", true)
                Intent.ACTION_USER_PRESENT ->
                    methodChannel?.invokeMethod("onScreenLock", false)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        discardHeadlessEngine()
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            runCatching { window.colorMode = ActivityInfo.COLOR_MODE_HDR }
        }
        // Android 14 and older keep a fullscreen landscape window clear of the
        // camera cutout, which leaves a black strip beside the video. Android
        // 15 draws under it already.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        deepLinkFrom(intent)?.let { pendingDeepLink = it }
        gameInputManager?.registerInputDeviceListener(gameInputDeviceListener, null)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deepLinkFrom(intent)?.let { watchNextChannel?.invokeMethod("onDeepLink", it) }
    }

    private fun deepLinkFrom(intent: Intent?): String? {
        val itemId = intent?.getStringExtra(WatchNextPublisher.EXTRA_ITEM_ID) ?: return null
        val serverId = intent.getStringExtra(WatchNextPublisher.EXTRA_SERVER_ID)
        val query = if (serverId.isNullOrEmpty()) {
            "id=${Uri.encode(itemId)}"
        } else {
            "id=${Uri.encode(itemId)}&serverId=${Uri.encode(serverId)}"
        }
        return "moonfin://item?$query"
    }

    // audio_service boots the app on an engine of its own whenever something
    // binds the media service with no Activity around, a car head unit or a
    // media button for instance, then hands that engine to the next Activity.
    // By then TV detection, the codec probes and the screensaver timer have
    // all settled for an Activity that wasn't there, so unless it's busy
    // playing the launch starts over on a fresh engine. The media service
    // keeps answering until the new engine configures it.
    private fun discardHeadlessEngine() {
        val cache = FlutterEngineCache.getInstance()
        val id = AudioServicePlugin.getFlutterEngineId()
        val cached = cache.get(id) ?: return
        if (cached === engineHandedToActivity || AudioServiceState.isPlaying()) return
        cache.remove(id)
        cached.destroy()
        // The next engine is built synchronously in super.onCreate, so no car
        // call can land between this and its attach.
        AudioServiceState.markFlutterNotReady()
    }

    // Null travels back to Dart as "ask again" rather than as "not a TV".
    private fun isTvDevice(): Boolean? = isTelevisionOrNull(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        engineHandedToActivity = flutterEngine


        val exitHistory = ProcessExitHistory.get(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PLATFORM_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Reading a crash record can mean parsing its tombstone, so it
                // stays off the main thread.
                "previousExits" -> thread(name = "moonfin-exit-history") {
                    val exits = exitHistory.takeUnreportedExits()
                    handler.post { result.success(exits) }
                }
                "setProcessState" -> {
                    exitHistory.setAppState(call.argument<String>("state") ?: "")
                    result.success(null)
                }
                "isTvDevice" -> {
                    result.success(isTvDevice())
                }
                "displayHdrTypes" -> result.success(getDisplayHdrTypes())
                "displayCapabilities" -> {
                    // The caller stamps why it asked, so the probe log can tell
                    // a launch answer from a resume or retry one.
                    val trigger = call.argument<String>("trigger") ?: "pull"
                    result.success(DisplayCapabilities.query(this, trigger))
                }
                // Server discovery's mDNS browse (Silo's _silo._tcp): Wi-Fi
                // drops multicast packets unless a lock is held.
                "acquireMulticastLock" -> {
                    val lock = discoveryMulticastLock
                        ?: (applicationContext.getSystemService(Context.WIFI_SERVICE)
                            as android.net.wifi.WifiManager)
                            .createMulticastLock("moonfin_server_discovery")
                            .also {
                                it.setReferenceCounted(false)
                                discoveryMulticastLock = it
                            }
                    lock.acquire()
                    result.success(null)
                }
                "releaseMulticastLock" -> {
                    discoveryMulticastLock?.let { if (it.isHeld) it.release() }
                    result.success(null)
                }
                "buildFingerprint" -> result.success(Build.FINGERPRINT)
                "uptimeMillis" -> result.success(SystemClock.uptimeMillis())
                "renderer" -> result.success(MoonfinApplication.rendererSummary)
                "dolbyVisionCodecCapabilities" -> {
                    result.success(MediaCodecCapabilities.queryDolbyVisionCapabilities())
                }
                "mediaCodecCapabilities" -> {
                    val includeSoftwareDecoders =
                        call.argument<Boolean>("includeSoftwareDecoders") ?: false
                    result.success(
                        MediaCodecCapabilities.query(
                            includeSoftwareDecoders = includeSoftwareDecoders,
                        ),
                    )
                }
                "audioCapabilities" -> {
                    result.success(AudioCapabilities.query(this))
                }
                "deviceMemory" -> {
                    result.success(deviceMemory())
                }
                "exitApp" -> {
                    result.success(true)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        finishAndRemoveTask()
                    } else {
                        finishAffinity()
                    }
                }
                else -> result.notImplemented()
            }
        }

        gamepadChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GAMEPAD_CHANNEL,
        )
        gamepadChannel?.setMethodCallHandler { call, result ->
            if (call.method == "setNavigationEnabled") {
                gameInputRouter.setNavigationEnabled(call.argument<Boolean>("enabled") ?: false)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        externalPlayerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EXTERNAL_PLAYER_CHANNEL,
        )
        externalPlayerChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "listPlayers" -> result.success(listExternalPlayerApps())
                "launch" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    launchExternalPlayer(args, result)
                }
                "chooseAndLaunch" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    chooseAndLaunchExternalPlayer(args, result)
                }
                else -> result.notImplemented()
            }
        }

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enableAutoPiP" -> {
                    pipEnabled = call.argument<Boolean>("enabled") ?: false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        setPictureInPictureParams(buildPiPParams(true))
                    }
                    result.success(true)
                }
                "updatePiPActions" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        isInPictureInPictureMode
                    ) {
                        setPictureInPictureParams(
                            buildPiPParams(
                                call.argument<Boolean>("isPlaying") ?: true,
                            ),
                        )
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Re-probe audio capabilities whenever the audio route changes (e.g. an
        // AVR is powered on after launch) and push the fresh result to Dart so
        // the device profile self-heals without an app restart. A link
        // renegotiating mid-playback reports the sink removed and then added
        // again, and answering the removal would tell Dart the box has stereo
        // speakers, so only the trailing edge of a burst is probed.
        audioCapsEventsChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CAPS_EVENTS_CHANNEL,
        )
        audioCapsEventsChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                audioCapsSink = events
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val audioManager =
                        getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                    val callback = object : AudioDeviceCallback() {
                        override fun onAudioDevicesAdded(
                            addedDevices: Array<out AudioDeviceInfo>?,
                        ) = audioEmit.schedule("added")

                        override fun onAudioDevicesRemoved(
                            removedDevices: Array<out AudioDeviceInfo>?,
                        ) = audioEmit.schedule("removed")
                    }
                    audioDeviceCallback = callback
                    audioManager?.registerAudioDeviceCallback(
                        callback,
                        Handler(Looper.getMainLooper()),
                    )
                }
            }

            override fun onCancel(arguments: Any?) {
                unregisterAudioDeviceCallback()
                audioCapsSink = null
            }
        })

        // The display side of the same self-healing story. A box that launched
        // before its TV or AVR woke up has no way to learn the panel does HDR
        // after all, so without this it keeps forcing a transcode on every
        // Dolby Vision item until the app is restarted.
        displayCapsEventsChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DISPLAY_CAPS_EVENTS_CHANNEL,
        )
        displayCapsEventsChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                displayCapsSink = events
                val displayManager =
                    getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
                // No display id filter. A sink waking up can arrive as a remove
                // and re-add under a brand new id, which is exactly the event
                // worth reacting to, so anything the system reports is probed.
                // onDisplayChanged also fires for rotation, refresh rate and
                // brightness, so a waking chain arrives as a burst and only
                // the trailing edge of it describes settled hardware.
                val listener = object : DisplayManager.DisplayListener {
                    override fun onDisplayAdded(displayId: Int) =
                        displayEmit.schedule("added")

                    override fun onDisplayRemoved(displayId: Int) =
                        displayEmit.schedule("removed")

                    override fun onDisplayChanged(displayId: Int) =
                        displayEmit.schedule("changed")
                }
                displayListener = listener
                displayManager?.registerDisplayListener(
                    listener,
                    Handler(Looper.getMainLooper()),
                )
            }

            override fun onCancel(arguments: Any?) {
                unregisterDisplayListener()
                displayCapsSink = null
            }
        })

        val publisher = watchNextPublisher ?: WatchNextPublisher(applicationContext)
            .also { watchNextPublisher = it }
        val channelPublisher = previewChannelPublisher
            ?: PreviewChannelPublisher(applicationContext).also { previewChannelPublisher = it }
        watchNextChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WATCH_NEXT_CHANNEL,
        )
        watchNextChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "publish" -> {
                    @Suppress("UNCHECKED_CAST")
                    val items = call.argument<List<Map<String, Any?>>>("items") ?: emptyList()
                    publisher.publish(items)
                    result.success(null)
                }
                "clear" -> {
                    publisher.clear()
                    result.success(null)
                }
                "publishChannels" -> {
                    @Suppress("UNCHECKED_CAST")
                    val channels = call.argument<List<Map<String, Any?>>>("channels")
                        ?: emptyList()
                    channelPublisher.publishChannels(channels)
                    result.success(null)
                }
                "clearChannels" -> {
                    channelPublisher.clearChannels()
                    result.success(null)
                }
                "getInitialDeepLink" -> {
                    result.success(pendingDeepLink)
                    pendingDeepLink = null
                }
                "schedulePeriodic" -> {
                    WatchNextWorker.schedule(applicationContext)
                    result.success(null)
                }
                "cancelPeriodic" -> {
                    WatchNextWorker.cancel(applicationContext)
                    result.success(null)
                }
                "runRefreshNow" -> {
                    WatchNextWorker.runNow(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }



        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                pipReceiver,
                IntentFilter(ACTION_PLAY_PAUSE),
                Context.RECEIVER_EXPORTED,
            )
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(pipReceiver, IntentFilter(ACTION_PLAY_PAUSE))
        }

        val screenFilter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, screenFilter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(screenReceiver, screenFilter)
        }
    }

    // D-pad events remain native; only analog stick navigation crosses to Dart.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (gameInputRouter.onKeyEvent(event)) return true
        if (gameInputRouter.blocksNavigation(event)) return true
        return super.dispatchKeyEvent(ModifierScanCodePolicy.forFlutter(event))
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (gameInputRouter.onMotionEvent(event)) return true
        return super.dispatchGenericMotionEvent(event)
    }

    // The axis is "h" or "v" so Dart can tell which one a "none" recentre came
    // from. Without it, releasing a diagonal is ambiguous.
    private fun sendGamepadNavigate(axis: String, direction: String) {
        runOnUiThread {
            gamepadChannel?.invokeMethod(
                "onNavigate",
                mapOf("axis" to axis, "direction" to direction),
            )
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // A dream or a call taking the foreground never reaches here, which
        // is what separates walking away from the screensaver coming on. PiP
        // keeps the player on screen, so that is not walking away either.
        if (!requestEnterPiPIfEligible()) {
            methodChannel?.invokeMethod("onUserLeftApp", null)
        }
    }

    override fun onPictureInPictureRequested(): Boolean {
        return requestEnterPiPIfEligible()
    }

    private fun requestEnterPiPIfEligible(): Boolean {
        val hasPiPFeature = packageManager.hasSystemFeature(
            android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE,
        )
        if (!pipEnabled) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (!hasPiPFeature) return false
        if (isInPictureInPictureMode) return true
        if (isFinishing || isDestroyed) return false
        val result = enterPictureInPictureMode(buildPiPParams(true))
        return result
    }

    override fun onPictureInPictureModeChanged(
        isInPiP: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPiP, newConfig)
        dispatchPiPMethod("onPiPChanged", isInPiP)

        dismissRunnable?.let {
            handler.removeCallbacks(it)
            dismissRunnable = null
        }

        if (!isInPiP) {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!power.isInteractive) return

            dismissRunnable = Runnable {
                dispatchPiPMethod("onPiPAction", "dismissed")
                dismissRunnable = null
            }
            handler.postDelayed(dismissRunnable!!, DISMISS_DELAY_MS)
        }
    }

    override fun onResume() {
        super.onResume()
        if (isInPictureInPictureMode) return
        dismissRunnable?.let {
            handler.removeCallbacks(it)
            dismissRunnable = null
        }
    }

    private fun dispatchPiPMethod(method: String, argument: Any) {
        val channel = methodChannel
        if (channel != null) {
            channel.invokeMethod(method, argument)
            return
        }
        handler.post {
            methodChannel?.invokeMethod(method, argument)
        }
    }

    private fun buildPiPParams(isPlaying: Boolean): PictureInPictureParams {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            throw IllegalStateException("PiP requires API 26+")
        }

        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))

        val icon = if (isPlaying) {
            Icon.createWithResource(this, android.R.drawable.ic_media_pause)
        } else {
            Icon.createWithResource(this, android.R.drawable.ic_media_play)
        }
        val label = if (isPlaying) "Pause" else "Play"
        val intent = PendingIntent.getBroadcast(
            this,
            0,
            Intent(ACTION_PLAY_PAUSE).apply { setPackage(packageName) },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val action = RemoteAction(icon, label, label, intent)
        builder.setActions(listOf(action))

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(pipEnabled)
            builder.setSeamlessResizeEnabled(true)
        }

        return builder.build()
    }

    override fun onDestroy() {
        discoveryMulticastLock?.let { if (it.isHeld) it.release() }
        val shouldTerminateProcess = isFinishing && !isChangingConfigurations
        // Process-wide InputManager registration: without this the listener
        // keeps this Activity alive across every recreation.
        gameInputManager?.unregisterInputDeviceListener(gameInputDeviceListener)
        dismissRunnable?.let { handler.removeCallbacks(it) }
        try { unregisterReceiver(pipReceiver) } catch (_: Exception) {}
        try { unregisterReceiver(screenReceiver) } catch (_: Exception) {}
        unregisterAudioDeviceCallback()
        audioCapsEventsChannel?.setStreamHandler(null)
        // DisplayManagerGlobal holds registrations process wide, so without
        // this the listener keeps this Activity alive across every recreation.
        unregisterDisplayListener()
        displayCapsEventsChannel?.setStreamHandler(null)
        externalPlayerChannel?.setMethodCallHandler(null)
        gamepadChannel?.setMethodCallHandler(null)
        watchNextChannel?.setMethodCallHandler(null)
        externalPlayerPendingResult?.error(
            "ACTIVITY_DESTROYED",
            "Main activity was destroyed before external playback returned.",
            null,
        )
        externalPlayerPendingResult = null
        super.onDestroy()

        if (shouldTerminateProcess) {
            // Recents-close can destroy activity while native callbacks from the old
            // engine lifetime are still in flight. Terminating this process prevents
            // a new engine from attaching to stale native callback state.
            Process.killProcess(Process.myPid())
        }
    }

    private fun listExternalPlayerApps(): List<Map<String, Any>> {
        val queryIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(EXTERNAL_PLAYER_SAMPLE_URL), "video/*")
        }
        val activities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                queryIntent,
                android.content.pm.PackageManager.ResolveInfoFlags.of(
                    android.content.pm.PackageManager.MATCH_DEFAULT_ONLY.toLong(),
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(
                queryIntent,
                android.content.pm.PackageManager.MATCH_DEFAULT_ONLY,
            )
        }

        return activities
            .mapNotNull { info ->
                val packageName = info.activityInfo?.packageName ?: return@mapNotNull null
                if (packageName == this.packageName) {
                    return@mapNotNull null
                }
                if (info.priority < 0) {
                    return@mapNotNull null
                }
                val categoryMatch = info.match and IntentFilter.MATCH_CATEGORY_MASK
                if (categoryMatch < IntentFilter.MATCH_CATEGORY_TYPE) {
                    return@mapNotNull null
                }
                if (!hasExplicitVideoMimeType(info.filter)) {
                    return@mapNotNull null
                }
                var activityName = info.activityInfo?.name ?: return@mapNotNull null
                if (activityName.startsWith(".")) {
                    activityName = "$packageName$activityName"
                }
                val component = "$packageName/$activityName"
                val label = info.loadLabel(packageManager)?.toString()?.takeIf { it.isNotBlank() }
                    ?: activityName
                val entry = mutableMapOf<String, Any>(
                    "component" to component,
                    "packageName" to packageName,
                    "activityName" to activityName,
                    "label" to label,
                )
                iconToPngBytes(info.loadIcon(packageManager))?.let { iconBytes ->
                    entry["iconPngBytes"] = iconBytes
                }
                entry
            }
            .distinctBy { it["component"] }
                .sortedBy { (it["label"] as? String)?.lowercase() ?: "" }
    }

    private fun hasExplicitVideoMimeType(filter: IntentFilter?): Boolean {
        if (filter == null) {
            return true
        }

        val typeCount = filter.countDataTypes()
        if (typeCount <= 0) {
            return true
        }

        var hasVideoType = false
        for (index in 0 until typeCount) {
            val mimeType = filter.getDataType(index)?.lowercase() ?: continue
            if (mimeType == "*/*") {
                continue
            }
            if (mimeType == "video/*" || mimeType.startsWith("video/")) {
                hasVideoType = true
                break
            }
        }

        return hasVideoType
    }

    private fun launchExternalPlayer(args: Map<*, *>, result: MethodChannel.Result) {
        val launchIntent = createExternalPlayerIntent(args, requireComponent = true)
        if (launchIntent == null) {
            result.error("BAD_ARGS", "Missing or invalid external player launch arguments.", null)
            return
        }

        if (launchIntent.resolveActivity(packageManager) == null) {
            result.error("PLAYER_NOT_FOUND", "Selected external player is unavailable.", null)
            return
        }

        startExternalPlayer(launchIntent, args, result)
    }

    private fun chooseAndLaunchExternalPlayer(args: Map<*, *>, result: MethodChannel.Result) {
        val baseIntent = createExternalPlayerIntent(args, requireComponent = false)
        if (baseIntent == null) {
            result.error("BAD_ARGS", "Missing or invalid external player launch arguments.", null)
            return
        }

        val hasTarget = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                baseIntent,
                android.content.pm.PackageManager.ResolveInfoFlags.of(
                    android.content.pm.PackageManager.MATCH_DEFAULT_ONLY.toLong(),
                ),
            ).isNotEmpty()
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(
                baseIntent,
                android.content.pm.PackageManager.MATCH_DEFAULT_ONLY,
            ).isNotEmpty()
        }
        if (!hasTarget) {
            result.error("PLAYER_NOT_FOUND", "No compatible external player was found.", null)
            return
        }

        val chooserIntent = Intent.createChooser(baseIntent, EXTERNAL_PLAYER_CHOOSER_TITLE)
        startExternalPlayer(chooserIntent, args, result)
    }

    // A player that relaunches itself, as VLC does for a live stream, answers
    // a waiting proxy at once and brings Moonfin back over it. A detached
    // launch runs in its own task instead and the app waits for the viewer
    // to come back.
    private fun startExternalPlayer(
        intent: Intent,
        args: Map<*, *>,
        result: MethodChannel.Result,
    ) {
        if (args["detached"] != true) {
            startExternalPlayerProxy(intent, result)
            return
        }
        try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            result.success(
                mapOf(
                    "completed" to false,
                    "hasError" to false,
                    "resultCode" to Activity.RESULT_OK,
                ),
            )
        } catch (error: ActivityNotFoundException) {
            result.error("PLAYER_NOT_FOUND", error.message, null)
        } catch (error: Exception) {
            result.error("LAUNCH_FAILED", error.message, null)
        }
    }

    private fun startExternalPlayerProxy(
        launchIntent: Intent,
        result: MethodChannel.Result,
    ) {
        if (externalPlayerPendingResult != null) {
            result.error(
                "IN_PROGRESS",
                "An external player launch is already in progress.",
                null,
            )
            return
        }

        externalPlayerPendingResult = result
        try {
            val proxyIntent = Intent(this, ExternalPlayerProxyActivity::class.java).apply {
                putExtra(EXTRA_EXTERNAL_PLAYER_LAUNCH_INTENT, launchIntent)
            }
            startActivityForResult(proxyIntent, EXTERNAL_PLAYER_PROXY_REQUEST_CODE)
        } catch (error: ActivityNotFoundException) {
            externalPlayerPendingResult = null
            result.error("PLAYER_NOT_FOUND", error.message, null)
        } catch (error: Exception) {
            externalPlayerPendingResult = null
            result.error("LAUNCH_FAILED", error.message, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == EXTERNAL_PLAYER_PROXY_REQUEST_CODE) {
            val pendingResult = externalPlayerPendingResult
            externalPlayerPendingResult = null
            pendingResult?.success(buildExternalPlayerResultPayload(data, resultCode))
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun createExternalPlayerIntent(
        args: Map<*, *>,
        requireComponent: Boolean,
    ): Intent? {
        val url = (args["url"] as? String)?.trim().orEmpty()
        if (url.isEmpty()) return null

        val componentRaw = (args["component"] as? String)?.trim().orEmpty()
        val component = splitComponent(componentRaw)
        if (requireComponent && component == null) {
            return null
        }

        val mimeType = (args["mimeType"] as? String)?.trim().takeUnless { it.isNullOrEmpty() }
            ?: "video/*"
        val title = (args["title"] as? String)?.trim().orEmpty()
        val fileName = (args["filename"] as? String)?.trim().orEmpty()
        val positionMs = (anyToLong(args["positionMs"]) ?: 0L).coerceAtLeast(0L)
        val positionInt = positionMs.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(url), mimeType)
            if (component != null) {
                setClassName(component.first, component.second)
            }
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)

            putExtra("position", positionInt)
            putExtra("return_result", true)
            putExtra("secure_uri", true)
            if (title.isNotEmpty()) {
                putExtra("title", title)
            }
            if (fileName.isNotEmpty()) {
                putExtra("filename", fileName)
            }

            putExtra("from_start", positionInt <= 0)

            putExtra("forcename", title)
            putExtra("startfrom", positionInt)
            putExtra("forceresume", false)
        }

        val headers = args["headers"] as? Map<*, *>
        if (headers != null) {
            val headerBundle = Bundle()
            for ((key, value) in headers.entries) {
                val headerKey = key as? String ?: continue
                val headerValue = value as? String ?: continue
                if (headerKey.isBlank() || headerValue.isBlank()) continue
                headerBundle.putString(headerKey, headerValue)
            }
            if (headerBundle.size() > 0) {
                intent.putExtra("headers", headerBundle)
            }
        }

        val subtitleEntries = args["subtitles"] as? List<*> ?: emptyList<Any>()
        if (subtitleEntries.isNotEmpty()) {
            val subtitleUris = ArrayList<Uri>()
            val subtitleNames = ArrayList<String>()
            val subtitleFiles = ArrayList<String>()

            for (entry in subtitleEntries) {
                val map = entry as? Map<*, *> ?: continue
                val subtitleUrl = (map["url"] as? String)?.trim().orEmpty()
                if (subtitleUrl.isEmpty()) continue

                val subtitleUri = runCatching { Uri.parse(subtitleUrl) }.getOrNull() ?: continue
                subtitleUris.add(subtitleUri)
                subtitleNames.add((map["name"] as? String)?.trim().orEmpty())
                subtitleFiles.add((map["language"] as? String)?.trim().orEmpty())
            }

            if (subtitleUris.isNotEmpty()) {
                intent.putExtra("subs", subtitleUris.toTypedArray())
                intent.putExtra("subs.name", subtitleNames.toTypedArray())
                intent.putExtra("subs.filename", subtitleFiles.toTypedArray())
                intent.putExtra("subtitles_location", subtitleUris.first().toString())
            }
        }

        return intent
    }

    private fun splitComponent(raw: String): Pair<String, String>? {
        if (raw.isBlank()) return null
        val slash = raw.indexOf('/')
        if (slash <= 0 || slash >= raw.lastIndex) return null

        val packageName = raw.substring(0, slash).trim()
        var activityName = raw.substring(slash + 1).trim()
        if (packageName.isEmpty() || activityName.isEmpty()) return null
        if (activityName.startsWith(".")) {
            activityName = "$packageName$activityName"
        }
        return packageName to activityName
    }

    private fun iconToPngBytes(drawable: Drawable?): ByteArray? {
        if (drawable == null) return null
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
            val generated = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(generated)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            generated
        }

        val stream = ByteArrayOutputStream()
        return try {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (_: Exception) {
            null
        } finally {
            runCatching { stream.close() }
        }
    }

    private fun buildExternalPlayerResultPayload(
        data: Intent?,
        resultCode: Int,
    ): Map<String, Any> {
        val action = data?.action ?: ""
        val forwardedErrorCode = data?.getStringExtra(EXTRA_EXTERNAL_PLAYER_ERROR_CODE)
        val forwardedErrorMessage = data?.getStringExtra(EXTRA_EXTERNAL_PLAYER_ERROR_MESSAGE)

        if (!forwardedErrorCode.isNullOrBlank()) {
            val payload = mutableMapOf<String, Any>(
                "completed" to false,
                "hasError" to true,
                "resultCode" to resultCode,
                "errorCode" to forwardedErrorCode,
                "errorMessage" to (forwardedErrorMessage ?: "External player launch failed."),
            )
            if (action.isNotEmpty()) {
                payload["playerAction"] = action
            }
            return payload
        }

        val endPositionMs = extractExternalPlayerPositionMs(data)

        val playbackCompleted = when (action) {
            API_MX_RESULT_ID ->
                data?.extras?.getString(API_MX_RESULT_END_BY) == API_MX_RESULT_END_BY_PLAYBACK_COMPLETION
            API_MPV_RESULT_ID -> endPositionMs == null
            API_VIMU_RESULT_ID -> resultCode == API_VIMU_RESULT_PLAYBACK_COMPLETED
            else -> false
        }

        val hasError = when (action) {
            API_VIMU_RESULT_ID -> resultCode == API_VIMU_RESULT_ERROR
            else -> resultCode != Activity.RESULT_OK && !playbackCompleted
        }

        val payload = mutableMapOf<String, Any>(
            "completed" to playbackCompleted,
            "hasError" to hasError,
            "resultCode" to resultCode,
        )

        if (action.isNotEmpty()) {
            payload["playerAction"] = action
        }

        if (endPositionMs != null) {
            payload["endPositionMs"] = endPositionMs
        }

        if (hasError) {
            payload["errorCode"] = "EXTERNAL_PLAYER_ERROR"
            payload["errorMessage"] = "External player reported an error or was canceled."
        }

        return payload
    }

    private fun extractExternalPlayerPositionMs(data: Intent?): Long? {
        val extras = data?.extras ?: return null
        val keys = listOf(
            API_MX_RESULT_POSITION,
            API_VLC_RESULT_POSITION,
        )
        for (key in keys) {
            val raw = extras.get(key) ?: continue
            val value = anyToLong(raw)
            if (value != null && value >= 0L) {
                return value
            }
        }
        return null
    }

    private fun anyToLong(value: Any?): Long? {
        return when (value) {
            is Int -> value.toLong()
            is Long -> value
            is Short -> value.toLong()
            is Byte -> value.toLong()
            is Float -> value.toLong()
            is Double -> value.toLong()
            is String -> value.toLongOrNull()
            else -> null
        }
    }



}
