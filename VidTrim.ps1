$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

function Pause-Exit {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message
    Read-Host "Press Enter to close"
    exit
}

function Confirm-YesNo {
    param([string]$Prompt)
    $answer = Read-Host "$Prompt ""Y/N"" (Enter = Y)"
    return ($answer -eq '' -or $answer -match '^[Yy]')
}

function Get-SecondsToCut {
    while ($true) {
        $raw = Read-Host "How many seconds should I cut from the beginning of the video(s)? (Enter = 60)"
        if ($raw.Trim() -eq '') { return 60 }
        $n = 0
        if ([int]::TryParse($raw.Trim(), [ref]$n) -and $n -gt 0) { return $n }
        Write-Host "  Please type a whole number bigger than 0, or just press Enter for 60." -ForegroundColor Yellow
    }
}

function Get-Extension {
    while ($true) {
        $raw = Read-Host "Which file extension should I process? (Enter = .mp4)"
        $ext = $raw.Trim().ToLower()
        if ($ext -eq '') { return '.mp4' }
        if (-not $ext.StartsWith('.')) { $ext = ".$ext" }
        if ($ext -match '^\.[a-z0-9]{1,8}$') { return $ext }
        Write-Host "  That doesn't look like a file extension. Try something like .mp4" -ForegroundColor Yellow
    }
}

function Show-TrimBar {
    param([double]$Percent)
    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }
    $filled = [int][Math]::Round($Percent / 4)
    $bar = ('=' * $filled).PadRight(25, '.')
    Write-Host ("`r  [" + $bar + "] " + [int]$Percent + "% ") -ForegroundColor Green -NoNewline
}

function Format-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N1} MB" -f ($Bytes / 1MB)) }
    return ("{0:N0} KB" -f ($Bytes / 1KB))
}

Write-Host ""
Write-Host "==============="
Write-Host "   VidTrim"
Write-Host "==============="
Write-Host ""
Write-Host "Trim seconds off the beginning of your videos."
Write-Host ""

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Pause-Exit "ffmpeg was not found on this computer. Please install it first (for example: winget install ffmpeg). Nothing was changed."
}

$mode = Read-Host "Will you trim (F) a single video file, or (D) a whole folder of videos? (Enter = F)"
$pickFile = -not ($mode -match '^[Dd]')

$videos = @()
if ($pickFile) {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Pick the video you want to trim"
    $dialog.Filter = "Video files|*.mp4;*.mov;*.avi;*.mkv;*.wmv;*.m4v;*.mpg;*.mpeg;*.mts;*.m2ts|All files|*.*"
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Pause-Exit "No file was picked. Closing - nothing was changed."
    }
    $videos = @(Get-Item -LiteralPath $dialog.FileName)
}
else {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Pick the folder of videos you want to trim"
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Pause-Exit "No folder was picked. Closing - nothing was changed."
    }
    $folderItem = Get-Item -LiteralPath $dialog.SelectedPath
    $ext = Get-Extension
    $videos = @(Get-ChildItem -LiteralPath $folderItem.FullName -Filter "*$ext" -File | Sort-Object Name)
    if ($videos.Count -eq 0) {
        Pause-Exit "No $ext videos were found in '$($folderItem.FullName)'. Nothing was changed."
    }
}

$seconds = Get-SecondsToCut

Write-Host ""
if ($pickFile) {
    Write-Host "We are going to cut '$($videos[0].Name)' by [$seconds] seconds, are you sure?"
}
else {
    Write-Host "Videos found in '$($videos[0].DirectoryName)' ($($videos.Count) total):"
    $videos | ForEach-Object { Write-Host "   $($_.Name)" }
    Write-Host ""
    Write-Host "All of the above videos will be cut by [$seconds] seconds. Are you sure???"
}
if (-not (Confirm-YesNo "Type Y to continue, or N to cancel")) {
    Pause-Exit "Cancelled - no videos were changed."
}

Write-Host ""
$keepOriginals = Confirm-YesNo "Would you like to keep copies of the videos before I edit them? It's strongly recommended that you do."

$totalBytes = ($videos | Measure-Object -Property Length -Sum).Sum
$freeBytes = $videos[0].PSDrive.Free

if ($keepOriginals -and $freeBytes -lt $totalBytes) {
    Pause-Exit ("I can't do it - there is not enough disk space to keep the originals. Only {0:N2} GB free, but the originals take {1:N2} GB. Please make smaller folders (fewer videos at a time) and try again." -f ($freeBytes / 1GB), ($totalBytes / 1GB))
}

$origSizes = @{}
$videos | ForEach-Object { $origSizes[$_.Name] = $_.Length }

$backupDir = $null
$backupFile = $null
if ($keepOriginals) {
    if ($pickFile) {
        $backupFile = $videos[0].FullName + '~'
        Move-Item -LiteralPath $videos[0].FullName -Destination $backupFile
    }
    else {
        $backupDir = Join-Path $videos[0].DirectoryName 'Original_Vids'
        New-Item -ItemType Directory -Path $backupDir | Out-Null
        $videos | ForEach-Object { Move-Item -LiteralPath $_.FullName -Destination $backupDir }
    }
}

