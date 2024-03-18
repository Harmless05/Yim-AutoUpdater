# Created by Harmless

# Setting a custom console color (f blue background)
function Set-ConsoleColor ($Background, $Foreground) {
    $Host.UI.RawUI.BackgroundColor = $Background
    $Host.UI.RawUI.ForegroundColor = $Foreground
    Clear-Host
}
Set-ConsoleColor -Background "Black" -Foreground "White" # Feel free to change the colors

# Don't change these :)
$scriptVersion = "1.1.0"
$configVersion = "1.0"
$currentScriptPath = $MyInvocation.MyCommand.Path
$ScriptFolderPath = "C:\Users\$env:USERNAME\Documents\Yim-AutoUpdater"
$BgCheckerPath = Join-Path -Path $ScriptFolderPath -ChildPath "updateChecker.ps1"
$configFile = Join-Path -Path $ScriptFolderPath -ChildPath "config.json"
$defaultDownloadLocation = "C:\Users\$env:USERNAME\Desktop"
$defaultConfig = @{
    "ConfigVersion" = $configVersion
    "DownloadLocation" = $defaultDownloadLocation
    "ScheduledTask" = $false
    "ScheduledTaskName" = "YimMenu AutoUpdater"
    "LastTaskCheck" = "EmptyDate"
}

<#
    CUSTOM FUNCTIONS Part 1

    - Check script folder (If it exists) [checkScriptFolder]
    
    - Check config (If it exists) [checkConfig]

    - Get config value (Get a value from config) [getConfigValue]

    - Set config value (Set a value in the config) [setConfigValue]

    - Update config (If config version is different) [updateConfig]
#>

# Check if the script folder exists, if not create it
function checkScriptFolder {
    if (-not (Test-Path -Path $ScriptFolderPath)) {
        Write-Host "`nScript folder not found, creating a new one..." -ForegroundColor Red
        New-Item -Path $ScriptFolderPath -ItemType Directory | Out-Null
    }
}
checkScriptFolder

# Check if the config file exists, if not create it
function checkConfig {
    if (-not (Test-Path -Path $configFile)) {
        Write-Host "`nConfig file not found, creating a new one...`n" -ForegroundColor Red
        $defaultConfig | ConvertTo-Json | Out-File -FilePath $configFile
    }
}
checkConfig

# Function to get a value from the config file
function getConfigValue($propertyName) {
    if (Test-Path -Path $configFile) {
        $config = Get-Content $configFile | ConvertFrom-Json
        $value = $config.$propertyName
        return $value
    } else {
        Write-Host "Config file not found." -ForegroundColor Red
    }
}

# Function to update a value in the config file
function setConfigValue {
    param (
        [string]$propertyName,
        [string]$newValue
    )
    
    if (Test-Path -Path $configFile) {
        $config = Get-Content $configFile | ConvertFrom-Json
        if ($config.PSObject.Properties.Name -contains $propertyName) {
            $config.$propertyName = $newValue
            $config | ConvertTo-Json | Set-Content $configFile
        } else {
            Write-Host "Property $propertyName does not exist on config object" -ForegroundColor Red
        }
    } else {
        Write-Host "Config file not found." -ForegroundColor Red
    }
}

