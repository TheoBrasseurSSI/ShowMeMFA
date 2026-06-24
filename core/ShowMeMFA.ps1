Clear-Host
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$WarningPreference = "SilentlyContinue"

$banner = @"
  #####                       #     #        #     # #######    #    
 #     # #    #  ####  #    # ##   ## ###### ##   ## #         # #   
 #       #    # #    # #    # # # # # #      # # # # #        #   #  
  #####  ###### #    # #    # #  #  # #####  #  #  # #####   #     # 
       # #    # #    # # ## # #     # #      #     # #       ####### 
 #     # #    # #    # ##  ## #     # #      #     # #       #     # 
  #####  #    #  ####  #    # #     # ###### #     # #       #     #                                                                     
"@

Write-Host $banner -ForegroundColor Cyan
Write-Host "[Azure AD - Audit des methodes MFA enregistrees]" -ForegroundColor DarkGray
Write-Host ""
 
# =========================
# Preparation environnement
# =========================
Write-Host "Preparation de l'environnement PowerShell..." -ForegroundColor Yellow
 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "Installation du fournisseur NuGet..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}
 
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Write-Host "Installation du module Microsoft.Graph..."
    Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
}
 
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Identity.SignIns
 
# =========================
# Connexion
# =========================
Write-Host "Connexion a Microsoft Graph..." -ForegroundColor Yellow
 
try {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
 
    Connect-MgGraph `
        -Scopes "UserAuthenticationMethod.ReadWrite.All", "User.Read.All" `
        -ContextScope Process `
        -UseDeviceAuthentication `
        -ErrorAction Stop
 
    $ctx = Get-MgContext
    Write-Host ""
    Write-Host "===== SESSION CONNECTEE =====" -ForegroundColor Cyan
    Write-Host "Compte  : $($ctx.Account)" -ForegroundColor Green
    Write-Host "Tenant  : $($ctx.TenantId)" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host "Erreur : impossible de se connecter. Verifiez vos droits." -ForegroundColor Red
    Write-Host ""
    Write-Host "Appuyez sur ESPACE pour quitter"
    do { $key = [System.Console]::ReadKey($true) } until ($key.Key -eq "Spacebar")
    exit
}
 
# =========================
# Initialisation log
# =========================
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir    = Join-Path $scriptDir "..\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
$logFile = Join-Path $logDir "ShowMeMFA_$timestamp.log"
 
function Write-Log {
    param([string]$message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $message"
    Add-Content -Path $script:logFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}
 
Write-Log "=== Nouvelle session ShowMeMFA ==="
Write-Log "Compte admin : $($env:USERNAME)"
 
# =========================
# Fonction : traduire le type de methode MFA
# =========================
function Get-NomMethode {
    param($methode)
 
    switch ($methode.AdditionalProperties["@odata.type"]) {
        "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
            $device = $methode.AdditionalProperties["displayName"]
            if ($device) { return "Microsoft Authenticator - $device" }
            return "Microsoft Authenticator"
        }
        "#microsoft.graph.phoneAuthenticationMethod" {
            $num = $methode.AdditionalProperties["phoneNumber"]
            return "Telephone (SMS/Appel) - $num"
        }
        "#microsoft.graph.fido2AuthenticationMethod" {
            $model = $methode.AdditionalProperties["model"]
            return "Cle de securite FIDO2 - $model"
        }
        "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" { return "Windows Hello for Business" }
        "#microsoft.graph.passwordAuthenticationMethod" { return "Mot de passe" }
        "#microsoft.graph.softwareOathAuthenticationMethod" { return "Application OTP logicielle" }
        "#microsoft.graph.temporaryAccessPassAuthenticationMethod" { return "Pass d'acces temporaire (TAP)" }
        "#microsoft.graph.emailAuthenticationMethod" { return "Email" }
        default { return "Methode inconnue ($($methode.AdditionalProperties["@odata.type"]))" }
    }
}
 
# =========================
# Boucle menu principal
# =========================
while ($true) {
 
    Write-Host ""
    $upn = Read-Host "Entrez l'adresse email de l'utilisateur (ou Q pour quitter)"
    if ($upn -eq "Q" -or $upn -eq "q") {
        break
    }
    if ([string]::IsNullOrWhiteSpace($upn)) {
        Write-Host "Adresse non valide." -ForegroundColor Red
        continue
    }
 
    Write-Log "Audit MFA pour : $upn"
    Write-Host "Recherche des methodes MFA pour $upn" -NoNewline
 
    try {
        $user = Get-MgUser -UserId $upn -ErrorAction Stop
    }
    catch {
        Write-Host ""
        Write-Host "Erreur : utilisateur introuvable." -ForegroundColor Red
        Write-Log "ERREUR : utilisateur introuvable - $upn"
        continue
    }
 
    try {
        $methodes = Get-MgUserAuthenticationMethod -UserId $user.Id -ErrorAction Stop
    }
    catch {
        Write-Host ""
        Write-Host "Erreur lors de la recuperation des methodes MFA." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
        Write-Log "ERREUR : $($_.Exception.Message)"
        continue
    }
 
    Write-Host ""
 
    if (-not $methodes -or $methodes.Count -eq 0) {
        Write-Host "Aucune methode d'authentification trouvee pour cet utilisateur." -ForegroundColor Yellow
        Write-Log "Aucune methode MFA trouvee pour $upn"
        continue
    }
 
    Write-Host "Methodes enregistrees : $($methodes.Count)" -ForegroundColor Cyan
    Write-Host ""
 
    $i = 1
    foreach ($m in $methodes) {
        $nom = Get-NomMethode -methode $m
        $couleur = if ($nom -like "*Mot de passe*") { "DarkGray" } else { "White" }
        Write-Host "  [$i] $nom" -ForegroundColor $couleur
        Write-Log "Methode $i : $nom"
        $i++
    }
 
    Write-Host ""
    Write-Host "Conseil : si une methode inconnue ou un numero de telephone non reconnu" -ForegroundColor DarkGray
    Write-Host "apparait, cela peut signaler une persistance ajoutee par un attaquant." -ForegroundColor DarkGray
 
    Write-Host ""
    $continuer = Read-Host "Verifier un autre utilisateur ? (OUI pour continuer, toute autre valeur pour quitter)"
    if ($continuer -ne "OUI") { break }
}
 
Write-Log "=== Fin de session ==="
Write-Host ""
Write-Host "Appuyez sur ESPACE pour quitter"
 
do {
    $key = [System.Console]::ReadKey($true)
} until ($key.Key -eq "Spacebar")
 
exit