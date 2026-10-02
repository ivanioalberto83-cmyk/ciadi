package ao.ciadi.plus

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class ClinicaVirtualActivity : AppCompatActivity() {
    private lateinit var webView: WebView

    companion object {
        private const val MEDIA_PERMISSION_REQUEST = 7001
        private val MEDIA_PERMISSIONS = arrayOf(
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO
        )
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val id = intent.getStringExtra("agendamento_id")
        if (id.isNullOrBlank()) {
            Toast.makeText(this, "Agendamento não informado.", Toast.LENGTH_LONG).show()
            finish()
            return
        }

        webView = WebView(this)
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            allowFileAccess = false
            allowContentAccess = false
        }
        webView.webViewClient = WebViewClient()
        webView.webChromeClient = object : WebChromeClient() {
            override fun onPermissionRequest(request: PermissionRequest) {
                runOnUiThread {
                    val cameraGranted = ContextCompat.checkSelfPermission(
                        this@ClinicaVirtualActivity,
                        Manifest.permission.CAMERA
                    ) == PackageManager.PERMISSION_GRANTED
                    val micGranted = ContextCompat.checkSelfPermission(
                        this@ClinicaVirtualActivity,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED

                    val requested = request.resources.toSet()
                    val canGrantCamera = PermissionRequest.RESOURCE_VIDEO_CAPTURE in requested && cameraGranted
                    val canGrantMic = PermissionRequest.RESOURCE_AUDIO_CAPTURE in requested && micGranted

                    val resources = buildList {
                        if (canGrantCamera) add(PermissionRequest.RESOURCE_VIDEO_CAPTURE)
                        if (canGrantMic) add(PermissionRequest.RESOURCE_AUDIO_CAPTURE)
                    }

                    if (resources.isNotEmpty()) {
                        request.grant(resources.toTypedArray())
                    } else {
                        request.deny()
                    }
                }
            }
        }

        setContentView(webView)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !mediaPermissionsGranted()) {
            ActivityCompat.requestPermissions(
                this,
                MEDIA_PERMISSIONS,
                MEDIA_PERMISSION_REQUEST
            )
        } else {
            loadClinicRoom(id)
        }
    }

    private fun mediaPermissionsGranted(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun loadClinicRoom(id: String) {
        webView.loadUrl(SupabaseConfig.clinicRoomUrl(id))
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != MEDIA_PERMISSION_REQUEST) return

        val id = intent.getStringExtra("agendamento_id")
        if (id.isNullOrBlank()) {
            finish()
            return
        }

        if (mediaPermissionsGranted()) {
            loadClinicRoom(id)
        } else {
            Toast.makeText(
                this,
                "A sala de vídeo precisa de acesso à câmara e ao microfone.",
                Toast.LENGTH_LONG
            ).show()
            finish()
        }
    }

    override fun onDestroy() {
        if (::webView.isInitialized) {
            webView.stopLoading()
            webView.loadUrl("about:blank")
            webView.destroy()
        }
        super.onDestroy()
    }
}
