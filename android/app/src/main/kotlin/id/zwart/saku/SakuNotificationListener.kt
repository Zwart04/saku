package id.zwart.saku

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Pembaca notifikasi. Event diteruskan ke Flutter lewat EventChannel "saku/notifs".
 * Filter native: kalau whitelist (dipilih user di onboarding) tidak kosong,
 * hanya notifikasi dari app di whitelist yang diteruskan.
 */
class SakuNotificationListener : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d("SakuNotif", "listener connected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val builder = StringBuilder()
        for (key in TEXT_KEYS) {
            val v = extras.getCharSequence(key)?.toString()
            if (!v.isNullOrBlank()) {
                builder.append(v).append(' ')
            }
        }
        val text = builder.toString().trim()
        if (title.isBlank() && text.isBlank()) return

        val prefs = getSharedPreferences("saku_native", Context.MODE_PRIVATE)
        val whitelist = prefs.getStringSet("notif_whitelist", emptySet()) ?: emptySet()
        if (whitelist.isNotEmpty() && sbn.packageName !in whitelist) return

        val event = mapOf(
            "package" to sbn.packageName,
            "title" to title,
            "text" to text,
            "timestamp" to sbn.postTime
        )
        SakuNotifBridge.emit(event)
    }

    companion object {
        private val TEXT_KEYS = arrayOf(
            Notification.EXTRA_TEXT,
            Notification.EXTRA_BIG_TEXT,
            Notification.EXTRA_SUB_TEXT
        )
    }
}

object SakuNotifBridge {
    @Volatile
    var sink: EventChannel.EventSink? = null

    private val buffer = ArrayDeque<Map<String, Any?>>()
    private const val MAX_BUFFER = 40

    fun emit(event: Map<String, Any?>) {
        val s = sink
        if (s != null) {
            try {
                s.success(event)
            } catch (t: Throwable) {
                bufferEvent(event)
            }
        } else {
            bufferEvent(event)
        }
    }

    @Synchronized
    private fun bufferEvent(event: Map<String, Any?>) {
        if (buffer.size >= MAX_BUFFER) buffer.removeFirst()
        buffer.addLast(event)
    }

    @Synchronized
    fun flushBuffered() {
        val s = sink ?: return
        while (buffer.isNotEmpty()) {
            val e = buffer.removeFirst()
            try {
                s.success(e)
            } catch (t: Throwable) {
                return
            }
        }
    }
}
