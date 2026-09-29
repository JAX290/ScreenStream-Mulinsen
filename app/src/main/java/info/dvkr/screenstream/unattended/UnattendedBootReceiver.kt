package info.dvkr.screenstream.unattended

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.elvishew.xlog.XLog
import info.dvkr.screenstream.BuildConfig

public class UnattendedBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val supportedBootAction = intent.action in SUPPORTED_ACTIONS
        val debugTestAction = BuildConfig.DEBUG && intent.action == ACTION_TEST_UNATTENDED_BOOT
        if ((!supportedBootAction && !debugTestAction) || !UnattendedModeStore.isEnabled(context)) return

        XLog.i("UnattendedBootReceiver: ${intent.action}; arming unattended capture")
        UnattendedModeStore.setPending(context, true)
        context.sendBroadcast(Intent(UnattendedAccessibilityService.ACTION_TRIGGER).setPackage(context.packageName))
    }

    private companion object {
        const val ACTION_TEST_UNATTENDED_BOOT = "info.dvkr.screenstream.action.TEST_UNATTENDED_BOOT"
        val SUPPORTED_ACTIONS: Set<String?> = setOf(
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_USER_UNLOCKED,
            Intent.ACTION_MY_PACKAGE_REPLACED
        )
    }
}
