package net.xyspace.xydesk.nativeclient

import android.app.Application
import com.onesignal.OneSignal

/** Inisialisasi SDK native yang harus hidup sebelum activity mana pun dibuat. */
class XyDeskApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        NativePushNotifications.initialize(this)
    }
}

/**
 * Adapter kecil agar UI Compose tidak mengetahui detail SDK OneSignal.
 * App ID boleh berada di APK; REST/API key tidak pernah boleh berada di sini.
 */
object NativePushNotifications {
    private var initialized = false

    @Synchronized
    fun initialize(application: Application) {
        if (initialized) return
        val appId = BuildConfig.ONESIGNAL_APP_ID.trim()
        if (appId.isBlank()) return
        OneSignal.initWithContext(application, appId)
        initialized = true
    }

    fun permissionGranted(): Boolean =
        initialized && OneSignal.Notifications.permission

    fun setOptIn(enabled: Boolean) {
        if (!initialized) return
        if (enabled) OneSignal.User.pushSubscription.optIn()
        else OneSignal.User.pushSubscription.optOut()
    }

    suspend fun requestPermission(): Boolean {
        if (!initialized) return false
        return OneSignal.Notifications.requestPermission(false)
    }
}
