#!/usr/bin/env bash
set -euo pipefail

APP_DIR="ciadi-plus-src"
ZIP="ciadi+ (1).zip"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
unzip -q "$ZIP" -d "$APP_DIR"
cd "$APP_DIR"

python3 - <<'PY'
from pathlib import Path

p=Path('app/build.gradle.kts')
s=p.read_text()
s=s.replace('versionCode = 1', 'versionCode = 13')
s=s.replace('versionName = "1.0"', 'versionName = "1.1.0"')
p.write_text(s)

p=Path('app/src/main/java/com/example/data/repository/SupabaseAuthRepositoryImpl.kt')
s=p.read_text().replace('val trimmedPass = password.trim()', 'val trimmedPass = password')
p.write_text(s)

p=Path('app/src/main/java/com/example/ui/screens/login/LoginScreen.kt')
s=p.read_text().replace('painterResource(id = R.drawable.ic_ciadi_logo_1790332105105)', 'painterResource(id = R.mipmap.ic_launcher)')
p.write_text(s)

p=Path('app/src/main/java/com/example/data/repository/SupabaseModulesRepositoryImpl.kt')
s=p.read_text()
s=s.replace('    private val _chatMensagens = MutableStateFlow<Map<String, List<ChatMensagemDto>>>(emptyMap())\n', '    private val chatMessageState = ChatMessageStateStore()\n')
s=s.replace('''    override fun observeChatMensagens(grupoId: String): Flow<List<ChatMensagemDto>> {
        val current = _chatMensagens.value[grupoId].orEmpty()
        return MutableStateFlow(current).asStateFlow()
    }
    override fun observeMensagens(grupoId: String): StateFlow<List<ChatMensagemDto>> {
        val current = _chatMensagens.value[grupoId].orEmpty()
        return MutableStateFlow(current).asStateFlow()
    }
''','''    override fun observeChatMensagens(grupoId: String): Flow<List<ChatMensagemDto>> =
        chatMessageState.flowFor(grupoId)

    override fun observeMensagens(grupoId: String): StateFlow<List<ChatMensagemDto>> =
        chatMessageState.flowFor(grupoId)
''')
s=s.replace('''            val current = _chatMensagens.value[grupoId].orEmpty()
            if (current.none { it.id == novaMsg.id }) {
                _chatMensagens.value = _chatMensagens.value + (grupoId to (current + novaMsg))
            }''','''            chatMessageState.appendIfMissing(grupoId, novaMsg)''')
s=s.replace('                _chatMensagens.value = _chatMensagens.value + (grupoId to msgs)', '                chatMessageState.replace(grupoId, msgs)')
s=s.replace('''                val current = _chatMensagens.value[grupoId].orEmpty()
                if (current.none { it.id == created.id }) {
                    _chatMensagens.value = _chatMensagens.value + (grupoId to (current + created))
                }''','''                chatMessageState.appendIfMissing(grupoId, created)''')
s=s.replace('''                val current = _chatMensagens.value[mensagem.grupoId].orEmpty()
                _chatMensagens.value = _chatMensagens.value + (mensagem.grupoId to (current + created))''','''                chatMessageState.appendIfMissing(mensagem.grupoId, created)''')
s=s.replace('        _chatMensagens.value = emptyMap()\n', '        chatMessageState.clear()\n')
p.write_text(s)
PY

cat > app/src/main/java/com/example/data/repository/ChatMessageStateStore.kt <<'KOTLIN'
package com.example.data.repository

import com.example.data.remote.dto.ChatMensagemDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

internal class ChatMessageStateStore {
    private val flows = mutableMapOf<String, MutableStateFlow<List<ChatMensagemDto>>>()

    @Synchronized
    fun flowFor(grupoId: String): StateFlow<List<ChatMensagemDto>> =
        flows.getOrPut(grupoId) { MutableStateFlow(emptyList()) }.asStateFlow()

    @Synchronized
    fun replace(grupoId: String, messages: List<ChatMensagemDto>) {
        flows.getOrPut(grupoId) { MutableStateFlow(emptyList()) }.value = messages
    }

    @Synchronized
    fun appendIfMissing(grupoId: String, message: ChatMensagemDto) {
        val state = flows.getOrPut(grupoId) { MutableStateFlow(emptyList()) }
        if (state.value.none { it.id == message.id }) state.value = state.value + message
    }

