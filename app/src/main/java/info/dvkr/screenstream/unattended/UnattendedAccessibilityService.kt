package info.dvkr.screenstream.unattended

import android.accessibilityservice.AccessibilityService
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.UserManager
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.content.ContextCompat
import com.elvishew.xlog.XLog

public class UnattendedAccessibilityService : AccessibilityService() {

    public companion object {
        public const val ACTION_TRIGGER: String = "info.dvkr.screenstream.action.UNATTENDED_TRIGGER"
        private const val SYSTEM_UI_PACKAGE = "com.android.systemui"
        private const val POSITIVE_BUTTON_ID = "android:id/button1"
        private const val ALERT_TITLE_ID = "android:id/alertTitle"
        private const val RETRY_DELAY_MS = 1_000L
        private const val MAX_AUTOMATION_MS = 120_000L
        private val START_STREAM_TEXTS = setOf(
            "ScreenStreamUnattendedStart", "Start streaming", "Start stream", "开始串流", "开始流媒体", "開始串流"
        )
        private val STOP_STREAM_TEXTS = setOf(
            "ScreenStreamUnattendedStop", "Stop streaming", "Stop stream", "停止串流", "停止流媒体"
        )
        private val CONTINUE_TEXTS = setOf("Continue", "继续", "繼續")
        private val PROJECTION_TITLE_MARKERS = setOf("record", "cast", "share", "录制", "投射", "共享", "錄製", "投放", "分享")
    }

    private val handler = Handler(Looper.getMainLooper())
    private var automationStartedAt = 0L
    private var lastLaunchAt = 0L
    private var launchPending = false
    private var projectionConfirmed = false
    private var launchOverlay: View? = null

