<#
  SEDUC - Manutencao Automatica (PowerShell)
  Sequencia: 4 - A - B - 1

  Hospede este arquivo no GitHub (link RAW) e execute no PowerShell com:
    irm https://raw.githubusercontent.com/USUARIO/REPO/main/SEDUC_Manutencao_Auto_sem5.ps1 | iex

  NAO ha autoexclusao: ao rodar via 'irm | iex' o script roda da memoria.
#>

# >>> EDITE: cole aqui a URL RAW deste script no GitHub (usada na auto-elevacao) <<<
$ScriptUrl = 'https://raw.githubusercontent.com/USUARIO/REPO/main/SEDUC_Manutencao_Auto_sem5.ps1'

# --- Auto-elevacao para Administrador ---
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host '[INFO] Solicitando privilegios de Administrador...' -ForegroundColor Yellow
    try {
        $cmd = "irm '$ScriptUrl' | iex"
        Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$cmd
    } catch {
        Write-Host '[ERRO] Nao foi possivel elevar. Abra o PowerShell como Administrador e rode novamente.' -ForegroundColor Red
    }
    return
}

$ErrorActionPreference = 'SilentlyContinue'
$Protegidos = @('Publico','anos_iniciais','bluelab')
$Sistema    = @('Administrador','Administrator','Default','DefaultAccount','Guest','WDAGUtilityAccount','Public','defaultuser0')
$NomeAtual  = $env:USERNAME

Clear-Host
Write-Host '============================================================'
Write-Host '  SEDUC - MANUTENCAO AUTOMATICA (PowerShell)'
Write-Host '  Sequencia: 4 - A - B - 1'
Write-Host '============================================================'
Write-Host ''
Write-Host '[ATENCAO] A etapa 1 REMOVE perfis de usuario (contas protegidas' -ForegroundColor Yellow
Write-Host '          e a conta atual sao preservadas). Ctrl+C para cancelar.' -ForegroundColor Yellow
Start-Sleep -Seconds 8

# ================= [1/4] LIMPAR PERFIS DE USUARIO =================
Write-Host ''
Write-Host '====== [1/4] LIMPAR PERFIS DE USUARIO ======' -ForegroundColor Cyan
$removidos = 0; $falhas = 0
$perfis = Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special }
foreach ($p in $perfis) {
    $path = $p.LocalPath
    if (-not $path) { continue }
    $nome = Split-Path $path -Leaf
    if ($Sistema   -contains $nome) { continue }
    if ($Protegidos -contains $nome) { continue }
    if ($nome -ieq $NomeAtual) { continue }
    if ($nome -like '*.AzureAD') { continue }
    if ($p.Loaded) { continue }
    Write-Host "[REMOVENDO] $nome ..."
    try { Remove-CimInstance -InputObject $p -ErrorAction Stop } catch {}
    cmd /c "net user `"$nome`" /delete" > $null 2>&1
    Remove-LocalUser -Name $nome -ErrorAction SilentlyContinue
    if (Test-Path $path) { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $path) { $falhas++; Write-Host "[AVISO] $nome nao removido completamente (pasta em uso)." }
    else { $removidos++; Write-Host "[OK] $nome removido." }
}
Write-Host '[INFO] Removendo perfis fantasma presos na tela de login...'
Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special -and -not (Test-Path $_.LocalPath) } | Remove-CimInstance -ErrorAction SilentlyContinue
$pl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
Get-ChildItem $pl | Get-ItemProperty | Where-Object { $_.ProfileImagePath -and -not (Test-Path $_.ProfileImagePath) } | ForEach-Object { Remove-Item $_.PSPath -Force -Recurse -ErrorAction SilentlyContinue }
Write-Host "[OK] Perfis removidos: $removidos | Falhas: $falhas"

# ================= [2/4] SECPOL - ultimo usuario =================
Write-Host ''
Write-Host '====== [2/4] SECPOL - Exibir ultimo usuario no login ======' -ForegroundColor Cyan
$sys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
New-ItemProperty -Path $sys -Name 'DontDisplayLastUserName' -Value 0 -PropertyType DWord -Force | Out-Null
Write-Host '[OK] Politica desabilitada: o ultimo usuario sera exibido no login.'

# ================= [3/4] MELHOR DESEMPENHO =================
Write-Host ''
Write-Host '====== [3/4] MELHOR DESEMPENHO - Energia + RAM ======' -ForegroundColor Cyan
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
Write-Host '[OK] Plano Alto Desempenho ativado.'
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
$ult = (powercfg -list | Select-String 'Ultimate' | ForEach-Object { ($_ -split '\s+' | Where-Object { $_ -match '^[0-9a-f-]{36}$' }) } | Select-Object -First 1)
if ($ult) { powercfg -setactive $ult | Out-Null; Write-Host '[OK] Ultimate Performance ativado.' }
else { Write-Host '[INFO] Ultimate Performance indisponivel. Mantido Alto Desempenho.' }
$sig = '[DllImport("psapi.dll")] public static extern bool EmptyWorkingSet(IntPtr h);'
$mm = Add-Type -MemberDefinition $sig -Name 'Mm' -Namespace 'Win' -PassThru
$antes = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
Get-Process | ForEach-Object { try { $mm::EmptyWorkingSet($_.Handle) | Out-Null } catch {} }
Start-Sleep -Milliseconds 600
$depois = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
Write-Host ('[OK] RAM otimizada. Livre antes: {0} MB | depois: {1} MB | liberado: {2} MB' -f [math]::Round($antes/1024),[math]::Round($depois/1024),[math]::Round(($depois-$antes)/1024))

# ================= [4/4] LIMPAR TEMPORARIOS =================
Write-Host ''
Write-Host '====== [4/4] LIMPAR ARQUIVOS TEMPORARIOS ======' -ForegroundColor Cyan
$alvos = @(
    "$env:TEMP",
    "$env:LOCALAPPDATA\Temp",
    "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\ThumbCacheToDelete",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
    "$env:APPDATA\Microsoft\Windows\Recent",
    "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations",
    "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations",
    "C:\Windows\Temp",
    "C:\Windows\Prefetch"
)
foreach ($a in $alvos) {
    if (Test-Path $a) {
        Write-Host "[LIMPANDO] $a"
        Get-ChildItem -LiteralPath $a -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
Write-Host '[OK] Arquivos temporarios limpos.'

# ================= FINAL =================
Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host '  MANUTENCAO AUTOMATICA CONCLUIDA!' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host '[IMPORTANTE] Reinicie o PC para que as mudancas na tela de'
Write-Host '             login (perfis e politica) tenham efeito.'
