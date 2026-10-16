package com.talhagohar.malikiprayertimes

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Re-schedules prayer-time notifications after a device reboot (REL-03).
 * flutter_local_notifications schedules do not survive a restart, so without
 * this receiver every notification is silently lost until the user next opens
 * the app.
 *
 * Android 12+ background limits: a BOOT_COMPLETED receiver only gets a brief
 * execution window, and the process may be killed soon after onReceive()
 * returns — so the Dart entrypoint runs synchronously here with a bounded
 * wait instead of being left to finish in the background. BOOT_COMPLETED is
 * delivered after the user unlocks the device (not during direct boot), so
 * SharedPreferences is readable.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val pendingResult = goAsync()
        try {
            runReschedule(context.applicationContext)
        } catch (_: Throwable) {
            // Never crash the boot path: worst case the next app launch
            // re-schedules through _NotificationBootstrap.
        } finally {
            pendingResult.finish()
        }
    }

    private fun runReschedule(appContext: Context) {
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(appContext)
            loader.ensureInitializationComplete(appContext, null)
        }
        val engine = FlutterEngine(appContext)
        try {
            io.flutter.plugins.GeneratedPluginRegistrant.registerWith(engine)
            val done = CountDownLatch(1)
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                "com.talhagohar.malikiprayertimes/boot_reschedule",
            ).setMethodCallHandler { call, result ->
                if (call.method == "done") {
                    done.countDown()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
            val entrypoint = DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                "rescheduleOnBoot",
            )
            engine.dartExecutor.executeDartEntrypoint(entrypoint)
            // Bounded wait: the OS can kill a lingering receiver anyway, and
            // the Dart side also signals completion, so never block boot
            // indefinitely.
            done.await(30, TimeUnit.SECONDS)
        } finally {
            engine.destroy()
        }
    }
}
