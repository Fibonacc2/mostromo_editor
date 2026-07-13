package com.example.mostromo_editor // Kendi paket adınla değiştirmeyi unutma!

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "mostromo/file_intent"
    private var startupRoute: String = "/" // Varsayılan rota ana ekran

    override fun onCreate(savedInstanceState: Bundle?) {
        // Flutter uyanmadan önce intent'i kontrol et
        val path = handleIntent(intent)
        if (path != null) {
            // Eğer bir dosya açılıyorsa, Flutter'ın ilk açacağı sayfayı /reader olarak ayarla!
            startupRoute = "/reader?path=${Uri.encode(path)}"
        }
        super.onCreate(savedInstanceState)
    }

    // 🌟 KİLİT ÇÖZÜM: GoRouter "Uygulama açıldı, nereye gideyim?" dediğinde cevabımız:
    override fun getInitialRoute(): String {
        return startupRoute 
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Uygulama ZATEN AÇIKKEN yeni bir dosyaya tıklanırsa
        val path = handleIntent(intent)
        if (path != null) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let {
                MethodChannel(it, CHANNEL).invokeMethod("onFileOpened", path)
            }
        }
    }

    private fun handleIntent(intent: Intent): String? {
        if (Intent.ACTION_VIEW == intent.action) {
            val uri: Uri? = intent.data
            if (uri != null) {
                return copyToCache(uri)
            }
        }
        return null
    }

    private fun copyToCache(uri: Uri): String? {
        try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val tempFile = File(cacheDir, "external_note_${System.currentTimeMillis()}.mostromo")
            val outputStream = FileOutputStream(tempFile)
            inputStream.copyTo(outputStream)
            inputStream.close()
            outputStream.close()
            return tempFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Artık "getInitialFile" metoduna gerek kalmadı çünkü getInitialRoute ile işi hallettik, 
        // ancak "onFileOpened" (uygulama açıkken tıklanma) için kanal açık kalmalı.
    }
}