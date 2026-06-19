package com.example.mostromo_editor

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
    private var initialFilePath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    // Uygulama arka planda açıkken dosyaya tıklanırsa tetiklenir
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        
        initialFilePath?.let {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onFileOpened", it)
            }
        }
    }

    private fun handleIntent(intent: Intent) {
        if (Intent.ACTION_VIEW == intent.action) {
            val uri: Uri? = intent.data
            if (uri != null) {
                initialFilePath = copyToCache(uri) // Dart'ın okuyabilmesi için çevir!
            }
        }
    }

    // 🌟 SİHİRLİ KISIM: content:// şifreli yolunu kırıp fiziksel dosyaya dönüştürür
    private fun copyToCache(uri: Uri): String? {
        try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            // Önbellekte geçici bir Mostromo dosyası oluştur
            val tempFile = File(cacheDir, "external_note_${System.currentTimeMillis()}.mostromo")
            val outputStream = FileOutputStream(tempFile)
            inputStream.copyTo(outputStream)
            inputStream.close()
            outputStream.close()
            return tempFile.absolutePath
        } catch (e: Exception) {
            return null
        }
    }

    // Flutter ile iletişime geçiş
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialFile") {
                result.success(initialFilePath)
                initialFilePath = null // Okunduktan sonra temizle
            } else {
                result.notImplemented()
            }
        }
    }
}