function updateConfig { # This took way too long to figure out (Checks if the config version and/or properties are different)
    param (
        [string]$configFile,
        [hashtable]$defaultConfig
    )
    # Check if config file exists
    if (Test-Path -Path $configFile) {
        $currentConfig = Get-Content -Path $configFile | ConvertFrom-Json
        # Compare config versions
        if ([version]$currentConfig.ConfigVersion -lt [version]$defaultConfig.ConfigVersion) {
            Write-Host "`nUpdating config file...`n" -ForegroundColor Yellow
            # Update missing/new properties and version
            $defaultConfig.Keys | ForEach-Object {
                if ($null -eq $currentConfig.$_) {
                    Add-Member -InputObject $currentConfig -NotePropertyName $_ -NotePropertyValue $defaultConfig.$_
                }
            }
            # Remove properties that don't exist in the default config
            $currentConfig.PSObject.Properties.Name | Where-Object { $_ -notin $defaultConfig.Keys } | ForEach-Object {
                $currentConfig.PSObject.Properties.Remove($_)
            }
            # Update config version
            $currentConfig.ConfigVersion = $configVersion
            # Save updated config
            $currentConfig | ConvertTo-Json | Set-Content -Path $configFile
        }
    } else {
        # Create new config file with default config
        $defaultConfig | ConvertTo-Json | Set-Content -Path $configFile
    }
}
updateConfig -configFile $configFile -defaultConfig $defaultConfig

# Script variables
$downloadLocation = getConfigValue("DownloadLocation")
# Check if the download location exists, if not then set default location
if (-not $downloadLocation) {
    setConfigValue -propertyName "DownloadLocation" -newValue $defaultDownloadLocation
    $downloadLocation = $defaultDownloadLocation
}
$fileName = "YimMenu.dll"
$fullPath = Join-Path -Path $downloadLocation -ChildPath $fileName

<#

I didn't find a better way to get the value without moving the config functions to the top of the script.

If you have a better way to do this, please let me know.

#>

$API_URL = "https://api.github.com/repos/YimMenu/YimMenu/releases/latest"
$DLL_URL = "https://github.com/YimMenu/YimMenu/releases/download/nightly/YimMenu.dll"

