package info.dvkr.screenstream.common.module

import android.annotation.SuppressLint
import android.app.Service
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.IBinder
import androidx.core.app.ServiceCompat
import com.elvishew.xlog.XLog
import info.dvkr.screenstream.common.getLog
import info.dvkr.screenstream.common.notification.NotificationHelper
import org.koin.android.ext.android.inject
import java.util.UUID

public abstract class StreamingModuleService : Service() {

    protected abstract val notificationIdForeground: Int
    protected abstract val notificationIdError: Int

    protected val streamingModuleManager: StreamingModuleManager by inject(mode = LazyThreadSafetyMode.NONE)
    protected val notificationHelper: NotificationHelper by inject(mode = LazyThreadSafetyMode.NONE)

    protected val processedIntents: MutableSet<String> = mutableSetOf()

    private val wifiLock: WifiManager.WifiLock? by lazy(LazyThreadSafetyMode.NONE) {
        runCatching {
            @Suppress("DEPRECATION")
            applicationContext.getSystemService(WifiManager::class.java)
                ?.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "ScreenStream::StreamingWifiLock")
                ?.apply { setReferenceCounted(false) }
        }.onFailure { XLog.w(getLog("wifiLock", "Unable to create Wi-Fi lock"), it) }
            .getOrNull()
    }

    @Suppress("RedundantVisibilityModifier")
    protected companion object {
        public const val INTENT_ID: String = "info.dvkr.screenstream.intent.ID"

        public fun Intent.addIntentId(): Intent = putExtra(INTENT_ID, UUID.randomUUID().toString())
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        XLog.d(getLog("onCreate"))
    }

    override fun onDestroy() {
        stopForeground()
        hideErrorNotification()
        super.onDestroy()
    }

    protected fun isDuplicateIntent(intent: Intent): Boolean {
        val id = intent.getStringExtra(INTENT_ID)
        return when {
            id == null -> {
                XLog.w(getLog("isDuplicateIntent", "No intent ID provided"))
                false
            }
            processedIntents.contains(id) -> {
                XLog.w(getLog("isDuplicateIntent", "Duplicate intent ID: $id"))
                true
            }
            else -> {
                processedIntents.add(id)
                false
            }
        }
    }

    @SuppressLint("InlinedApi")
    protected fun startForeground(stopIntent: Intent, serviceType: Int) {
        val notification = notificationHelper.createForegroundNotification(this, stopIntent)
        ServiceCompat.startForeground(this, notificationIdForeground, notification, serviceType)
        acquireWifiLock()
    }

    public fun stopForeground() {
        XLog.d(getLog("stopForeground"))

        releaseWifiLock()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
    }

    @SuppressLint("WakelockTimeout")
    private fun acquireWifiLock() {
        runCatching {
            wifiLock?.let { lock -> if (!lock.isHeld) lock.acquire() }
        }.onFailure { XLog.w(getLog("acquireWifiLock", "Unable to acquire Wi-Fi lock"), it) }
    }

    private fun releaseWifiLock() {
        runCatching {
            wifiLock?.let { lock -> if (lock.isHeld) lock.release() }
        }.onFailure { XLog.w(getLog("releaseWifiLock", "Unable to release Wi-Fi lock"), it) }
    }

    protected fun showErrorNotification(message: String, recoverIntent: Intent?) {
        hideErrorNotification()

        if (notificationHelper.notificationPermissionGranted(this).not()) {
            XLog.e(getLog("showErrorNotification", "No permission granted. Ignoring."))
            return
        }

        if (notificationHelper.errorNotificationsEnabled().not()) {
            XLog.e(getLog("showErrorNotification", "Notifications disabled. Ignoring."))
            return
        }

        val notification = notificationHelper.getErrorNotification(this, message, recoverIntent)
        notificationHelper.showNotification(notificationIdError, notification)
    }

    public fun hideErrorNotification() {
        XLog.d(getLog("hideErrorNotification"))

        notificationHelper.cancelNotification(notificationIdError)
    }
}
