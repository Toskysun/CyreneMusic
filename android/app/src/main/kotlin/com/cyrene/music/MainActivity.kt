package com.cyrene.music

import android.os.Bundle
import android.util.Log
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // 必须在 super.onCreate() 之前调用 installSplashScreen()
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d("MainActivity", "🔧 开始配置 Flutter Engine")

        try {
            // 注册悬浮歌词插件
            val floatingPlugin = FloatingLyricPlugin()
            flutterEngine.plugins.add(floatingPlugin)
            Log.d("MainActivity", "✅ 悬浮歌词插件注册成功: ${floatingPlugin::class.java.simpleName}")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ 悬浮歌词插件注册失败: ${e.message}", e)
        }

        try {
            // 注册 Android 媒体通知插件
            val mediaNotificationPlugin = AndroidMediaNotificationPlugin()
            flutterEngine.plugins.add(mediaNotificationPlugin)
            Log.d("MainActivity", "✅ 媒体通知插件注册成功: ${mediaNotificationPlugin::class.java.simpleName}")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ 媒体通知插件注册失败: ${e.message}", e)
        }
    }
}

