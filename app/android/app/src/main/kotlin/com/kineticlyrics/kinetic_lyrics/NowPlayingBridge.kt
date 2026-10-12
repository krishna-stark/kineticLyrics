package com.kineticlyrics.kinetic_lyrics

import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import io.flutter.plugin.common.EventChannel

object NowPlayingBridge : EventChannel.StreamHandler {
    private lateinit var appContext: Context
    private lateinit var sessionManager: MediaSessionManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var sessionListenerRegistered = false
    private var selectedController: MediaController? = null
    private val callbacks = mutableMapOf<MediaController, MediaController.Callback>()

    private val activeSessionsListener =
        MediaSessionManager.OnActiveSessionsChangedListener { refresh() }

    fun initialize(context: Context) {
        appContext = context.applicationContext
        sessionManager = appContext.getSystemService(MediaSessionManager::class.java)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        refresh()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        stopWatching()
    }

    fun refresh() {
        if (!::appContext.isInitialized) return
        mainHandler.post { refreshOnMainThread() }
    }

    private fun refreshOnMainThread() {
        if (!hasNotificationAccess()) {
            stopWatching()
            emit(
                mapOf(
                    "access" to "denied",
                    "message" to "Enable Notification Access to read active media sessions.",
                    "track" to null,
                ),
            )
            return
        }

        try {
            if (!sessionListenerRegistered) {
                sessionManager.addOnActiveSessionsChangedListener(
                    activeSessionsListener,
                    listenerComponent,
                    mainHandler,
                )
                sessionListenerRegistered = true
            }

            val controllers = sessionManager.getActiveSessions(listenerComponent)
                .filter { it.packageName != appContext.packageName }
            watch(controllers)
            val selected = controllers.filter { title(it.metadata).isNotBlank() }.maxByOrNull(::score)
            selectedController = selected
            emit(
                mapOf(
                    "access" to "granted",
                    "message" to null,
                    "track" to selected?.let(::trackMap),
                ),
            )
        } catch (error: SecurityException) {
            stopWatching()
            emit(
                mapOf(
                    "access" to "denied",
                    "message" to (error.message ?: "Media-session access was denied."),
                    "track" to null,
                ),
            )
        } catch (error: Exception) {
            emit(
                mapOf(
                    "access" to "error",
                    "message" to (error.message ?: "Could not inspect media sessions."),
                    "track" to null,
                ),
            )
        }
    }

    fun transport(action: String, source: String?, expectedTitle: String?, positionMs: Long?): Boolean {
        val controller = selectedController ?: return false
        if (controller.packageName != source || title(controller.metadata) != expectedTitle) return false
        val actions = controller.playbackState?.actions ?: return false
        val required = when (action) {
            "play" -> PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PLAY_PAUSE
            "pause" -> PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE
            "next" -> PlaybackState.ACTION_SKIP_TO_NEXT
            "previous" -> PlaybackState.ACTION_SKIP_TO_PREVIOUS
            "seek" -> PlaybackState.ACTION_SEEK_TO
            else -> return false
        }
        if ((actions and required) == 0L) return false
        return try {
            val controls = controller.transportControls
            when (action) {
                "play" -> controls.play()
                "pause" -> controls.pause()
                "next" -> controls.skipToNext()
                "previous" -> controls.skipToPrevious()
                "seek" -> {
                    val duration = controller.metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
                    if (duration <= 0 || positionMs == null) return false
                    controls.seekTo(positionMs.coerceIn(0L, duration))
                }
            }
            refresh()
            true
        } catch (_: Exception) { false }
    }

    private fun watch(controllers: List<MediaController>) {
        val stale = callbacks.keys - controllers.toSet()
        stale.forEach { controller ->
            callbacks.remove(controller)?.let(controller::unregisterCallback)
        }
        controllers.forEach { controller ->
            if (callbacks.containsKey(controller)) return@forEach
            val callback = object : MediaController.Callback() {
                override fun onMetadataChanged(metadata: MediaMetadata?) = refresh()
                override fun onPlaybackStateChanged(state: PlaybackState?) = refresh()
                override fun onSessionDestroyed() = refresh()
            }
            callbacks[controller] = callback
            controller.registerCallback(callback, mainHandler)
        }
    }

