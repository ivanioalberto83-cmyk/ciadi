package ao.ciadi.plus

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
        }

        layout.addView(TextView(this).apply {
            text = "CIADI+\nClínica Virtual"
            textSize = 26f
        })

        layout.addView(Button(this).apply {
            text = "Abrir Clínica Virtual"
            setOnClickListener {
                val i = Intent(this@MainActivity, ClinicaVirtualActivity::class.java)
                i.putExtra("agendamento_id", intent.getStringExtra("agendamento_id"))
                startActivity(i)
            }
        })

        setContentView(layout)
    }
}
