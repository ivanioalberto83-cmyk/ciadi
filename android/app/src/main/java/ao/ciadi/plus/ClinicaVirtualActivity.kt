package ao.ciadi.plus

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class ClinicaVirtualActivity : AppCompatActivity() {
    private lateinit var webView: WebView

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
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.mediaPlaybackRequiresUserGesture = false
        webView.webViewClient = WebViewClient()
        webView.webChromeClient = object : WebChromeClient() {
            override fun onPermissionRequest(request: PermissionRequest) {
                runOnUiThread { request.grant(request.resources) }
            }
        }

        setContentView(webView)
        webView.loadUrl(SupabaseConfig.clinicRoomUrl(id))
    }

    override fun onDestroy() {
        webView.destroy()
        super.onDestroy()
    }
}
