package com.douyin.downloader

import android.Manifest
import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.webkit.*
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import kotlinx.coroutines.*

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private var pythonReady = false
    private val mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    companion object {
        private const val SERVER_PORT = 8765
        private const val PERMISSION_REQUEST_CODE = 100
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        webView = findViewById(R.id.webview)

        setupWebView()

        mainScope.launch {
            showLoadingDialog()
            try {
                initPython()
                loadWebApp()
            } catch (e: Exception) {
                e.printStackTrace()
                showError("初始化失败: ${e.message}")
                loadFallbackPage()
            } finally {
                dismissLoadingDialog()
            }
        }

        handleSharedIntent(intent)
    }

    private fun initPython() {
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }
        val py = Python.getInstance()
        val server = py.getModule("server")
        server.callAttr("start_server", SERVER_PORT)
        // 等待服务器启动
        Thread.sleep(2000)
        pythonReady = true
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleSharedIntent(intent)
    }

    private fun handleSharedIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
            mainScope.launch {
                delay(3000)
                val escaped = sharedText.replace("\\", "\\\\")
                    .replace("'", "\\'")
                    .replace("\n", "\\n")
                webView.evaluateJavascript(
                    "document.getElementById('shareUrl').value = '$escaped';" +
                    "document.getElementById('shareUrl').focus();" +
                    "document.getElementById('shareUrl').scrollIntoView();",
                    null
                )
            }
        }
    }

    private fun setupWebView() {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowContentAccess = true
            allowFileAccess = true
            setSupportMultipleWindows(false)
            builtInZoomControls = false
            displayZoomControls = false
            loadsImagesAutomatically = true
            mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            userAgentString = "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
                    "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
            }
        }
    }


    private fun loadWebApp() {
        webView.loadUrl("http://127.0.0.1:$SERVER_PORT/")
    }

    private fun loadFallbackPage() {
        webView.loadDataWithBaseURL(
            null,
            "<html><body style='background:#0f0f13;color:#e8e8f0;padding:40px;text-align:center;font-family:sans-serif'>" +
            "<h2>启动失败</h2>" +
            "<p style='color:#888;margin-top:16px'>Python 环境初始化失败</p>" +
            "<p style='color:#666;font-size:13px;margin-top:8px'>请尝试重启应用</p>" +
            "</body></html>",
            "text/html", "utf-8", null
        )
    }

    private fun downloadVideo(url: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startDownload(url)
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
                != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this,
                    arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    PERMISSION_REQUEST_CODE)
                return
            }
            startDownload(url)
        }
    }

    private fun startDownload(url: String) {
        try {
            val fileName = "douyin_${System.currentTimeMillis()}.mp4"
            val request = DownloadManager.Request(Uri.parse(url))
                .setTitle("抖音视频下载")
                .setDescription("正在下载视频...")
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(true)

            val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            downloadManager.enqueue(request)
            showToast("已加入下载队列")
        } catch (e: Exception) {
            showToast("下载失败: ${e.message}")
        }
    }

    private var loadingDialog: AlertDialog? = null

    private fun showLoadingDialog() {
        loadingDialog = AlertDialog.Builder(this)
            .setTitle("启动中")
            .setMessage("正在初始化 Python 环境...")
            .setCancelable(false)
            .show()
    }

    private fun dismissLoadingDialog() {
        loadingDialog?.dismiss()
        loadingDialog = null
    }

    private fun showError(msg: String) {
        showToast(msg)
    }

    private fun showToast(msg: String) {
        runOnUiThread {
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        mainScope.cancel()
    }
}
