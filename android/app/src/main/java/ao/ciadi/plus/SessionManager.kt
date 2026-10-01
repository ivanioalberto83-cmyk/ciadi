package ao.ciadi.plus

import android.content.Context

class SessionManager(context: Context) {
    private val prefs = context.getSharedPreferences("ciadi_session", Context.MODE_PRIVATE)

    fun saveAccessToken(token: String) =
        prefs.edit().putString("access_token", token).apply()

    fun getAccessToken(): String? = prefs.getString("access_token", null)

    fun clear() = prefs.edit().clear().apply()
}