function YimAutoUpdater {
    $TitleArt = "https://raw.githubusercontent.com/Harmless05/Yim-AutoUpdater/main/title.txt"
    $TitleArt = Invoke-RestMethod -Uri $TitleArt
    Write-Host $TitleArt -ForegroundColor Cyan
    Write-Host "v".PadLeft(89) $scriptVersion -ForegroundColor DarkGray

    <#
    BACKGROUND SCRIPT CHECKS

    - Special Message checks [specialMsgCheck]

    - Script update checks [checkForScriptUpdates]

    - Local YimMenu.dll checks [checkIfLocalDLLExists]
    #>
    function specialMsgCheck {
        $specialMsgURL = "https://raw.githubusercontent.com/Harmless05/Yim-AutoUpdater/main/NOTE.txt"
        $specialMsg = Invoke-RestMethod -Uri $specialMsgURL
        # If there is a special message, display it
        if ($specialMsg -ne "") {
            Write-Host "`n! ! ! !`n" -BackgroundColor Red
            Write-Host $specialMsg -ForegroundColor Cyan
            Write-Host "`n! ! ! !`n" -BackgroundColor Red
            Read-Host "Press any key to continue"
        }
    }
    specialMsgCheck

    # Check for script updates

    function checkForScriptUpdates {
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Harmless05/Yim-AutoUpdater/releases/latest"
        $latestVersion = $latestRelease.tag_name
        if ($latestVersion -gt $scriptVersion) {
            Write-Host "`nNew version available: $latestVersion" -ForegroundColor Green
            $downloadUrl = $latestRelease.assets[0].browser_download_url
            $updateChoice = Read-Host "Do you want to update now? (yes/no)"
            if ($updateChoice -eq "yes" -or $updateChoice -eq "y") {
                Invoke-WebRequest -Uri $downloadUrl -OutFile $currentScriptPath
                Write-Host "`New version downloaded, script updated. Restarting..." -ForegroundColor Green
                & $currentScriptPath
                exit
            }
            else {
                Write-Host "Update cancelled" -ForegroundColor Red
                Write-Host "Continuing with the current version..."
            }
        }
    }
    checkForScriptUpdates

    # Check if a local version of YimMenu.dll already exists
    function checkIfLocalDLLExists {

        if (-not (Test-Path -Path $fullPath)) {
            Write-Host "`nLocal file not found!" -ForegroundColor Red
            Write-Host "`nDownloading the latest version..."
            Invoke-WebRequest -Uri $DLL_URL -OutFile $fullPath
            Write-Host "`nDownload completed!" -ForegroundColor Green
        }
    }
    checkIfLocalDLLExists
    <#
    END OF BACKGROUND SCRIPT CHECKS
    #>


    <#
    CUSTOM FUNCTIONS Part 2

    - Reset config [resetConfig]

    - Get hashes (Get hashes of  local and web DLL) [getHashes]

    #>

    # Reset the config file to default values
    function resetConfig {
        while ($true) {
            Write-Host "`nAre you sure you want to reset the config file to default values? (y/N)" -ForegroundColor Red
            $choice = Read-Host
            switch ($choice) {
                y {Clear-Host; $defaultConfig | ConvertTo-Json | Out-File -FilePath $configFile; Write-Host "Config file reset to default values" -ForegroundColor Green; return}
                default {Clear-Host; return}
            }
        }
    }

    function getHashes {
        # Fetch the API response
        $response = Invoke-RestMethod -Uri $API_URL
        # Get Web DLL hash
        $sha256Web = [regex]::match($response.body, '([a-fA-F\d]{64})').Groups[1].Value
        # Check if local DLL exists
        if (-not (Test-Path -Path $fullPath)) {
            Write-Host "`nLocal file not found!" -ForegroundColor Red
            Write-Host "`nDownloading the latest version..."
            Invoke-WebRequest -Uri $DLL_URL -OutFile $fullPath
            Write-Host "`nDownload completed!" -ForegroundColor Green
            # Get Local DLL hash
            $sha256Local = (Get-FileHash $fullPath -Algorithm SHA256 | ForEach-Object Hash).ToLower()
        } else {
            # Get Local DLL hash
            $sha256Local = (Get-FileHash $fullPath -Algorithm SHA256 | ForEach-Object Hash).ToLower()
        }
        $hashes = @{
            "WebHash" = $sha256Web
            "LocalHash" = $sha256Local
        }
        return $hashes
    }

    <#
    END OF CUSTOM FUNCTIONS
    #>

    # Main menu
    function options {
        Write-Host "`n~ " -NoNewline
        Write-Host "Yim" -NoNewline -ForegroundColor Blue
        Write-Host "Menu " -NoNewline -ForegroundColor DarkCyan
        Write-Host "Auto" -NoNewline -ForegroundColor DarkCyan
        Write-Host "Updater" -NoNewline -ForegroundColor Blue
        Write-Host " ~`n"
        Write-Host "Please select a task to run:" -ForegroundColor Cyan
        Write-Host "(1) Check for YimMenu updates"
        Write-Host "(2) Check and download YimMenu updates"
        Write-Host "(3) Script settings"
        Write-Host "(h) Help"
        Write-Host "(0) Exit" -ForegroundColor Red
    }

    function checkForYimUpdates {
        # Fetch the API response
        $response = Invoke-RestMethod -Uri $API_URL
        $hashes = getHashes
        # Compare the two hashes
        if ($hashes.WebHash -ne $hashes.LocalHash) {
            Write-Host "A newer version of YimMenu is available!" -ForegroundColor Green
            Write-Host "`nLatest version: " -NoNewline
            Write-Host $response.name -ForegroundColor Cyan
            Write-Host "`nUpload date: " -NoNewline
            # Convert the date to a readable format
            $response.created_at = [datetime]::Parse($response.created_at)
            Write-Host $response.created_at -ForegroundColor Cyan
            Write-Host "`nWeb hash:   " -NoNewline
            Write-Host $($hashes.WebHash) -ForegroundColor Green
            Write-Host "Local hash: " -NoNewline
            Write-Host $($hashes.LocalHash) -ForegroundColor Red
        } else {
            Write-Host "There are no newer versions of YimMenu available."
        }
    }

    function checkAndDownloadYimUpdates {
        # Fetch the API response
        $response = Invoke-RestMethod -Uri $API_URL
        $hashes = getHashes

        # Compare the two hashes
        if ($hashes.WebHash -ne $hashes.LocalHash) {
            Write-Host "A newer version of YimMenu is available!" -ForegroundColor Green
            Write-Host "`nLatest version: " -NoNewline
            Write-Host $response.name -ForegroundColor Cyan
            Write-Host "`nUpload date: " -NoNewline
            # Convert the date to a readable format
            $response.created_at = [datetime]::Parse($response.created_at)
            Write-Host $response.created_at -ForegroundColor Cyan
            Write-Host "`nWeb hash:   " -NoNewline
            Write-Host $($hashes.WebHash) -ForegroundColor Green
            Write-Host "Local hash: " -NoNewline
            Write-Host $($hashes.LocalHash) -ForegroundColor Red

            $choice = Read-Host "`nDo you want to update YimMenu? (y/N)"
            if ($choice -eq "yes" -or $choice -eq "y" -or $choice -eq "Y" -or $choice -eq "Yes") {
                Write-Host "`nDeleting the old version..." -ForegroundColor Yellow
                # Try to remove the old version
                try {
                    Remove-Item $fullPath -ErrorAction Stop
                } catch {
                    Write-Host "Failed to delete the old version" -ForegroundColor Red
                    break
                }
                Write-Host "`nDownloading the latest version..."
                Invoke-WebRequest -Uri $DLL_URL -OutFile $fullPath
                Clear-Host
                Write-Host "`nDownload complete." -ForegroundColor Green
            } else {
                Clear-Host
                Write-Host "`nDownload cancelled." -ForegroundColor Red
                
            }
        } else {
            Write-Host "There are no newer versions of YimMenu available."
        }
    }

    # Script settings
    function scriptSettings {
        function settingsOptions {
            Write-Host "`n~ " -NoNewline
            Write-Host "Auto" -NoNewline -ForegroundColor DarkRed
            Write-Host "Updater " -NoNewline -ForegroundColor Red
            Write-Host "Settings" -NoNewline -ForegroundColor DarkRed
            Write-Host " ~`n"
            Write-Host "Please select a task to run:" -ForegroundColor Cyan
            Write-Host "(1) Get YimMenu Info"
            Write-Host "(2) Create a Scheduled Task" -NoNewline
            $taskStatus = [System.Convert]::ToBoolean((getConfigValue "ScheduledTask"))
            if ($taskStatus) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }
            Write-Host "(3) Remove the Scheduled Task"
            Write-Host "(4) Open script folder"
            Write-Host "(5) Display config"
            Write-Host "(6) Change YimMenu download location"
            Write-Host "(7) Reset config" -ForegroundColor DarkRed
            Write-Host "(8) Run As Administrator"
            Write-Host "(r) Reload the script"
            Write-Host "(0) Go Back" -ForegroundColor Magenta
        }

        # Function to create a scheduled task
        function createScheduledTask {
            $taskName = getConfigValue("ScheduledTaskName")
            $bgCheckerURL = "https://raw.githubusercontent.com/Harmless05/Yim-AutoUpdater/main/updateChecker.ps1"

            # Download the updater script to the script folder and delete old if exists
            if (Test-Path -Path $BgCheckerPath) {
                Remove-Item -Path $BgCheckerPath -Force
                Write-Host "Downloading the updater script..." -ForegroundColor Yellow
                Invoke-WebRequest -Uri $bgCheckerURL -OutFile $BgCheckerPath
            } else {
                Write-Host "Downloading the updater script..." -ForegroundColor Yellow
                Invoke-WebRequest -Uri $bgCheckerURL -OutFile $BgCheckerPath
            }

            # Check if the task already exists
            if (Get-ScheduledTask | Where-Object {$_.TaskName -eq $taskName}) {
                Write-Host "Scheduled task already exists" -ForegroundColor Yellow
            } else {
                # Check if the user is admin
                if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
                    #[System.Media.SystemSounds]::Exclamation.Play()
                    Write-Host "You need to run the script as administrator to create the scheduled task!" -ForegroundColor Red
                    return
                }
                setConfigValue -propertyName "ScheduledTask" -newValue $true
                $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $BgCheckerPath"
                $taskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 365)
                $taskTrigger2 = New-ScheduledTaskTrigger -AtStartup
                $taskSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
                Register-ScheduledTask -TaskName $taskName -Trigger $taskTrigger, $taskTrigger2 -Action $taskAction -Settings $taskSettings
                Write-Host "Scheduled task created" -ForegroundColor Green
            }
        }

        function removeScheduledTask {
            $taskName = getConfigValue("ScheduledTaskName")
            if (Get-ScheduledTask | Where-Object {$_.TaskName -eq $taskName}) {
                # Check if the user is admin
                if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
                    #[System.Media.SystemSounds]::Exclamation.Play()
                    Write-Host "You need to run the script as administrator to remove the scheduled task!" -ForegroundColor Red
                    return
                }
                setConfigValue -propertyName "ScheduledTask" -newValue $false
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                Write-Host "Scheduled task removed." -ForegroundColor Green
            } else {
                setConfigValue -propertyName "ScheduledTask" -newValue $false
                Write-Host "Scheduled task not found!" -ForegroundColor Red
            }
        }

        function changeDownloadLocation {
            function presetLocations {
                Write-Host "`n~ " -NoNewline
                Write-Host "Preset " -NoNewline -ForegroundColor DarkCyan
                Write-Host "Locations" -NoNewline -ForegroundColor Cyan
                Write-Host " ~`n"
                Write-Host "(1) Desktop"
                Write-Host "(2) Downloads"
                Write-Host "(3) Documents"
                Write-Host "(4) Yim-AutoUpdater"
                Write-Host "(5) Custom location" -ForegroundColor Green
                Write-Host "(0) Go Back" -ForegroundColor Magenta
            }
            
            function changeLocation {
                $downloadLocationNew = (New-Object -ComObject Shell.Application).BrowseForFolder(0, "Select the new download location", 0, "C:\").Self.Path
                setConfigValue -propertyName "DownloadLocation" -newValue $downloadLocationNew
                Write-Host "Download location changed to $downloadLocationNew" -ForegroundColor Green
            }

            while ($true) {
                presetLocations
                $choice = Read-Host "`nEnter your choice"
                switch ($choice) {
                    1 { Clear-Host; setConfigValue -propertyName "DownloadLocation" -newValue "C:\Users\$env:USERNAME\Desktop"; Write-Host "Download location changed to C:\Users\$env:USERNAME\Desktop" -ForegroundColor Green; break }
                    2 { Clear-Host; setConfigValue -propertyName "DownloadLocation" -newValue "C:\Users\$env:USERNAME\Downloads"; Write-Host "Download location changed to C:\Users\$env:USERNAME\Downloads" -ForegroundColor Green; break }
                    3 { Clear-Host; setConfigValue -propertyName "DownloadLocation" -newValue "C:\Users\$env:USERNAME\Documents"; Write-Host "Download location changed to C:\Users\$env:USERNAME\Documents" -ForegroundColor Green; break }
                    4 { Clear-Host; setConfigValue -propertyName "DownloadLocation" -newValue "C:\Users\$env:USERNAME\Documents\Yim-AutoUpdater"; Write-Host "Download location changed to C:\Users\CoolUserName\Documents\Yim-AutoUpdater" -ForegroundColor Green; break }
                    5 { Clear-Host; changeLocation; break }
                    0 { Clear-Host; return }
                    default {Clear-Host; Write-Host "Invalid choice, please try again" -ForegroundColor Red; [System.Media.SystemSounds]::Exclamation.Play()}
                }
            }
        }

        function openScriptFolder {
            if (Test-Path $ScriptFolderPath) {
                Invoke-Item $ScriptFolderPath
            } else {
                Write-Host "Script folder not found" -ForegroundColor Red
                Write-Host "Creating script folder..." -ForegroundColor Yellow
                New-Item -Path $ScriptFolderPath -ItemType Directory
                Write-Host "Script folder created" -ForegroundColor Green
                Write-Host "Opening script folder..."
                Invoke-Item $ScriptFolderPath
            }
        }

        function displayConfig {
            Write-Host "`nConfig:" -ForegroundColor Cyan
            # Convert json to readable format
            $config = Get-Content $configFile | ConvertFrom-Json
            $config.PSObject.Properties | ForEach-Object {
                Write-Host ("{0} : {1}" -f $_.Name, $_.Value)
            }
        }

        function getYimMenuInfo {
            $response = Invoke-RestMethod -Uri $API_URL
            $hashes = getHashes
            Write-Host "`nLatest version: " -NoNewline
            Write-Host $response.name -ForegroundColor Cyan
            Write-Host "`nUpload date: " -NoNewline
            # Convert the date to a readable format
            $response.created_at = [datetime]::Parse($response.created_at)
            Write-Host $response.created_at
            # Compare the two hashes
            if ($hashes.WebHash -ne $hashes.LocalHash) {
                Write-Host "`nWeb hash:   " -NoNewline
                Write-Host $($hashes.WebHash) -ForegroundColor Green
                Write-Host "Local hash: " -NoNewline
                Write-Host $($hashes.LocalHash) -ForegroundColor Red
            } else {
                Write-Host "`nWeb hash:   " -NoNewline
                Write-Host $($hashes.WebHash) -ForegroundColor Green
                Write-Host "Local hash: " -NoNewline
                Write-Host $($hashes.LocalHash) -ForegroundColor Green
            }
        }

        function runAsAdmin {
            # Check if the script is running as admin
            function runAsAdminCheck {
                if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
                    # Relaunch as admin
                    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$currentScriptPath`"" -Verb RunAs
                    exit
                }
            }

            while ($true) {
                Write-Host "`n~ " -NoNewline
                Write-Host "Run " -NoNewline -ForegroundColor DarkRed
                Write-Host "As " -NoNewline -ForegroundColor Red
                Write-Host "Administrator" -NoNewline -ForegroundColor DarkRed
                Write-Host " ~`n"
                Write-Host "Do you want to run the script as administrator?" -NoNewline -ForegroundColor DarkRed
                Write-Host " (y/N): "
                $choice = Read-Host
                switch ($choice) {
                    y { Clear-Host; runAsAdminCheck; break }
                    default {Clear-Host; return}
                }
            }
        }

        # Function to reload the script
        # Mostly used this when testing the script
        function reloadScript {
            Write-Host "`nReloading the script..." -ForegroundColor Yellow
            & $currentScriptPath
            exit
        }

        while ($true) {
            settingsOptions
            $choice = Read-Host "`nEnter your choice"
            switch ($choice) {
                1 { Clear-Host; getYimMenuInfo; break }
                2 { Clear-Host; createScheduledTask; break }
                3 { Clear-Host; removeScheduledTask; break }
                4 { Clear-Host; openScriptFolder; break }
                5 { Clear-Host; displayConfig; break }
                6 { Clear-Host; changeDownloadLocation; break }
                7 { Clear-Host; resetConfig; break }
                8 { Clear-Host; runAsAdmin; break }
                r { Clear-Host; reloadScript; break }
                0 { Clear-Host; return }
                default {Clear-Host; Write-Host "Invalid choice, please try again" -ForegroundColor Red; [System.Media.SystemSounds]::Exclamation.Play()}
            }
        }
    }

    function helpMenu {
        function helpMenuOptions {
            Write-Host "`n~ " -NoNewline
            Write-Host "Help " -NoNewline -ForegroundColor Blue
            Write-Host "Menu" -NoNewline -ForegroundColor DarkCyan
            Write-Host " ~`n"

            Write-Host "`n- " -NoNewline
            Write-Host "Main " -NoNewline -ForegroundColor Cyan
            Write-Host "Menu" -NoNewline -ForegroundColor DarkCyan
            Write-Host "Features:" -NoNewline -ForegroundColor Cyan
            Write-Host " -`n"
            Write-Host "1. Check for YimMenu updates" -ForegroundColor DarkCyan
            Write-Host " - Checks if a newer version of YimMenu is available."
            Write-Host "`n2. Check and download YimMenu updates" -ForegroundColor DarkCyan
            Write-Host " - Checks if a newer version of YimMenu is available and also downloads it."
            Write-Host "`n3. Script settings" -ForegroundColor DarkCyan
            Write-Host " - Change the download location, create a scheduled task, remove the scheduled task, and more."

            Write-Host "`n- " -NoNewline
            Write-Host "Auto" -NoNewline -ForegroundColor DarkRed
            Write-Host "Updater " -NoNewline -ForegroundColor Red
            Write-Host "Settings" -NoNewline -ForegroundColor DarkRed
            Write-Host " -`n"
            Write-Host "1. Get YimMenu Info" -ForegroundColor Red
            Write-Host " - Get the latest version of YimMenu and its hashes."
            Write-Host "`n2. Create a Scheduled Task" -ForegroundColor Red
            Write-Host " - Creates a scheduled task to periodically check for updates in the background."
            Write-Host " - (Runs every 30 minutes and at user logon)"
            Write-Host " - (Requires admin privileges)" -ForegroundColor Yellow
            Write-Host "`n3. Remove the Scheduled Task" -ForegroundColor Red
            Write-Host " - Removes the scheduled task."
            Write-Host "  - (Requires admin privileges)" -ForegroundColor Yellow
            Write-Host "`n4. Open script folder" -ForegroundColor Red
            Write-Host " - Opens the script folder."
            Write-Host "`n5. Display config" -ForegroundColor Red
            Write-Host " - Displays the current config."
            Write-Host "`n6. Change YimMenu download location" -ForegroundColor Red
            Write-Host " - Change the download location where YimMenu is downloaded to."
            Write-Host "`n7. Reset config" -ForegroundColor Red
            Write-Host " - Resets the config file to default values."
            Write-Host "`n8. Run As Administrator" -ForegroundColor Red
            Write-Host " - Relaunch the script as administrator."
            Write-Host "`nr/R. Reload the script" -ForegroundColor Red
            Write-Host " - Reloads the script."

            Write-Host "`n`n`Didn't find what you were looking for?`n" -ForegroundColor Red
            Write-Host "Contact at GitHub: " -NoNewline 
            Write-Host "https://github.com/Harmless05/Yim-AutoUpdater/issues" -ForegroundColor Cyan
            Write-Host "Contact at Discord: " -NoNewline 
            Write-Host "@harmless0" -ForegroundColor Blue
        }

        while ($true) {
            helpMenuOptions
            Write-Host "`n(0) Go Back: " -ForegroundColor Magenta -NoNewline
            $choice = Read-Host
            switch ($choice) {
                0 { Clear-Host; return }
                default {Clear-Host}
            }
        }
    }

    while ($true) {
        options
        $choice = Read-Host "`nEnter your choice"
        switch ($choice) {
            1 { Clear-Host; checkForYimUpdates; break }
            2 { Clear-Host; checkAndDownloadYimUpdates; break }
            3 { Clear-Host; scriptSettings; break}
            h { Clear-Host; helpMenu; break }
            0 { exit }
            default {Clear-Host; Write-Host "Invalid choice, please try again" -ForegroundColor Red; [System.Media.SystemSounds]::Exclamation.Play()}
        }
    }
}
YimAutoUpdater