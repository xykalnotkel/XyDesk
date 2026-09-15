package net.xyspace.xydesk.nativeclient

import android.app.Notification
import android.app.NotificationChannel
import android.app.PendingIntent
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

    private fun notification(message: String): Notification {
        val openApp = PendingIntent.getActivity(
            this,
            REQUEST_OPEN_APP,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopSession = PendingIntent.getService(
            this,
            REQUEST_STOP_SESSION,
            Intent(this, SessionForegroundService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_headset)
            .setContentTitle("XyDesk")
            .setContentText(message)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(android.R.drawable.ic_media_pause, "Akhiri sesi", stopSession)
            .build()
    }

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
        private const val REQUEST_OPEN_APP = 8702
        private const val REQUEST_STOP_SESSION = 8703
    }
}
