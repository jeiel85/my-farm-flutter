package com.jeiel85.myfarm

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jeiel85.myfarm/update")
            .setMethodCallHandler(::onUpdateCall)
    }

    /// 앱 안 업데이트(lib/data/app_update.dart)의 네이티브 부분.
    private fun onUpdateCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "info" -> {
                val pkg = packageManager.getPackageInfo(packageName, 0)
                @Suppress("DEPRECATION")
                val versionCode = if (Build.VERSION.SDK_INT >= 28) pkg.longVersionCode else pkg.versionCode.toLong()
                result.success(
                    mapOf(
                        "versionCode" to versionCode,
                        "versionName" to (pkg.versionName ?: ""),
                        "sdkInt" to Build.VERSION.SDK_INT,
                        "cacheDir" to cacheDir.absolutePath,
                    )
                )
            }
            "canInstall" -> result.success(Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls())
            "openInstallSettings" -> {
                if (Build.VERSION.SDK_INT >= 26) {
                    startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                }
                result.success(null)
            }
            "sha256" -> {
                val file = updateFile(call.arguments as String) ?: return result.error("bad_path", null, null)
                // 수십 MB를 읽으므로 UI 스레드를 막지 않는다.
                Thread {
                    val hash = runCatching { sha256(file) }
                    runOnUiThread {
                        hash.fold({ result.success(it) }, { result.error("hash_failed", it.message, null) })
                    }
                }.start()
            }
            "install" -> {
                val file = updateFile(call.arguments as String) ?: return result.error("bad_path", null, null)
                val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                // ACTION_VIEW는 파일 관리자·다른 설치 앱이 끼어들 수 있어 시스템 설치 화면으로만 보낸다.
                // 다른 키로 서명된 APK는 OS가 설치를 거부한다.
                @Suppress("DEPRECATION")
                val intent = Intent(Intent.ACTION_INSTALL_PACKAGE)
                    .setData(uri)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                try {
                    startActivity(intent)
                    result.success(null)
                } catch (e: ActivityNotFoundException) {
                    result.error("no_installer", e.message, null)
                }
            }
            "openUrl" -> {
                val url = call.arguments as String
                if (!url.startsWith("https://")) return result.error("bad_url", null, null)
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    result.success(null)
                } catch (e: ActivityNotFoundException) {
                    result.error("no_browser", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /// FileProvider에 연 경로(cache/updates/) 안의 파일만 받는다.
    private fun updateFile(path: String): File? {
        val dir = File(cacheDir, "updates").canonicalFile
        val file = File(path).canonicalFile
        return if (file.parentFile == dir && file.isFile) file else null
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                digest.update(buffer, 0, n)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
