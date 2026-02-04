# ======================== CONFIGURATION ========================
$Repo = "Xionero/my-game-patch"
$SourceZipFile = "Meltopia.zip" 
$Version = "1.0.0" 
$Tag = "v$Version" 
$NewZipFileName = "Meltopia_Patch.zip"
$VersionJsonPath = Join-Path $PSScriptRoot "version.json"
$Branch = "main" 
# ===============================================================

function Die ($msg) {
    Write-Host "`n!!! ERROR: $msg !!!" -ForegroundColor Red
    if (Test-Path $NewZipFileName) { Rename-Item -Path $NewZipFileName -NewName $SourceZipFile -ErrorAction SilentlyContinue }
    pause; exit
}

Clear-Host
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "   GAME PATCH DEPLOYER - FIXED LARGE FILE " -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow

# --- Step 0: สร้าง .gitignore เพื่อกันไฟล์ ZIP หลุดเข้า Git ---
Write-Host "`n[0/6] Configuring Git Ignore..." -ForegroundColor Cyan
if (-not (Test-Path ".gitignore")) { New-Item ".gitignore" -Type File -Force | Out-Null }
$ignoreContent = Get-Content ".gitignore" -ErrorAction SilentlyContinue
if ($ignoreContent -notcontains "*.zip") {
    Add-Content -Path ".gitignore" -Value "`n*.zip"
    Write-Host "   > Added *.zip to .gitignore (Safety first!)" -ForegroundColor Green
}

# --- Step 1: เตรียมไฟล์ ZIP ---
Write-Host "`n[1/6] Preparing zip file..." -ForegroundColor Cyan
if (-not (Test-Path $SourceZipFile)) { Die "$SourceZipFile not found!" }
if (Test-Path $NewZipFileName) { Remove-Item $NewZipFileName }
Rename-Item -Path $SourceZipFile -NewName $NewZipFileName

# --- Step 2: ยืนยันข้อมูล ---
Write-Host "`n[2/6] Confirmation" -ForegroundColor Cyan
Write-Host "   > Version: $Version"
Write-Host "   > File:    $NewZipFileName (Size: $(("{0:N2} MB" -f ((Get-Item $NewZipFileName).Length / 1MB))))"
if ((Read-Host "   > Proceed? (y/n)") -ne 'y') { 
    Rename-Item -Path $NewZipFileName -NewName $SourceZipFile
    exit 
}

# --- Step 3: จัดการ GitHub Release (ไฟล์ใหญ่จะไปอยู่ที่นี่) ---
Write-Host "`n[3/6] Uploading to GitHub Release (Large File OK)..." -ForegroundColor Cyan
try {
    gh release delete $Tag --repo $Repo --yes 2>$null
    git push --delete origin $Tag 2>$null
    
    # อัปโหลดไฟล์ Zip เข้า Release (ตรงนี้รับได้ถึง 2GB)
    gh release create $Tag ".\$NewZipFileName" --repo $Repo --title "Version $Version" --notes "Patch updated at $(Get-Date)"
} catch {
    Die "Failed to upload Release. Check internet connection."
}

# --- Step 4: อัปเดต version.json ---
Write-Host "`n[4/6] Updating version.json..." -ForegroundColor Cyan
$patchUrl = "https://github.com/$Repo/releases/download/$Tag/$NewZipFileName"
$timestamp = (Get-Date -UFormat %s)
$jsonContent = @"
{
  "latestVersion": "$Version",
  "patchUrl": "$patchUrl",
  "patchVersion": "$timestamp"
}
"@
Set-Content -Path $VersionJsonPath -Value $jsonContent

# --- Step 5: จัดเตรียมไฟล์เข้า Git (Code & Images Only) ---
Write-Host "`n[5/6] Staging source files..." -ForegroundColor Cyan
try {
    # บังคับลบไฟล์ zip ออกจากสารบบ Git (เผื่อหลุดเข้าไป)
    git rm --cached *.zip 2>$null 

    # Add ทุกไฟล์ (แต่ .gitignore จะกันไฟล์ zip ออกให้เอง)
    git add .
    
    $status = git status --porcelain
    if ($status) {
        Write-Host "   > Found changes. Preparing to commit." -ForegroundColor Green
    } else {
        Write-Host "   > No source code changes found." -ForegroundColor Gray
    }
} catch {
    Die "Git add failed."
}

# --- Step 6: ส่งขึ้น GitHub (Git Push) ---
Write-Host "`n[6/6] Syncing Source Code to GitHub..." -ForegroundColor Cyan
try {
    git commit -m "Update: Patch v$Version details" --allow-empty
    
    # ดึงไฟล์ล่าสุดจาก Server มาผสาน (โดยยึดไฟล์ในเครื่องเป็นหลัก)
    git pull origin $Branch --rebase -X theirs
    
    # ส่งขึ้น Server (รอบนี้จะไม่มีไฟล์ Zip ติดไปด้วย)
    git push origin $Branch

    Write-Host "`n--- [ SUCCESS ] ---" -ForegroundColor Green
    Write-Host "Patch $Version is LIVE!" 
    Write-Host " - Zip File: Uploaded to Releases (Success)"
    Write-Host " - Source Code: Pushed to Git (Success)"
    
    Rename-Item -Path $NewZipFileName -NewName $SourceZipFile
} catch {
    Die "Git Push Failed. Please check the error above."
}

pause