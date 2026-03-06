package com.mg.wandeung

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
            "ffmpeg_kit_flutter_new" to { com.antonkarpenko.ffmpegkit.FFmpegKitFlutterPlugin() },
            "file_picker" to { com.mr.flutter.plugin.filepicker.FilePickerPlugin() },
            // FlutterNaverMapPlugin is Kotlin-internal; use reflection
            "flutter_naver_map" to {
                val cls = Class.forName("dev.note11.flutter_naver_map.flutter_naver_map.FlutterNaverMapPlugin")
                cls.getDeclaredConstructor().newInstance() as FlutterPlugin
            },
            "flutter_plugin_android_lifecycle" to { io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin() },
            "gal" to { studio.midoridesign.gal.GalPlugin() },
            "geocoding_android" to { com.baseflow.geocoding.GeocodingPlugin() },
            "geolocator_android" to { com.baseflow.geolocator.GeolocatorPlugin() },
            "get_thumbnail_video" to { xyz.justsoft.video_thumbnail.VideoThumbnailPlugin() },
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
            try {
                flutterEngine.plugins.add(factory())
            } catch (t: Throwable) {
                Log.e(TAG, "Error registering plugin $name", t)
            }
        }
    }
}
