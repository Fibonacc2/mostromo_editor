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
    private var pendingFilePath: String? = null 

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Uygulama tamamen kapalıyken gelen intent'i yakala
        pendingFilePath = handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val path = handleIntent(intent)
        // Uygulama arka planda açıkken gelen dosyayı hemen Flutter'a bildir
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
            // Geçici dosyayı oluştur
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
        
        // Flutter hazır olduğunda kanalı kur ve bekleyen dosya varsa gönder
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialFile") {
                result.success(pendingFilePath)
                pendingFilePath = null // İşlem bitti, temizle
            } else {
                result.notImplemented()
            }
        }
    }
}