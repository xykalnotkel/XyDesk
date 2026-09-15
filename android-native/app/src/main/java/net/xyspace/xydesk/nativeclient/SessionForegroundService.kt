package net.xyspace.xydesk.nativeclient

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/** Menjaga sesi tetap terlihat dan hidup saat UI masuk background/PiP. */
class SessionForegroundService : Service() {
    override fun onCreate() {
        super.onCreate()
        NativeSessionRuntime.attach(applicationContext)
        createChannel()
        startForeground(NOTIFICATION_ID, notification("Sesi XyDesk aktif"))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            NativeSessionRuntime.stop()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val message = intent?.getStringExtra(EXTRA_MESSAGE).orEmpty()
        if (message.isNotBlank()) {
            getSystemService(NotificationManager::class.java)
                ?.notify(NOTIFICATION_ID, notification(message))
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun notification(message: String): Notification = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(android.R.drawable.stat_sys_headset)
        .setContentTitle("XyDesk")
        .setContentText(message)
        .setOngoing(true)
        .setCategory(NotificationCompat.CATEGORY_SERVICE)
        .build()

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Sesi XyDesk",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
    }

    companion object {
        const val ACTION_START = "net.xyspace.xydesk.action.SESSION_START"
        const val ACTION_STOP = "net.xyspace.xydesk.action.SESSION_STOP"
        const val EXTRA_MESSAGE = "message"
        private const val CHANNEL_ID = "xydesk-session"
        private const val NOTIFICATION_ID = 8701
    }
}