    private val triggerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_TRIGGER) beginAutomation()
        }
    }

    private val retryRunnable = object : Runnable {
        override fun run() = driveAutomation()
    }

    override fun onCreate() {
        super.onCreate()
        ContextCompat.registerReceiver(
            this,
            triggerReceiver,
            IntentFilter(ACTION_TRIGGER),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        if (UnattendedModeStore.isPending(this)) beginAutomation()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (UnattendedModeStore.isPending(this)) scheduleDrive(150L)
    }

    override fun onInterrupt(): Unit = Unit

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        removeLaunchOverlay()
        unregisterReceiver(triggerReceiver)
        super.onDestroy()
    }

    private fun beginAutomation() {
        if (!UnattendedModeStore.isEnabled(this) || !UnattendedModeStore.isPending(this)) return
        automationStartedAt = 0L
        lastLaunchAt = 0L
        projectionConfirmed = false
        XLog.i("UnattendedAccessibilityService: automation armed")
        scheduleDrive(250L)
    }

    private fun scheduleDrive(delayMs: Long = RETRY_DELAY_MS) {
        handler.removeCallbacks(retryRunnable)
        handler.postDelayed(retryRunnable, delayMs)
    }

    private fun driveAutomation() {
        if (!UnattendedModeStore.isEnabled(this) || !UnattendedModeStore.isPending(this)) return
        val now = SystemClock.elapsedRealtime()

        val userManager = getSystemService(UserManager::class.java)
        val keyguard = getSystemService(KeyguardManager::class.java)
        if (userManager?.isUserUnlocked != true || keyguard?.isDeviceLocked == true) {
            // AppSettings is stored in credential-protected storage. Starting the activity during
            // Direct Boot can leave its eager DataStore flow stuck on the default module value.
            automationStartedAt = 0L
            scheduleDrive()
            return
        }

        if (automationStartedAt == 0L) automationStartedAt = now
        if (now - automationStartedAt > MAX_AUTOMATION_MS) {
            XLog.w("UnattendedAccessibilityService: automation timed out; leaving request pending")
            removeLaunchOverlay()
            return
        }

        val root = rootInActiveWindow
        val activePackage = root?.packageName?.toString()
        when {
            activePackage == packageName -> driveOwnUi(root)
            activePackage == SYSTEM_UI_PACKAGE -> driveProjectionDialog(root)
            now - lastLaunchAt >= 5_000L -> launchOwnApp(now)
        }
        scheduleDrive()
    }

    private fun driveOwnUi(root: AccessibilityNodeInfo) {
        removeLaunchOverlay()
        if (projectionConfirmed && root.containsAnyText(STOP_STREAM_TEXTS)) {
            XLog.i("UnattendedAccessibilityService: stream confirmed; automation complete")
            UnattendedModeStore.setPending(this, false)
            handler.removeCallbacks(retryRunnable)
            return
        }

        root.findFirstByExactText(CONTINUE_TEXTS)?.clickNodeOrParent()?.let { clicked ->
            if (clicked) XLog.i("UnattendedAccessibilityService: confirmed ScreenStream education")
            return
        }

        root.findFirstByExactText(START_STREAM_TEXTS)?.clickNodeOrParent()?.let { clicked ->
            if (clicked) XLog.i("UnattendedAccessibilityService: requested stream start")
        }
    }

    private fun driveProjectionDialog(root: AccessibilityNodeInfo) {
        val title = root.findAccessibilityNodeInfosByViewId(ALERT_TITLE_ID)
            .firstOrNull()?.text?.toString().orEmpty()
        val isScreenStreamDialog = title.contains("ScreenStream", ignoreCase = true) &&
                PROJECTION_TITLE_MARKERS.any { title.contains(it, ignoreCase = true) }
        if (!isScreenStreamDialog) return

        val positive = root.findAccessibilityNodeInfosByViewId(POSITIVE_BUTTON_ID).firstOrNull() ?: return
        if (positive.clickNodeOrParent()) {
            projectionConfirmed = true
            XLog.i("UnattendedAccessibilityService: confirmed verified MediaProjection dialog")
        }
    }

    private fun launchOwnApp(now: Long) {
        if (launchPending) return
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        ensureLaunchOverlay()
        launchPending = true
        lastLaunchAt = now
        handler.postDelayed({
            launchPending = false
            runCatching { startActivity(launchIntent) }
                .onSuccess { XLog.i("UnattendedAccessibilityService: launched ScreenStream with accessibility overlay") }
                .onFailure { XLog.e("UnattendedAccessibilityService: unable to launch ScreenStream", it) }
        }, 250L)
    }

    private fun ensureLaunchOverlay() {
        if (launchOverlay != null) return
        val windowManager = getSystemService(WindowManager::class.java) ?: return
        val view = View(this)
        val layoutParams = WindowManager.LayoutParams(
            1,
            1,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            alpha = 0.01F
        }
        runCatching { windowManager.addView(view, layoutParams) }
            .onSuccess {
                launchOverlay = view
                XLog.i("UnattendedAccessibilityService: temporary launch overlay attached")
            }
            .onFailure { XLog.e("UnattendedAccessibilityService: unable to attach launch overlay", it) }
    }

    private fun removeLaunchOverlay() {
        val view = launchOverlay ?: return
        launchOverlay = null
        runCatching { getSystemService(WindowManager::class.java)?.removeViewImmediate(view) }
            .onFailure { XLog.w("UnattendedAccessibilityService: unable to remove launch overlay", it) }
    }

    private fun AccessibilityNodeInfo.findFirstByExactText(candidates: Set<String>): AccessibilityNodeInfo? {
        val values = listOfNotNull(text?.toString()?.trim(), contentDescription?.toString()?.trim())
        if (values.any { value -> candidates.any { it.equals(value, ignoreCase = true) } }) return this
        for (index in 0 until childCount) {
            getChild(index)?.findFirstByExactText(candidates)?.let { return it }
        }
        return null
    }

    private fun AccessibilityNodeInfo.containsAnyText(candidates: Set<String>): Boolean =
        findFirstByExactText(candidates) != null

    private fun AccessibilityNodeInfo.clickNodeOrParent(): Boolean {
        var candidate: AccessibilityNodeInfo? = this
        repeat(4) {
            val current = candidate
            if (current?.isClickable == true) return current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            candidate = current?.parent
        }
        return false
    }
}
