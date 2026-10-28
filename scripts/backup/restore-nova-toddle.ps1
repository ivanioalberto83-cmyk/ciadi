#requires -Version 7.0
<#
.SYNOPSIS
  Restauro controlado de uma cópia PostgreSQL NOVA TODDLE em homologação.
.DESCRIPTION
  Script de segurança por defeito: não corre sem -Environment Homologacao e
  -ConfirmRestore. Bloqueia o identificador conhecido do projeto Supabase de
  produção NOVA TODDLE. A ligação de destino é lida de variável de ambiente,
  nunca passada na linha de comandos. Requer pg_restore/psql instalados.
  Não recupera Storage; os objetos precisam de procedimento separado.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Homologacao')]
  [string]$Environment,

  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
  [string]$BackupPath,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Fa-f0-9]{64}$')]
  [string]$ExpectedSha256,

  [Parameter(Mandatory = $true)]
  [switch]$ConfirmRestore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ConfirmRestore) {
  throw 'Bloqueado: é obrigatório indicar -ConfirmRestore após confirmar o ambiente de homologação.'
}

$databaseUrl = $env:NOVA_TODDLE_HOMOLOGATION_DATABASE_URL
if ([string]::IsNullOrWhiteSpace($databaseUrl)) {
  throw 'Defina NOVA_TODDLE_HOMOLOGATION_DATABASE_URL no ambiente seguro; não a grave no script nem no Git.'
}

# Bloqueio explícito do projeto de produção conhecido e dos nomes de ambiente de produção.
if ($databaseUrl -match 'rojyxfjaidyvtmsmefcf' -or $databaseUrl -match '(?i)(production|prod-db|prod.|:prod)') {
  throw 'Destino recusado: o identificador parece apontar para produção. Use apenas uma base isolada de homologação.'
}

$uri = $null
if (-not [Uri]::TryCreate($databaseUrl, [UriKind]::Absolute, [ref]$uri)) {
  throw 'A variável de destino não é uma URI PostgreSQL válida.'
}
if ($uri.Scheme -notin @('postgres', 'postgresql')) {
  throw 'Esquema de destino inválido: use uma URI postgres/postgresql.'
}

$hash = (Get-FileHash -LiteralPath $BackupPath -Algorithm SHA256).Hash
if ($hash -ne $ExpectedSha256.ToUpperInvariant()) {
  throw "Hash SHA-256 não corresponde ao manifesto. Restauro cancelado. Calculado: $hash"
}

$pgRestore = Get-Command pg_restore -ErrorAction SilentlyContinue
$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $pgRestore -and -not $psql) {
  throw 'Instale as ferramentas oficiais PostgreSQL (pg_restore e/ou psql) antes de continuar.'
}

$extension = [IO.Path]::GetExtension($BackupPath).ToLowerInvariant()
$format = if ($extension -in @('.dump', '.backup', '.custom')) { 'custom' } elseif ($extension -eq '.sql') { 'plain' } else { 'unknown' }
if ($format -eq 'unknown') {
  throw 'Formato não reconhecido. Use dump custom PostgreSQL (.dump/.backup/.custom) ou SQL simples (.sql).'
}
if ($format -eq 'custom' -and -not $pgRestore) { throw 'pg_restore não está disponível.' }
if ($format -eq 'plain' -and -not $psql) { throw 'psql não está disponível.' }

Write-Host 'Destino validado como homologação; hash SHA-256 verificado.'
Write-Host "Ficheiro: $([IO.Path]::GetFileName($BackupPath))"
Write-Host "SHA-256: $hash"
Write-Warning 'O restauro pode substituir dados no destino. Confirme que a base de homologação é descartável e está isolada de emails, SMS, pagamentos e integrações reais.'

if (-not $PSCmdlet.ShouldProcess($uri.Host, 'Restaurar backup PostgreSQL em homologação')) {
  Write-Host 'Simulação concluída; nenhum restauro foi executado.'
  return
}

# A credencial está apenas na variável de ambiente. Não imprimir a URI nem argumentos com segredos.
if ($format -eq 'custom') {
  & $pgRestore.Source --verbose --no-owner --no-privileges --clean --if-exists --dbname="$databaseUrl" "$BackupPath"
  if ($LASTEXITCODE -ne 0) { throw "pg_restore falhou com código $LASTEXITCODE." }
} else {
  & $psql.Source --set ON_ERROR_STOP=on --single-transaction --dbname="$databaseUrl" --file="$BackupPath"
  if ($LASTEXITCODE -ne 0) { throw "psql falhou com código $LASTEXITCODE." }
}

Write-Host 'Comando de restauro terminou sem erro. Isto não comprova recuperação total.'
Write-Host 'Obrigatório: validar tabelas, constraints, funções, RLS, contagens, Storage e testes de isolamento antes de declarar o restauro aprovado.'
