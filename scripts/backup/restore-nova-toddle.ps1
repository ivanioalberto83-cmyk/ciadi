#requires -Version 7.0
<#
.SYNOPSIS
  Restauro controlado de uma cópia PostgreSQL NOVA TODDLE em homologação.
.DESCRIPTION
  Não corre sem -Environment Homologacao e -ConfirmRestore. Exige allowlist
  explícita do host de destino, verifica SHA-256 e bloqueia o projeto de
  produção conhecido. Requer pg_restore/psql. Não restaura objetos Storage.
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
  throw 'Bloqueado: indique -ConfirmRestore apenas depois de confirmar o ambiente de homologação.'
}

$databaseUrl = $env:NOVA_TODDLE_HOMOLOGATION_DATABASE_URL
$allowedHosts = $env:NOVA_TODDLE_HOMOLOGATION_ALLOWED_HOSTS
if ([string]::IsNullOrWhiteSpace($databaseUrl) -or [string]::IsNullOrWhiteSpace($allowedHosts)) {
  throw 'Defina, no ambiente seguro, NOVA_TODDLE_HOMOLOGATION_DATABASE_URL e NOVA_TODDLE_HOMOLOGATION_ALLOWED_HOSTS.'
}

$uri = $null
if (-not [Uri]::TryCreate($databaseUrl, [UriKind]::Absolute, [ref]$uri)) {
  throw 'A variável de destino não é uma URI PostgreSQL válida.'
}
if ($uri.Scheme -notin @('postgres', 'postgresql')) {
  throw 'Esquema inválido: use uma URI postgres/postgresql.'
}
if ($uri.Host -match 'rojyxfjaidyvtmsmefcf' -or $databaseUrl -match '(?i)(production|prod-db|prod\.|:prod\b)') {
  throw 'Destino recusado: parece apontar para produção.'
}

$hostAllowlist = @($allowedHosts.Split(',') | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
if ($uri.Host.ToLowerInvariant() -notin $hostAllowlist) {
  throw 'Destino recusado: o host não consta na allowlist de homologação.'
}

$hash = (Get-FileHash -LiteralPath $BackupPath -Algorithm SHA256).Hash
if ($hash -ne $ExpectedSha256.ToUpperInvariant()) {
  throw "Hash SHA-256 não corresponde ao manifesto. Restauro cancelado. Calculado: $hash"
}

$pgRestore = Get-Command pg_restore -ErrorAction SilentlyContinue
$psql = Get-Command psql -ErrorAction SilentlyContinue
$extension = [IO.Path]::GetExtension($BackupPath).ToLowerInvariant()
$format = if ($extension -in @('.dump', '.backup', '.custom')) { 'custom' } elseif ($extension -eq '.sql') { 'plain' } else { 'unknown' }
if ($format -eq 'unknown') { throw 'Formato não reconhecido. Use .dump/.backup/.custom ou .sql.' }
if ($format -eq 'custom' -and -not $pgRestore) { throw 'pg_restore não está disponível.' }
if ($format -eq 'plain' -and -not $psql) { throw 'psql não está disponível.' }

Write-Host 'Destino homologação validado e hash SHA-256 confirmado.'
Write-Host "Ficheiro: $([IO.Path]::GetFileName($BackupPath))"
Write-Host "SHA-256: $hash"
Write-Warning 'O restauro pode substituir dados no destino. Confirme que a base é isolada e que integrações reais estão desativadas.'

if (-not $PSCmdlet.ShouldProcess($uri.Host, 'Restaurar backup PostgreSQL em homologação')) {
  Write-Host 'Simulação concluída; nenhum restauro foi executado.'
  return
}

if ($format -eq 'custom') {
  & $pgRestore.Source --verbose --no-owner --no-privileges --clean --if-exists --dbname="$databaseUrl" "$BackupPath"
  if ($LASTEXITCODE -ne 0) { throw "pg_restore falhou com código $LASTEXITCODE." }
} else {
  & $psql.Source --set ON_ERROR_STOP=on --single-transaction --dbname="$databaseUrl" --file="$BackupPath"
  if ($LASTEXITCODE -ne 0) { throw "psql falhou com código $LASTEXITCODE." }
}

Write-Host 'Comando de restauro terminou sem erro; a recuperação ainda não está certificada.'
Write-Host 'Validar tabelas, constraints, funções, triggers, RLS, contagens, Storage e testes de isolamento antes de aprovar.'