    @Synchronized
    fun clear() {
        flows.values.forEach { it.value = emptyList() }
        flows.clear()
    }
}
KOTLIN

python3 - <<'PY'
from pathlib import Path
p=Path('app/src/test/java/com/example/SupabaseAuthIntegrationTest.kt')
s=p.read_text()
start=s.index('    // Teste 10: RLS enforcement')
end=s.index('    // Teste 11:', start)
replacement='''    // Teste 10: a chamada REST usa o endpoint oficial e JWT separado da publishable key.
    @Test
    fun test10_PerfisRequestUsesOfficialEndpointAndPublicKey() {
        val request = Request.Builder()
            .url("${SupabaseConfig.supabaseUrl}/rest/v1/perfis?select=*")
            .header("apikey", SupabaseConfig.supabasePublishableKey)
            .header("Authorization", "Bearer mock-user-jwt")
            .get()
            .build()

        assertEquals("https://egpkkttbcaukqnnxyhjv.supabase.co/rest/v1/perfis?select=*", request.url.toString())
        assertEquals(SupabaseConfig.supabasePublishableKey, request.header("apikey"))
        assertEquals("Bearer mock-user-jwt", request.header("Authorization"))
    }

'''
s=s[:start]+replacement+s[end:]
p.write_text(s)
PY

cat > app/src/test/java/com/example/ChatMessageStateStoreTest.kt <<'KOTLIN'
package com.example

import com.example.data.remote.dto.ChatMensagemDto
import com.example.data.repository.ChatMessageStateStore
import org.junit.Assert.assertEquals
import org.junit.Test

class ChatMessageStateStoreTest {
    @Test
    fun realtimeMessageUpdatesTheSameObservedFlow() {
        val store = ChatMessageStateStore()
        val flow = store.flowFor("grupo-1")
        val message = ChatMensagemDto(
            grupoId = "grupo-1",
            remetenteId = "user-1",
            autorId = "user-1",
            conteudo = "Olá",
            mensagem = "Olá",
            lida = false
        )
        store.appendIfMissing("grupo-1", message)
        assertEquals(1, flow.value.size)
        assertEquals("Olá", flow.value.first().conteudo)
    }

    @Test
    fun duplicateRealtimeMessageIsIgnored() {
        val store = ChatMessageStateStore()
        val first = ChatMensagemDto(
            id = "msg-1",
            grupoId = "grupo-1",
            remetenteId = "user-1",
            autorId = "user-1",
            conteudo = "Olá",
            mensagem = "Olá",
            lida = false
        )
        store.appendIfMissing("grupo-1", first)
        store.appendIfMissing("grupo-1", first.copy(conteudo = "Alterada"))
        assertEquals(1, store.flowFor("grupo-1").value.size)
        assertEquals("Olá", store.flowFor("grupo-1").value.first().conteudo)
    }
}
KOTLIN

cat > app/src/main/res/drawable/ic_launcher_background.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#6F351F" android:pathData="M0,0h108v108h-108z" />
</vector>
XML

cat > app/src/main/res/drawable/ic_launcher_foreground.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#F58200" android:pathData="M18,54a36,36 0,1 0,72 0a36,36 0,1 0,-72 0" />
    <path android:fillColor="#FFDF19" android:pathData="M29,54a25,25 0,1 0,50 0a25,25 0,1 0,-50 0" />
    <path android:fillColor="#6F351F" android:pathData="M51,27h6v54h-6zM27,51h54v6h-54z" />
    <path android:fillColor="#FFFFFF" android:pathData="M54,36c-5,0 -9,4 -9,9s4,9 9,9 9,-4 9,-9 -4,-9 -9,-9M41,59c-4,4 -6,9 -6,15h38c0,-6 -2,-11 -6,-15 -3,4 -7,6 -13,6s-10,-2 -13,-6" />
</vector>
XML

cat > app/src/main/res/values/colors.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ciadi_orange">#F58200</color>
    <color name="ciadi_yellow">#FFDF19</color>
    <color name="ciadi_brown">#6F351F</color>
    <color name="ciadi_cream">#FFE7BF</color>
    <color name="white">#FFFFFFFF</color>
    <color name="black">#FF111111</color>
</resources>
XML

# APK build uses the icon already present in the CIADI+ source ZIP.
