# Don't change these
$currentVersion = "1.0.0"
$currentScriptPath = $MyInvocation.MyCommand.Path
$API_URL = "https://api.github.com/repos/YimMenu/YimMenu/releases/latest"
$DLL_URL = "https://github.com/YimMenu/YimMenu/releases/download/nightly/YimMenu.dll"

function YimAutoUpdater {
    function checkForScriptUpdates {
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Harmless05/Yim-AutoUpdater/releases/latest"
        $latestVersion = $latestRelease.tag_name
        if ($latestVersion -gt $currentVersion) {
            Write-Host "New version available: $latestVersion" -ForegroundColor Green
            $downloadUrl = $latestRelease.assets[0].browser_download_url
            $updateChoice = Read-Host "Do you want to update now? (yes/no)"
            if ($updateChoice -eq "yes" -or $updateChoice -eq "y") {
                Invoke-WebRequest -Uri $downloadUrl -OutFile $currentScriptPath
                Write-Host "New version downloaded, script updated. Restarting..." -ForegroundColor Green
                & $currentScriptPath
                exit
            }
            else {
                Write-Host "Update cancelled" -ForegroundColor Red
                Write-Host "Continuing with the current version..."
            }
        } else {
            Write-Host "You are running the latest version of Yim-AutoUpdater :D`n" -ForegroundColor Green
        }
    }
    checkForScriptUpdates

    function checkForDllUpdates {
        # Fetch the API response
        $response = Invoke-RestMethod -Uri $API_URL
        $bodyText = $response.body
        # Get Web DLL hash
        $sha256Web = [regex]::match($bodyText, '([a-fA-F\d]{64})').Groups[1].Value
        # Get Local DLL hash
        $sha256Local = (Get-FileHash -Path 'YimMenu.dll' -Algorithm SHA256 | ForEach-Object Hash).ToLower()

        # Compare the two hashes
        if ($sha256Web -ne $sha256Local) {
            Write-Host "A newer version of YimMenu is available!`n" -ForegroundColor Green
            Write-Host "Local hash: $sha256Local"
            Write-Host "Web hash: $sha256Web`n"
            $choice = Read-Host "`nDo you want to update YimMenu? (y/N)"
            if ($choice -eq "yes" -or $choice -eq "y" -or $choice -eq "Y" -or $choice -eq "Yes") {
                Write-Host "`nDeleting the old version..." -ForegroundColor Yellow
                Remove-Item -Path "YimMenu.dll"
                Write-Output "`nDownloading the latest version..."
                Invoke-WebRequest -Uri $DLL_URL -OutFile "YimMenu.dll"
                Write-Host "`nDownload complete." -ForegroundColor Green
                Read-Host "`nPress any key to exit"
                exit
            } else {
                Write-Host "`nDownload cancelled." -ForegroundColor Red
                Read-Host "`nPress any key to exit"
                exit
            }
        } else {
            Write-Host "`nThere are no newer versions of YimMenu available." -ForegroundColor Green
            Read-Host "`nPress any key to exit"
            exit
        }
    }

    function checkIfLocalFileExists {
        $localFile = Get-ChildItem -Path .\ -Filter YimMenu.dll | Sort-Object LastAccessTime -Descending | Select-Object -First 1
        if ($localFile) {
            #Write-Host "Local file found: $localFile" -ForegroundColor Green
            checkForDllUpdates
        } else {
            Write-Host "Could not find YimMenu." -ForegroundColor Red
            Write-Host "`nDownloading the latest version..."
            Invoke-WebRequest -Uri $DLL_URL -OutFile "YimMenu.dll"
            Write-Host "`nDownload complete." -ForegroundColor Green
            Read-Host "Press any key to exit"
            exit
        }
    }
    checkIfLocalFileExists
}
YimAutoUpdater