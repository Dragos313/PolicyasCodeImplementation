Write-Host "`n--- Pornire Pipeline Securitate ---" -ForegroundColor Cyan

# 1. PREGATIRE PLAN
Write-Host "[1/3] Pregatire plan Terraform..." -NoNewline
Remove-Item tfplan, tfplan.json -ErrorAction SilentlyContinue
terraform plan -out=tfplan > $null
terraform show -json tfplan > tfplan.json
Write-Host " OK" -ForegroundColor Green

# 2. AUDITARE OPA
Write-Host "[2/3] Auditare OPA in curs..."
$opaRaw = opa eval -i tfplan.json -d politici.rego "data.azure.securitate" --format json | ConvertFrom-Json

if (-not $opaRaw.result) {
    Write-Host "`n[EROARE] OPA nu a gasit pachetul de politici! Verificati pachetul in REGO." -ForegroundColor Red
    exit 1
}

$date = $opaRaw.result[0].expressions[0].value
$vulnerabilitati = @($date.vulnerabilitati) | Where-Object { $_ -ne $null }
$count = ($vulnerabilitati | Measure-Object).Count

# 3. MODUL SELF-HEALING
if ($count -gt 0) {
    Write-Host "`nS-au detectat $count vulnerabilitati critice!" -ForegroundColor Red
    
    foreach ($msg in $vulnerabilitati) {
        Write-Host "  [-] $msg" -ForegroundColor Yellow
    }
    
    Write-Host ""
    $raspuns = Read-Host "[SISTEM] Activati remedierea automata (Self-Healing)? (Y/N)"

    if ($raspuns -eq "Y") {
        Write-Host "`n[REMEDIERE] Se aplica patch-uri automate pe codul sursa...`n" -ForegroundColor Cyan

        # Patch 1: SSH Port 22
        if ($vulnerabilitati -like "*Portul 22*") {
            Write-Host "Aplicare patch: Limitare acces la IP Management..." -NoNewline
            (Get-Content main.tf) -replace 'source_address_prefix\s*=\s*"\*"', 'source_address_prefix = "82.210.140.50/32"' | Set-Content main.tf
            Write-Host " [REZOLVAT]" -ForegroundColor Green
            Write-Host "" 
        }

        # Patch 2: Locatie GDPR
        if ($vulnerabilitati -like "*Locatie*") {
            Write-Host "Aplicare patch: Mutare automata resurse in Sweden Central..." -NoNewline
            (Get-Content main.tf) -replace 'location\s*=\s*".*?"', 'location = "swedencentral"' | Set-Content main.tf
            Write-Host " [REZOLVAT]" -ForegroundColor Green
            Write-Host ""
        }

        # Patch 3: Key Vault Public Access
        if ($vulnerabilitati -like "*Key Vault*") {
            Write-Host "Aplicare patch: Dezactivare acces public la secret..." -NoNewline
            (Get-Content main.tf) -replace 'public_network_access_enabled\s*=\s*true', 'public_network_access_enabled = false' | Set-Content main.tf
            Write-Host " [REZOLVAT]" -ForegroundColor Green
            Write-Host ""
        }

        # Patch 4: Tag-uri Obligatorii
        if ($vulnerabilitati -like "*tag-urile*") {
            Write-Host "Aplicare patch: Injectare tag-uri (Departament/CostCenter)..." -NoNewline
            $tf = Get-Content main.tf -Raw
            if ($tf -match 'azurerm_key_vault" "kv"[\s\S]*?tags\s*=\s*\{') {
                if ($tf -notmatch 'kv"[\s\S]*?Departament\s*=') {
                    $NL = [Environment]::NewLine
                    $tinta = 'azurerm_key_vault" "kv"([\s\S]*?)tags\s*=\s*\{'
                    $inlocuitor = 'azurerm_key_vault" "kv"${1}tags = {' + $NL + '    Departament = "IT-Securitate"' + $NL + '    CostCenter  = "CC-1234"'
                    $tf = $tf -replace $tinta, $inlocuitor
                    $tf | Set-Content main.tf
                }
            }
            Write-Host " [REZOLVAT]" -ForegroundColor Green
            Write-Host ""
        }

        Write-Host "[REUSITA] Toate patch-urile au fost aplicate local (Shift-Left)." -ForegroundColor Cyan
        Write-Host "[INFO] Re-rulati scriptul pentru validarea finala a conformitatii."
        exit 0
    } else {
        Write-Host "`nDEPLOYMENT BLOCAT! Executia a fost oprita de utilizator.`n" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n[SUCCES] Verificare reusita! Infrastructura este sigura." -ForegroundColor Green
    exit 0
}