$failures = @()
$total = $videos.Count
$attempt = 0
foreach ($v in $videos) {
    $attempt++
    $inputPath = if ($pickFile) { $backupFile } elseif ($keepOriginals) { Join-Path $backupDir $v.Name } else { $v.FullName }
    $tmpOut = Join-Path $v.DirectoryName ($v.BaseName + '.trim-tmp' + $v.Extension)
    Write-Host ""
    Write-Host "  Trimming $($attempt)/$($total): $($v.Name)"
    $success = $false
    $ffErr = $null
    $durUs = 0
    try {
        $ErrorActionPreference = 'Continue'
        try {
            $probe = & ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 $inputPath 2>$null
            if ("$probe".Trim() -match '^(\d+(\.\d+)?)$') { $durUs = [long]((([double]$Matches[1]) - $seconds) * 1000000) }
            if ($durUs -lt 0) { $durUs = 0 }
            $ffErr = & ffmpeg -y -hide_banner -loglevel error -ss $seconds -i $inputPath -c copy -nostats -progress pipe:1 $tmpOut 2>&1 | ForEach-Object {
                $line = "$_"
                if ($durUs -gt 0 -and $line -match '^out_time_us=(-?\d+)') {
                    $val = [long]$Matches[1]
                    if ($val -ge 0) { Show-TrimBar (100 * $val / $durUs) }
                }
                else {
                    $_
                }
            }
        }
        finally {
            $ErrorActionPreference = 'Stop'
        }
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $tmpOut) -and ((Get-Item -LiteralPath $tmpOut).Length -gt 0)) {
            Move-Item -LiteralPath $tmpOut -Destination $v.FullName -Force
            $success = $true
        }
    }
    catch {
        $ffErr = @($_.Exception.Message)
    }
    if ($success) {
        if ($durUs -gt 0) { Show-TrimBar 100 }
        Write-Host " done" -ForegroundColor Green
    }
    else {
        Write-Host ""
        if (Test-Path -LiteralPath $tmpOut) { Remove-Item -LiteralPath $tmpOut -Force }
        $errText = ''
        if ($ffErr) { $errText = (($ffErr | Select-Object -Last 1) | Out-String).Trim() }
        $failures += $v.Name
        Write-Host "  Could not trim this one: $errText" -ForegroundColor Yellow
        if ($keepOriginals) {
            if ($pickFile) {
                Move-Item -LiteralPath $backupFile -Destination $v.FullName -Force
                $backupFile = $null
            }
            else {
                Move-Item -LiteralPath (Join-Path $backupDir $v.Name) -Destination $v.FullName -Force
            }
        }
    }
}

if ($keepOriginals -and (-not $pickFile) -and ($backupDir -ne $null) -and ((Get-ChildItem -LiteralPath $backupDir -File).Count -eq 0)) {
    Remove-Item -LiteralPath $backupDir -Force
    $backupDir = $null
}

$savedBytes = 0
foreach ($v in $videos) {
    if ($failures -notcontains $v.Name -and (Test-Path -LiteralPath $v.FullName)) {
        $delta = $origSizes[$v.Name] - (Get-Item -LiteralPath $v.FullName).Length
        if ($delta -gt 0) { $savedBytes += $delta }
    }
}

$trimmedCount = $videos.Count - $failures.Count

Write-Host ""
Write-Host "==============================================="
Write-Host "   ALL DONE - trimmed $trimmedCount of $($videos.Count) video(s) by $seconds second(s)"
Write-Host "==============================================="
if (-not $keepOriginals -and $savedBytes -gt 0) {
    Write-Host "   You saved $(Format-Size $savedBytes) of disk space!"
}
foreach ($f in $failures) {
    Write-Host "  Could not trim: $f -- original left untouched" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Please open your new videos and make sure they are what you want."
Write-Host ""

if ($keepOriginals -and ($backupDir -or $backupFile)) {
    $answer = Read-Host "If you check the videos and you are certain that the conversion went as planned, type 'DELETE' and I will move the originals into the recycle bin (Enter keeps them)"
    if ($answer.Trim() -match '^DELETE$') {
        try {
            if ($pickFile) {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($backupFile, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
            }
            else {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($backupDir, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
            }
            Write-Host ""
            Write-Host "Done - the originals are now in the Recycle Bin."
            if ($savedBytes -gt 0) {
                Write-Host "You saved $(Format-Size $savedBytes) of disk space! (Space frees up fully when you empty the Recycle Bin.)"
            }
        }
        catch {
            Write-Host "Could not move the originals to the Recycle Bin: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Okay - the originals are kept where they were, so nothing is saved yet."
    }
}
else {
    if ($failures.Count -eq $videos.Count) {
        Write-Host "No videos could be trimmed, so your originals were left untouched."
    }
}

Write-Host ""
Read-Host "Press Enter to close"
