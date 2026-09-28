from pathlib import Path

dto = Path("app/src/main/java/com/example/data/remote/dto/RestDtos.kt")
s = dto.read_text()
s = s.replace(
    '@param:Json(name = "funcao_at") val funcaoAt: String? = null,',
    '@param:Json(name = "funcao_at") val funcaoAt: Boolean = false,'
)
dto.write_text(s)

repo = Path("app/src/main/java/com/example/data/repository/SupabaseAuthRepositoryImpl.kt")
s = repo.read_text()
s = s.replace('val trimmedPass = password.trim()', 'val trimmedPass = password')

old_start = s.index('    private suspend fun fetchProfileFromDatabase(')
old_end = s.index('\n    override suspend fun refreshSession()', old_start)

new_method = '''    private suspend fun fetchProfileFromDatabase(userId: String, fallbackEmail: String, accessToken: String): UserProfile? {
        return try {
            val response = clientFactory.restApi.getPerfis(
                authHeader = "Bearer $accessToken",
                select = "id,nome_completo,nome_exibicao,email,tipo,ativo,funcao_at",
                idFilter = "eq.$userId"
            )

            if (!response.isSuccessful) {
                Log.w(TAG, "Falha ao carregar perfil: HTTP " + response.code())
                return null
            }

            val p = response.body()?.firstOrNull() ?: return null

            if (!p.ativo) {
                throw IllegalStateException(
                    "O seu acesso ao CIADI+ está inativo. Contacte a administração do CIADI."
                )
            }

            val role = if (p.funcaoAt) UserRole.AT else UserRole.fromCode(p.tipo)

            UserProfile(
                id = p.id,
                email = p.email ?: fallbackEmail,
                fullName = p.nomeCompleto ?: p.nomeExibicao ?: fallbackEmail.substringBefore("@"),
                role = role,
                specialty = if (p.funcaoAt) "Acompanhante Terapêutico" else null,
                unitName = "CIADI — Centro Integrado",
                permissions = Permission.defaultPermissionsFor(role)
            )
        } catch (e: IllegalStateException) {
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao carregar perfil CIADI+ para " + userId + ": " + e.message, e)
            null
        }
    }
'''
s = s[:old_start] + new_method + s[old_end:]

marker = '        } catch (e: java.net.UnknownHostException) {'
replacement = '''        } catch (e: IllegalStateException) {
            Log.w(TAG, "Acesso recusado: " + e.message)
            return@withContext Result.failure(e)
        } catch (e: java.net.UnknownHostException) {'''
if marker not in s:
    raise SystemExit("Expected auth exception marker not found")
s = s.replace(marker, replacement, 1)
repo.write_text(s)

interceptor = Path("app/src/main/java/com/example/data/remote/interceptor/SupabaseAuthInterceptor.kt")
s = interceptor.read_text()
s = s.replace(
    'val isAuthTokenEndpoint = path.contains("auth/v1/token") || path.contains("auth/v1/recover")',
    'val isAuthEndpoint = path.startsWith("/auth/v1/")'
)
s = s.replace('if (!isAuthTokenEndpoint) {', 'if (!isAuthEndpoint) {')
interceptor.write_text(s)

assert 'funcaoAt: Boolean' in dto.read_text()
assert 'val trimmedPass = password' in repo.read_text()
assert 'funcaoAt) UserRole.AT' in repo.read_text()
assert 'val isAuthEndpoint = path.startsWith("/auth/v1/")' in interceptor.read_text()
print("CIADI+ authentication patch OK")
