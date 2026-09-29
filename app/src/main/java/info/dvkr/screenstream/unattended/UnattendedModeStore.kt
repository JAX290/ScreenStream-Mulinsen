package info.dvkr.screenstream.unattended

import android.content.ComponentName
import android.content.Context
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityManager

internal object UnattendedModeStore {
    private const val PREFERENCES = "unattended_mode"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_PENDING = "pending_after_boot"

    private fun preferences(context: Context) = context.createDeviceProtectedStorageContext()
        .getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    fun isEnabled(context: Context): Boolean = preferences(context).getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        preferences(context).edit()
            .putBoolean(KEY_ENABLED, enabled)
            .also { if (!enabled) it.putBoolean(KEY_PENDING, false) }
            .apply()
    }

    fun isPending(context: Context): Boolean = preferences(context).getBoolean(KEY_PENDING, false)

    fun setPending(context: Context, pending: Boolean) {
        preferences(context).edit().putBoolean(KEY_PENDING, pending).apply()
    }

    fun isAccessibilityEnabled(context: Context): Boolean {
        val expected = ComponentName(context, UnattendedAccessibilityService::class.java)
        val manager = context.getSystemService(AccessibilityManager::class.java) ?: return false
        return manager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .any { ComponentName(it.resolveInfo.serviceInfo.packageName, it.resolveInfo.serviceInfo.name) == expected }
    }
}