    private fun stopWatching() {
        selectedController = null
        callbacks.forEach { (controller, callback) ->
            controller.unregisterCallback(callback)
        }
        callbacks.clear()
        if (sessionListenerRegistered) {
            sessionManager.removeOnActiveSessionsChangedListener(activeSessionsListener)
            sessionListenerRegistered = false
        }
    }

    private fun score(controller: MediaController): Int {
        val stateScore = when (controller.playbackState?.state) {
            PlaybackState.STATE_PLAYING -> 100
            PlaybackState.STATE_BUFFERING,
            PlaybackState.STATE_CONNECTING,
            PlaybackState.STATE_FAST_FORWARDING,
            PlaybackState.STATE_REWINDING,
            PlaybackState.STATE_SKIPPING_TO_NEXT,
            PlaybackState.STATE_SKIPPING_TO_PREVIOUS,
            PlaybackState.STATE_SKIPPING_TO_QUEUE_ITEM,
            -> 80
            PlaybackState.STATE_PAUSED -> 50
            PlaybackState.STATE_STOPPED -> 20
            else -> 0
        }
        return stateScore + if (title(controller.metadata).isNotBlank()) 10 else 0
    }

    private fun trackMap(controller: MediaController): Map<String, Any?> {
        val metadata = controller.metadata
        val playback = controller.playbackState
        val duration = metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION)
            ?.takeIf { it > 0 }
        val position = currentPosition(playback, duration)
        return mapOf(
            "sourcePackage" to controller.packageName,
            "sourceName" to sourceName(controller.packageName),
            "title" to title(metadata).ifBlank { "Unknown track" },
            "artist" to artist(metadata),
            "album" to metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM),
            "durationMs" to duration,
            "positionMs" to position,
            "playbackActions" to (playback?.actions ?: 0L),
            "playbackSpeed" to (playback?.playbackSpeed?.toDouble() ?: 0.0),
            "state" to stateName(playback?.state),
        )
    }

    private fun currentPosition(state: PlaybackState?, duration: Long?): Long {
        if (state == null || state.position == PlaybackState.PLAYBACK_POSITION_UNKNOWN) return 0
        var position = state.position.coerceAtLeast(0)
        if (state.state == PlaybackState.STATE_PLAYING && state.lastPositionUpdateTime > 0) {
            val elapsed = SystemClock.elapsedRealtime() - state.lastPositionUpdateTime
            position += (elapsed * state.playbackSpeed).toLong()
        }
        return if (duration == null) position.coerceAtLeast(0)
        else position.coerceIn(0, duration)
    }

    private fun title(metadata: MediaMetadata?): String =
        metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
            ?: ""

    private fun artist(metadata: MediaMetadata?): String =
        metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE)
            ?: ""

    private fun sourceName(packageName: String): String = try {
        val info = appContext.packageManager.getApplicationInfo(packageName, 0)
        appContext.packageManager.getApplicationLabel(info).toString()
    } catch (_: Exception) {
        packageName
    }

    private fun stateName(state: Int?): String = when (state) {
        PlaybackState.STATE_STOPPED -> "stopped"
        PlaybackState.STATE_PAUSED -> "paused"
        PlaybackState.STATE_PLAYING -> "playing"
        PlaybackState.STATE_BUFFERING -> "buffering"
        PlaybackState.STATE_CONNECTING -> "connecting"
        PlaybackState.STATE_FAST_FORWARDING,
        PlaybackState.STATE_REWINDING,
        PlaybackState.STATE_SKIPPING_TO_NEXT,
        PlaybackState.STATE_SKIPPING_TO_PREVIOUS,
        PlaybackState.STATE_SKIPPING_TO_QUEUE_ITEM,
        -> "seeking"
        PlaybackState.STATE_ERROR -> "error"
        else -> "none"
    }

    private fun hasNotificationAccess(): Boolean {
        val enabled = Settings.Secure.getString(
            appContext.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabled.split(':')
            .mapNotNull(ComponentName::unflattenFromString)
            .any { it == listenerComponent }
    }

    private val listenerComponent: ComponentName
        get() = ComponentName(appContext, MediaNotificationListener::class.java)

    private fun emit(value: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(value) }
    }
}
