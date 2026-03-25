package com.mg.cling

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Register each plugin individually with try-catch(Throwable).
        // The default GeneratedPluginRegistrant only catches Exception,
        // but FFmpegKit throws java.lang.Error (UnsatisfiedLinkError)
        // which kills the entire registration process.
        val plugins: List<Pair<String, () -> FlutterPlugin>> = listOf(
            "app_links" to { com.llfbandit.app_links.AppLinksPlugin() },
            "camera_android_camerax" to { io.flutter.plugins.camerax.CameraAndroidCameraxPlugin() },
            "connectivity_plus" to { dev.fluttercommunity.plus.connectivity.ConnectivityPlugin() },
            "ffmpeg_kit_flutter_new" to { com.antonkarpenko.ffmpegkit.FFmpegKitFlutterPlugin() },
            "file_picker" to { com.mr.flutter.plugin.filepicker.FilePickerPlugin() },
            "flutter_plugin_android_lifecycle" to { io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin() },
            "google_maps_flutter_android" to { io.flutter.plugins.googlemaps.GoogleMapsPlugin() },
            "gal" to { studio.midoridesign.gal.GalPlugin() },
            "geolocator_android" to { com.baseflow.geolocator.GeolocatorPlugin() },
            "get_thumbnail_video" to { xyz.justsoft.video_thumbnail.VideoThumbnailPlugin() },
            "google_mobile_ads" to { io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin() },
            "google_sign_in_android" to { io.flutter.plugins.googlesignin.GoogleSignInPlugin() },
            "image_picker_android" to { io.flutter.plugins.imagepicker.ImagePickerPlugin() },
            "package_info_plus" to { dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin() },
            "path_provider_android" to { io.flutter.plugins.pathprovider.PathProviderPlugin() },
            "permission_handler_android" to { com.baseflow.permissionhandler.PermissionHandlerPlugin() },
            "shared_preferences_android" to { io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin() },
            "url_launcher_android" to { io.flutter.plugins.urllauncher.UrlLauncherPlugin() },
            "video_player_android" to { io.flutter.plugins.videoplayer.VideoPlayerPlugin() },
            "wakelock_plus" to { dev.fluttercommunity.plus.wakelock.WakelockPlusPlugin() },
        )

        for ((name, factory) in plugins) {
            var plugin: FlutterPlugin? = null
            try {
                plugin = factory()
                flutterEngine.plugins.add(plugin)
            } catch (t: Throwable) {
                Log.e(TAG, "Error registering plugin $name", t)
                // If onAttachedToEngine succeeded but onAttachedToActivity failed,
                // the method channel is left in a broken state. Remove the plugin
                // so Dart gets MissingPluginException instead of a fatal Error.
                if (plugin != null) {
                    try {
                        flutterEngine.plugins.remove(plugin.javaClass)
                    } catch (_: Throwable) {}
                }
            }
        }
    }
}
