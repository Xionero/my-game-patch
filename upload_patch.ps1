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
Write-Host "   GAME PATCH DEPLOYER - CONFIRM MODE     " -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow

# --- Step 1: เตรียมไฟล์ ZIP (ตรวจความพร้อมในเครื่อง) ---
Write-Host "`n[1/4] Checking local files..." -ForegroundColor Cyan
if (-not (Test-Path $SourceZipFile)) { Die "$SourceZipFile not found!" }
if (Test-Path $NewZipFileName) { Remove-Item $NewZipFileName }
Rename-Item -Path $SourceZipFile -NewName $NewZipFileName
$fileSize = (Get-Item $NewZipFileName).Length / 1MB

# --- Step 2: [NEW] ยืนยันก่อนอัปโหลด (กันมือลั่น) ---
Write-Host "`n******************************************" -ForegroundColor Yellow
Write-Host "  READY TO UPDATE:" -ForegroundColor Yellow
Write-Host "  > Repo:    $Repo"
Write-Host "  > Version: $Version"
Write-Host "  > File:    $NewZipFileName"
Write-Host "  > Size:    $(("{0:N2}" -f $fileSize)) MB"
Write-Host "******************************************" -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Confirm to upload and sync everything? (type 'y' to proceed)"

if ($confirm -ne 'y') {
    Write-Host "`nAborted by user. Reverting file name..." -ForegroundColor Gray
    Rename-Item -Path $NewZipFileName -NewName $SourceZipFile
    pause; exit
}

# --- Step 3: อัปโหลดไฟล์ใหญ่ไป Releases ---
Write-Host "`n[2/4] Uploading Patch to GitHub Releases..." -ForegroundColor Cyan
try {
    gh release delete $Tag --repo $Repo --yes 2>$null
    git push --delete origin $Tag 2>$null
    gh release create $Tag ".\$NewZipFileName" --repo $Repo --title "Version $Version" --notes "Updated at $(Get-Date)"
} catch {
    Die "GitHub Release failed. Check internet/GH CLI."
}

# --- Step 4: อัปเดต Assets และ Sync ขึ้น GitHub ---
Write-Host "`n[3/4] Syncing Assets (Version/News/BG)..." -ForegroundColor Cyan
$patchUrl = "https://github.com/$Repo/releases/download/$Tag/$NewZipFileName"
$jsonContent = @"
{
  "latestVersion": "$Version",
  "patchUrl": "$patchUrl",
  "patchVersion": "$(Get-Date -UFormat %s)"
}
"@
Set-Content -Path $VersionJsonPath -Value $jsonContent

try {
    # 1. แอดเฉพาะไฟล์ที่ต้องการ (คลีนหน้าเว็บ)
    git add version.json news.txt
    $bgFiles = Get-ChildItem -Path "launcher_bg.*" -Include *.png, *.jpg, *.jpeg, *.gif
    foreach ($file in $bgFiles) { git add $file.Name }

    # 2. บันทึก
    git commit -m "Update: Patch v$Version assets" --allow-empty

    # 3. ซ่อนไฟล์ส่วนตัว (สคริปต์นี้/gitignore) ชั่วคราวเพื่อให้ Sync ผ่าน
    git stash push --keep-index --include-untracked -m "temp_stash"

    # 4. ดึงข้อมูลและผสาน
    git pull origin $Branch --rebase -X theirs

    # 5. ส่งขึ้น GitHub
    git push origin $Branch

    # 6. เอาไฟล์ที่ซ่อนไว้ออกมาคืน
    git stash pop 2>$null
    
    Write-Host "`n--- [ SUCCESS ] ---" -ForegroundColor Green
    Write-Host "Patch $Version is LIVE!"
    Write-Host "Everything is synced and GitHub is clean."
    
    Rename-Item -Path $NewZipFileName -NewName $SourceZipFile
} catch {
    git stash pop 2>$null
    Die "Git Sync Failed. Something went wrong during Push."
}

pause