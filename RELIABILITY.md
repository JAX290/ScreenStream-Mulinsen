# Background reliability

This fork keeps the upstream foreground media-projection service and adds two safeguards for unattended viewing:

* A high-performance Wi-Fi lock is held for the lifetime of an active foreground stream. This prevents Wi-Fi power saving from suspending an otherwise healthy stream while the display is dimmed.
* WebRTC signaling recovery continues for as long as a stream is active. Temporary outages no longer become terminal merely because a fixed retry count was reached.
* RTSP client mode keeps the active media-projection session and reconnects to the publishing server with a capped backoff after network or server interruptions.

The app settings screen also reports Android's battery-optimization status and links to the system exclusion screen.

## Device setup checklist

For a dedicated remote device:

1. Set ScreenStream to **Unrestricted** in Android battery settings.
2. Enable the manufacturer's **Auto start**, **Run in background**, and **Lock app in Recents** options when present.
3. Keep streaming notifications enabled. Android requires a visible foreground-service notification for screen capture.
4. Keep the device powered and use a stable Wi-Fi connection. Disable scheduled reboot and automatic power-off features.
5. Start the stream once locally and confirm that it remains available after the screen is dimmed and after a network interruption.

## Android limitation

These changes improve survival while the foreground service and media-projection session exist. They cannot silently recreate screen-capture consent after a reboot, force-stop, app update, or process death. Modern Android deliberately treats a media-projection grant as session-scoped; after such an event, the user must open the app and approve screen capture again.
