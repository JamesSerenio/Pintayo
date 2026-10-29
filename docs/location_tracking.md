# Location sharing and tracking

Sharing begins only after selection of accepted friends and/or circles plus a duration: 15 minutes, one hour, or until stopped. Existing circle members are snapshotted at that explicit action. New/rejoined members do not inherit an old session. Pause, stop, expiry, blocks, friend removal and circle departure revoke server authorization; the UI timer is only presentation/device cleanup.

The native Geolocator stream uses high accuracy and a 10 m distance filter. Configurable publication targets are 15 seconds while moving and 60 seconds for stationary fixes that the OS emits. The distance filter may mean no new stationary fix arrives; the app then labels the coordinate as last known. These targets are throttles, not OS scheduling promises. Poor fixes above 1000 m accuracy are rejected; each displayed location includes accuracy and time. Delayed or duplicate fix timestamps cannot overwrite a newer row. Permanent movement history is not stored.

## Android

The manifest declares coarse/fine/background location, foreground-service/location, wake lock, internet and notification permissions. Geolocator owns `GeolocatorLocationService`, declared with the location foreground-service type. Explicit sharing starts that native service while the activity is foregrounded, with an ongoing notification and wake lock. A Dart timer is not responsible for keeping GPS alive.

Precise foreground permission is requested after Enable Location or explicit sharing start. A denied user can keep chatting. Android background/“Allow all the time” access may require the device’s App Settings flow; location settings and app-permission shortcuts are provided. Foreground services must be started from the foreground under Android’s current restrictions. Manufacturer battery restrictions may stop updates. Do not claim survival of force-stop or process termination. Test Android 13–16 notification/location/service behavior on actual target devices.

## iOS/iPadOS

Info.plist includes purpose strings, location background mode, background push mode and photo-library permission. `AppleSettings` enables background updates and the visible background-location indicator only for sharing; automatic pausing is allowed. Always-location access is requested after the explicit sharing action. If it remains When In Use, the UI warns that updates can stop in the background. On app startup, already-granted permission can recenter the map or resume a still-authorized session without issuing an unsolicited prompt. Denied permission is never automatically requested on startup.

Enable Background Modes / Location updates in the signed Xcode target, supply real signing capabilities and test the Always permission upgrade flow. No iOS build or device verification was possible on this Windows machine.

## Lifecycle and failures

Sharing/tracker providers are retained at authenticated-session scope across screens. Logout stops the session server-side, removes notifications and disposes the tracker. Pause/stop always stops publication on this device first; if the server cannot be reached, the UI asks you to reconnect and retry to confirm revocation of the last known fix. Expiration stops publication and the native stream locally; database time independently denies access. Supabase handles token refresh in the current process. A connectivity or GPS failure displays a recovery message; no historical coordinate batch is queued. Reconnect resumes from a new OS fix. Closing/force-stopping the process can interrupt tracking; disabled GPS, revoked access or unavailable internet prevents updates.

Map startup without a location uses a country overview, never a fabricated device coordinate. Markers appear only for authorized rows, animate to newer fixes and show their timestamps. Follow stops when panning; recenter resumes following. Distance is straight-line distance, not road distance or ETA. Long-press creates a meet-up pin. OSM tile attribution is visible; `TILE_URL` and application identification are configurable, built-in header-aware cache is enabled, and `panBuffer=0` avoids prefetch beyond the viewport. Respect the [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/).

Before release, test with screen off, backgrounded for at least 30 minutes, low power mode, stationary/moving transitions, GPS disabled, denied/approximate permission, airplane mode, Wi-Fi/mobile handover, token refresh, session expiration, account logout and force-stop. Check both the sender’s ongoing notification and the recipient’s freshness label, then verify that revoked readers receive no new websocket coordinates.
