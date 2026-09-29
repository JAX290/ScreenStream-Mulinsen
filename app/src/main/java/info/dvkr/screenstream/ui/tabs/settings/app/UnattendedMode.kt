package info.dvkr.screenstream.ui.tabs.settings.app

import android.content.Intent
import android.provider.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import info.dvkr.screenstream.R
import info.dvkr.screenstream.ui.tabs.settings.app.common.SettingSwitchRow
import info.dvkr.screenstream.unattended.UnattendedModeStore

@Composable
internal fun UnattendedModeRow(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var enabled by remember { mutableStateOf(UnattendedModeStore.isEnabled(context)) }
    var accessibilityEnabled by remember { mutableStateOf(UnattendedModeStore.isAccessibilityEnabled(context)) }

    DisposableEffect(context, lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                enabled = UnattendedModeStore.isEnabled(context)
                accessibilityEnabled = UnattendedModeStore.isAccessibilityEnabled(context)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    SettingSwitchRow(
        checked = enabled,
        iconRes = R.drawable.settings_24px,
        title = stringResource(R.string.app_pref_unattended_mode),
        summary = stringResource(
            when {
                !enabled -> R.string.app_pref_unattended_mode_off
                accessibilityEnabled -> R.string.app_pref_unattended_mode_ready
                else -> R.string.app_pref_unattended_mode_needs_accessibility
            }
        ),
        onValueChange = { newValue ->
            enabled = newValue
            UnattendedModeStore.setEnabled(context, newValue)
            if (newValue) context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        },
        modifier = modifier
    )
}
