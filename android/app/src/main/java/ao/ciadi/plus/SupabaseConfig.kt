package ao.ciadi.plus

import java.net.URLEncoder

object SupabaseConfig {
    const val SUPABASE_URL = "https://egpkkttbcaukqnnxyhjv.supabase.co"
    const val SUPABASE_PUBLISHABLE_KEY = "sb_publishable_SSA6B6gfnaUxKhOzReE6HQ_utqQRebz"

    fun clinicRoomUrl(agendamentoId: String): String =
        "https://ivanioalberto83-cmyk.github.io/ciadi/ciadi-plus-web/sala.html?agendamento_id=" +
            URLEncoder.encode(agendamentoId, "UTF-8")
}
