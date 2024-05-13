# Created by Harmless

# Setting a custom console color (f blue background)
function Set-ConsoleColor ($Background, $Foreground) {
    $Host.UI.RawUI.BackgroundColor = $Background
    $Host.UI.RawUI.ForegroundColor = $Foreground
    Clear-Host
}
Set-ConsoleColor -Background "Black" -Foreground "White" # Feel free to change the colors

# Don't change these :)
$scriptVersion = "1.3.0"
$configVersion = "3.0"
$currentScriptPath = $MyInvocation.MyCommand.Path
$scriptFolderPath = "C:\Users\$env:USERNAME\Documents\Yim-AutoUpdater"
$bgCheckerPath = Join-Path -Path $scriptFolderPath -ChildPath "updateChecker.ps1"
$configFile = Join-Path -Path $scriptFolderPath -ChildPath "config.json"
$yimMenuPath = "C:\Users\$env:USERNAME\AppData\Roaming\YimMenu"
$defaultDownloadLocation = "C:\Users\$env:USERNAME\Desktop"
$defaultConfig = @{
    "ConfigVersion" = $configVersion
    "DownloadLocation" = $defaultDownloadLocation
    "CheckAtStartup" = $false
    "ExitAnywhere" = $false
    "RestartAnywhere" = $true
    "TitleArt" = $true
    "SoundEffects" = $true
    "DebugInfo" = $false
    "CheckLuaAtStartup" = $false
    "ScanLuaAtStartup" = $false
    "SkipDisabledLuaUpdates" = $false
    "InjectionDelay" = 7000
    "AutoLaunchGTAV" = $false
    "Platform" = "4"
    "GitHubToken" = ""
    "CloseAfterInjection" = $true
    "ScheduledTask" = $false
    "ScheduledTaskName" = "YimMenu AutoUpdater"
    "LastTaskCheck" = "EmptyDate"
}

<#
    CUSTOM FUNCTIONS

    - Get config value (Get a value from config) [GetConfigValue]

    - Set config value (Set a value in the config) [SetConfigValue]

    - Toggle config value (Toggle a boolean value in the config with message) [ToggleConfigValue]

    - Update config (If config version is different) [UpdateConfig]

    - Reset config [ResetConfig]

    - Get hashes (Get hashes of  local and web DLL) [GetHashes]

    - Reload script [ReloadScript]

    - Run DLL check [RunDLLCheck]

    - Play Exclamation sound [PlayExclamation]

#>

# Function to get a value from the config file
function GetConfigValue($propertyName) {
    if (Test-Path -Path $configFile) {
        $config = Get-Content $configFile | ConvertFrom-Json
        $value = $config.$propertyName
        return $value
    } else {
        Write-Host "Config file not found." -ForegroundColor Red
    }
}

# Function to update a value in the config file
function SetConfigValue {
    param (
        [string]$propertyName,
        $newValue
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

function ToggleConfigValue {
    param (
        [string]$propertyName,
        [string]$enabledMessage,
        [string]$disabledMessage
    )
    # Get the current status of the property
    $currentStatus = (GetConfigValue($propertyName))
    # Change the status based on the current status
    if ($currentStatus) {
        SetConfigValue -propertyName $propertyName -newValue $false
        Write-Host $disabledMessage -ForegroundColor Red
    } else {
        SetConfigValue -propertyName $propertyName -newValue $true
        Write-Host $enabledMessage -ForegroundColor Green
    }
}

function UpdateConfig { # This took way too long to figure out (Checks if the config version and/or properties are different)
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
UpdateConfig -configFile $configFile -defaultConfig $defaultConfig

function ResetConfig { # Reset the config file to default values
    while ($true) {
        Write-Host "`nAre you sure you want to reset the config file to default values? (y/N)" -ForegroundColor Red
        $choice = Read-Host
        switch ($choice) {
            y {Clear-Host; $defaultConfig | ConvertTo-Json | Out-File -FilePath $configFile; Write-Host "Config file reset to default values" -ForegroundColor Green; return}
            default {Clear-Host; return}
        }
    }
}

function GetHashes { # This function is used to get the hashes of the local and web DLLs
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

# Function to reload the script
# Mostly used this when testing the script
function ReloadScript {
    Write-Host "`nReloading the script..." -ForegroundColor Yellow
    & $currentScriptPath
    exit
}

function RunDLLCheck {
    $response = Invoke-RestMethod -Uri $API_URL
    $hashes = GetHashes

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
}

function PlayExclamation {
    if (GetConfigValue("SoundEffects")) {
        [System.Media.SystemSounds]::Exclamation.Play()
    }
}

# Script variables
$downloadLocation = GetConfigValue("DownloadLocation")
# Check if the download location exists, if not then set default location
if (-not $downloadLocation) {
    SetConfigValue -propertyName "DownloadLocation" -newValue $defaultDownloadLocation
    $downloadLocation = $defaultDownloadLocation
}
$fileName = "YimMenu.dll"
$fullPath = Join-Path -Path $downloadLocation -ChildPath $fileName

<#
I didn't find a better way to get the value without moving the config functions to the top of the script.
If you have a better way to do this, please let me know.
#>

<#
END OF CUSTOM FUNCTIONS
#>

$API_URL = "https://api.github.com/repos/YimMenu/YimMenu/releases/latest"
$DLL_URL = "https://github.com/YimMenu/YimMenu/releases/download/nightly/YimMenu.dll"

function YimAutoUpdater {
    function DisplayTitleArtFromURL {
        if (GetConfigValue("TitleArt")) {
            $TitleArt = "https://harmlessdev.xyz/title.txt"
            $TitleArt = Invoke-RestMethod -Uri $TitleArt
            Write-Host $TitleArt -ForegroundColor Cyan
            Write-Host "v".PadLeft(89) $scriptVersion -ForegroundColor DarkGray
        }
    }

    <#
    BACKGROUND SCRIPT CHECKS

    - Special Message checks [specialMsgCheck]

    - Script update checks [CheckForScriptUpdates]

    - Script folder checks [CheckScriptFolder]

    - Config file checks [CheckConfig]

    - Local YimMenu.dll checks [CheckIfLocalDLLExists]

    - Check for YimMenu updates at startup [checkAtStartup]
    #>

    function SpecialMsgCheck {
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
    SpecialMsgCheck
    
    # Check for script updates
    function CheckForScriptUpdates {
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Harmless05/Yim-AutoUpdater/releases/latest"
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
    CheckForScriptUpdates

    # Check if the script folder exists, if not create it
    function CheckScriptFolder {
        if (-not (Test-Path -Path $scriptFolderPath)) {
            Write-Host "`nScript folder not found, creating a new one..." -ForegroundColor Red
            New-Item -Path $scriptFolderPath -ItemType Directory | Out-Null
        }
    }
    CheckScriptFolder

    # Check if the config file exists, if not create it
    function CheckConfig {
        if (-not (Test-Path -Path $configFile)) {
            Write-Host "`nConfig file not found, creating a new one...`n" -ForegroundColor Red
            $defaultConfig | ConvertTo-Json | Out-File -FilePath $configFile
        }
    }
    CheckConfig

    # Check if a local version of YimMenu.dll already exists
    function CheckIfLocalDLLExists {
        if (-not (Test-Path -Path $fullPath)) {
            Write-Host "`nLocal file not found!" -ForegroundColor Red
            Write-Host "`nDownloading the latest version..."
            Invoke-WebRequest -Uri $DLL_URL -OutFile $fullPath
            Write-Host "`nDownload completed!" -ForegroundColor Green
        }
    }
    CheckIfLocalDLLExists
    
    function CheckAtStartup {
        $checkAtStartup = GetConfigValue("CheckAtStartup")
        if ($checkAtStartup) {
            $hashes = GetHashes
            # Compare the two hashes
            if ($hashes.WebHash -ne $hashes.LocalHash) {
                Write-Host "`n~ Checking for updates at startup ~`n" -ForegroundColor Yellow
                RunDLLCheck # Run the DLL check function
                $choice = Read-Host "`nDo you want to update YimMenu? (y/N)"
                if ($choice -eq "yes" -or $choice -eq "y" -or $choice -eq "Y" -or $choice -eq "Yes") {
                    Write-Host "`nDeleting the old version..." -ForegroundColor Yellow
                    # Try to remove the old version, if failed then break
                    try {
                        Remove-Item $fullPath -ErrorAction Stop
                    } catch {
                        PlayExclamation
                        Write-Host "Failed to delete the old version" -ForegroundColor Red
                        break
                    }
                    Write-Host "`nDownloading the latest version..."
                    Invoke-WebRequest -Uri $DLL_URL -OutFile $fullPath
                    Clear-Host
                    return Write-Host "`nDownload completed." -ForegroundColor Green
                } else {
                    Clear-Host
                    return Write-Host "`nDownload cancelled." -ForegroundColor Red
                }
            }
        }
    }
    CheckAtStartup

    <#
    END OF BACKGROUND SCRIPT CHECKS
    #>

    # Main menu
    function Options {
        DisplayTitleArtFromURL # Draw the "big" title art
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
        Write-Host "(4) YimMenu Lua"
        Write-Host "(5) Inject YimMenu " -NoNewline
        Write-Host "[ALPHA] - Use at your own risk!" -ForegroundColor Red
        if (GetConfigValue("AutoLaunchGTAV")) {
            Write-Host "    Platform: " -ForegroundColor DarkCyan -NoNewline 
            $platform = GetConfigValue("Platform")
            if ($platform -eq "4") {
                Write-Host "None" -ForegroundColor DarkCyan
            } elseif ($platform -eq "1") {
                Write-Host "Steam" -ForegroundColor DarkCyan
            } elseif ($platform -eq "2") {
                Write-Host "Epic Games" -ForegroundColor DarkCyan
            } elseif ($platform -eq "3") {
                Write-Host "Rockstar Games Launcher" -ForegroundColor DarkCyan
            }
        }
        Write-Host "(h) Help"
        Write-Host "(0) Exit" -ForegroundColor Red
    }

    function CheckForYimUpdates {
        # Fetch the API response
        #$response = Invoke-RestMethod -Uri $API_URL
        $hashes = GetHashes
        # Compare the two hashes
        if ($hashes.WebHash -ne $hashes.LocalHash) {
            RunDLLCheck # Run the DLL check function
        } else {
            Write-Host "There are no newer versions of YimMenu available."
        }
    }

    function CheckAndDownloadYimUpdates {
        # Fetch the API response
        #$response = Invoke-RestMethod -Uri $API_URL
        $hashes = GetHashes

        # Compare the two hashes
        if ($hashes.WebHash -ne $hashes.LocalHash) {
            RunDLLCheck # Run the DLL check function
            $choice = Read-Host "`nDo you want to update YimMenu? (y/N)"
            if ($choice -eq "yes" -or $choice -eq "y" -or $choice -eq "Y" -or $choice -eq "Yes") {
                Write-Host "`nDeleting the old version..." -ForegroundColor Yellow
                # Try to remove the old version, if failed then break
                try {
                    Remove-Item $fullPath -ErrorAction Stop
                } catch {
                    PlayExclamation
                    Write-Host "Failed to delete the old version" -ForegroundColor Red
                    break
                }
                Write-Host "`nDownloading the latest version..."
                Invoke-WebRequest -Uri $DLL_URL -OutFile $fullPath
                Clear-Host
                Write-Host "`nDownload completed." -ForegroundColor Green
            } else {
                Clear-Host
                Write-Host "`nDownload cancelled." -ForegroundColor Red
            }
        } else {
            Write-Host "There are no newer versions of YimMenu available."
        }
    }

    # Script settings
    function ScriptSettings {
        function SettingsOptions {
            Write-Host "`n~ " -NoNewline
            Write-Host "Auto" -NoNewline -ForegroundColor DarkRed
            Write-Host "Updater " -NoNewline -ForegroundColor Red
            Write-Host "Settings" -NoNewline -ForegroundColor DarkRed
            Write-Host " ~`n"
            Write-Host "Please select a task to run:" -ForegroundColor Cyan
            Write-Host "`n = YimMenu Settings =" -ForegroundColor Yellow # YimMenu category
            Write-Host "(1)  Get YimMenu Info"
            Write-Host "(2)  Open YimMenu folder"
            Write-Host "(3)  Change YimMenu download location"
            # Check for updates at startup
            Write-Host "(4)  Check for updates at startup" -NoNewline
            $checkAtStartup = (GetConfigValue "CheckAtStartup")
            if ($checkAtStartup) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }

            Write-Host "`n = Script Toggles =" -ForegroundColor Yellow # Script Toggles category
            # Enable exit keybind "E/Q" anywhere
            Write-Host "(5)  Exit keybind (e/q) anywhere" -NoNewline
            $exitAnywhere = (GetConfigValue "ExitAnywhere")
            if ($exitAnywhere) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }
            # Enable restart keybind "R" anywhere
            Write-Host "(6)  Restart keybind (r) anywhere" -NoNewline
            $restartAnywhere = (GetConfigValue "RestartAnywhere")
            if ($restartAnywhere) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }
            # Big Title Art
            Write-Host "(7)  Big Title Art" -NoNewline
            $titleArt = (GetConfigValue "TitleArt")
            if ($titleArt) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }
            # Sound effects
            Write-Host "(8)  Sound effects" -NoNewline
            $soundEffects = (GetConfigValue "SoundEffects")
            if ($soundEffects) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }
            # Debug info
            Write-Host "(9)  Debug Info" -NoNewline
            $debugInfo = (GetConfigValue "DebugInfo")
            if ($debugInfo) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }

            Write-Host "`n = YimMenu Lua Settings =" -ForegroundColor Yellow # YimMenu Lua category
            Write-Host "(10) Check for Lua updates at startup" -NoNewline
            $checkLuaAtStartup = (GetConfigValue "CheckLuaAtStartup")
            if ($checkLuaAtStartup) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }
            Write-Host "(11) Scan for Lua scripts at startup" -NoNewline
            $scanLuaAtStartup = (GetConfigValue "ScanLuaAtStartup")
            if ($scanLuaAtStartup) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }
            Write-Host "(12) Skip updates for YimMenu disabled luas" -NoNewline
            $skipDisabledLuaUpdates = (GetConfigValue "SkipDisabledLuaUpdates")
            if ($skipDisabledLuaUpdates) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }

            Write-Host "`n = DLL Injection Settings =" -ForegroundColor Yellow # DLL Injection category
            Write-Host "(13) Injection delay: " -NoNewline
            $injectionDelay = (GetConfigValue "InjectionDelay")
            Write-Host "$injectionDelay ms" -ForegroundColor Cyan
            Write-Host "(14) Auto launch GTAV" -NoNewline
            $autoLaunchGTAV = (GetConfigValue "AutoLaunchGTAV")
            if ($autoLaunchGTAV) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }
            Write-Host "(15) Platform: " -NoNewline
            $platform = (GetConfigValue "Platform")
            if ($platform -eq "4") {
                Write-Host "None" -ForegroundColor Cyan
            } elseif ($platform -eq "1") {
                Write-Host "Steam" -ForegroundColor Cyan
            } elseif ($platform -eq "2") {
                Write-Host "Epic Games" -ForegroundColor Cyan
            } elseif ($platform -eq "3") {
                Write-Host "Rockstar Games Launcher" -ForegroundColor Cyan
            }
            Write-Host "(16) Close after injection" -NoNewline
            $closeAfterInjection = (GetConfigValue "CloseAfterInjection")
            if ($closeAfterInjection) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }

            Write-Host "`n = GitHub API Settings =" -ForegroundColor Yellow # GitHub API category
            Write-Host "(17) Set GitHub token" -NoNewline
            $githubToken = (GetConfigValue "GitHubToken")
            # Check if value is empty
            if ($null -eq $githubToken -or $githubToken -eq "") {
                Write-Host " (Not set)" -ForegroundColor DarkRed
            } else {
                Write-Host " (Set)" -ForegroundColor DarkGreen
            }
            Write-Host "(18) Remove GitHub token"

            Write-Host "`n = Scheduled Task Settings =" -ForegroundColor Yellow # Scheduled Task category
            Write-Host "(19) Create a Scheduled Task" -NoNewline
            # Check if the scheduled task is enabled
            $taskStatus = (GetConfigValue "ScheduledTask")
            if ($taskStatus) {
                Write-Host " (Enabled)" -ForegroundColor DarkGreen
            } else {
                Write-Host " (Disabled)" -ForegroundColor DarkRed
            }
            Write-Host "(20) Remove the Scheduled Task"

            Write-Host "`n = Misc Settings =" -ForegroundColor Yellow # Misc category
            Write-Host "(21) Open script folder"
            Write-Host "(22) Display config"
            Write-Host "(23) Reset config" -ForegroundColor DarkRed
            Write-Host "(24) Run As Administrator"
            Write-Host "(r)  Reload the script"
            Write-Host "`n(0)  Go Back" -ForegroundColor Magenta
        }

        # Gets info about the latest version of YimMenu
        function GetYimMenuInfo {
            $response = Invoke-RestMethod -Uri $API_URL
            $hashes = GetHashes
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

        # Opens the YimMenu folder
        function OpenYimMenuFolder {
            $yimMenuPath = "C:\Users\$env:USERNAME\AppData\Roaming\YimMenu"
            if (Test-Path -Path $yimMenuPath) {
                Invoke-Item $yimMenuPath
            } else {
                Write-Host "YimMenu folder not found" -ForegroundColor Red
            }
        }

        # Function to change the download location
        function ChangeDownloadLocation {
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
            
            function ChangeLocation {
                $downloadLocationNew = (New-Object -ComObject Shell.Application).BrowseForFolder(0, "Select the new download location", 0, "C:\").Self.Path
                SetConfigValue -propertyName "DownloadLocation" -newValue $downloadLocationNew
                Write-Host "Download location changed to $downloadLocationNew" -ForegroundColor Green
            }

            while ($true) {
                presetLocations
                $choice = Read-Host "`nEnter your choice"
                switch ($choice) {
                    1 { Clear-Host; SetConfigValue -propertyName "DownloadLocation" -newValue "C:\Users\$env:USERNAME\Desktop"; Write-Host "Download location changed to C:\Users\$env:USERNAME\Desktop" -ForegroundColor Green; break }
                    2 { Clear-Host; SetConfigValue -propertyName "DownloadLocation" -newValue "C:\Users\$env:USERNAME\Downloads"; Write-Host "Download location changed to C:\Users\$env:USERNAME\Downloads" -ForegroundColor Green; break }
                    3 { Clear-Host; SetConfigValue -propertyName "DownloadLocation" -newValue "C:\Users\$env:USERNAME\Documents"; Write-Host "Download location changed to C:\Users\$env:USERNAME\Documents" -ForegroundColor Green; break }
                    4 { Clear-Host; SetConfigValue -propertyName "DownloadLocation" -newValue "C:\Users\$env:USERNAME\Documents\Yim-AutoUpdater"; Write-Host "Download location changed to C:\Users\CoolUserName\Documents\Yim-AutoUpdater" -ForegroundColor Green; break }
                    5 { Clear-Host; ChangeLocation; break }
                    0 { Clear-Host; return }
                    default { Clear-Host; Write-Host "Invalid choice, please try again" -ForegroundColor Red; PlayExclamation }
                }
            }
        }

        # Function to set the amount of time to wait before injecting the DLL
        function SetInjectionDelay {
            do {
                $injectionDelay = Read-Host "Enter the new injection delay in milliseconds (1000 - 20000)"
                $injectionDelay = $injectionDelay -as [int]
                Clear-Host
                Write-Host "Value must be between 1000 and 20000!`n" -ForegroundColor Red
            } until ($injectionDelay -and $injectionDelay -ge 1000 -and $injectionDelay -le 20000)
        
            SetConfigValue -propertyName "InjectionDelay" -newValue $injectionDelay
            Clear-Host
            Write-Host "Injection delay set to $injectionDelay ms" -ForegroundColor Green
        }

        # Function to set the DLL injection platform when auto-launching GTAV
        function SetPlatform {
            function ChoosePlatform {
                Write-Host "`n~ " -NoNewline
                Write-Host "Choose " -NoNewline -ForegroundColor DarkCyan
                Write-Host "Platform" -NoNewline -ForegroundColor Cyan
                Write-Host " ~`n"
                Write-Host "(1) Steam"
                Write-Host "(2) Epic Games"
                Write-Host "(3) Rockstar Games Launcher"
                Write-Host "(4) None" -ForegroundColor Yellow
                Write-Host "(0) Go Back" -ForegroundColor Magenta
            }

            while ($true) {
                ChoosePlatform
                $choice = Read-Host "`nEnter your choice"
                switch ($choice) {
                    1 { Clear-Host; SetConfigValue -propertyName "Platform" -newValue "1"; Write-Host "Platform set to Steam" -ForegroundColor Green; break }
                    2 { Clear-Host; SetConfigValue -propertyName "Platform" -newValue "2"; Write-Host "Platform set to Epic Games" -ForegroundColor Green; break }
                    3 { Clear-Host; SetConfigValue -propertyName "Platform" -newValue "3"; Write-Host "Platform set to Rockstar Games Launcher" -ForegroundColor Green; break }
                    4 { Clear-Host; SetConfigValue -propertyName "Platform" -newValue "4"; Write-Host "Platform set to None" -ForegroundColor Green; break }
                    0 { Clear-Host; return }
                    default { Clear-Host; Write-Host "Invalid choice, please try again" -ForegroundColor Red; PlayExclamation }
                }
            }
        }

        # Function to encrypt a string
        function EncryptString($inputString) {
            $secureInput = ConvertTo-SecureString $inputString -AsPlainText -Force
            $encryptedInput = ConvertFrom-SecureString $secureInput
            return $encryptedInput
        }

        # Function to decrypt a string
        function DecryptString($inputString) {
            $secureInput = ConvertTo-SecureString $inputString
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureInput)
            $unsecureInput = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            return $unsecureInput
        }

        # Function to set GitHub token
        function SetGitHubToken {
            $token = Read-Host "Please enter your GitHub token" -AsSecureString
            $encryptedToken = EncryptString $token
            SetConfigValue -propertyName "GitHubToken" -newValue $encryptedToken
            Clear-Host
            Write-Host "GitHub token has been set." -ForegroundColor Green
        }

        function RemoveGitHubToken {
            SetConfigValue -propertyName "GitHubToken" -newValue $null
            Write-Host "GitHub token has been removed." -ForegroundColor Green
        }

        # Function to get GitHub token
        function GetGitHubToken {
            $config = Get-Content config.json | ConvertFrom-Json
            $encryptedToken = $config.GitHubToken
            $token = DecryptString $encryptedToken
            return $token
        }
        
        <#
        
        Windows Credential Manager functions

        #>
        # # Function to set GitHub token
        # function SetGitHubToken {
        #     $securePassword = Read-Host "Please enter your GitHub token" -AsSecureString
        #     $credential = New-Object System.Management.Automation.PSCredential("YimGitHubToken", $securePassword)
        #     $result = New-StoredCredential -Credential $credential -Target "YimGitHubToken" -Persist LocalMachine
        #     if ($result) {
        #         SetConfigValue -propertyName "GitHubToken" -newValue $true
        #         Write-Host "GitHub token has been set." -ForegroundColor Green
        #     } else {
        #         Write-Host "Failed to set GitHub token." -ForegroundColor Red
        #     }
        # }

        # # Removes the GitHub token
        # function RemoveGitHubToken {
        #     $credential = Get-StoredCredential -Target "YimGitHubToken"
        #     if ($credential) {
        #         Remove-StoredCredential -Target "YimGitHubToken"
        #         SetConfigValue -propertyName "GitHubToken" -newValue $false
        #         Write-Host "GitHub token has been removed." -ForegroundColor Green
        #     } else {
        #         Write-Host "GitHub token not found." -ForegroundColor Red
        #     }
        # }

        # # Gets the current GitHub token value
        # function GetGitHubToken {
        #     $credential = Get-StoredCredential -Target "YimGitHubToken"
        #     if ($credential) {
        #         $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($credential.Password)
        #         try {
        #             $plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
        #         } finally {
        #             [System.Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($ptr)
        #         }
        #         return $plainTextPassword
        #     } else {
        #         return $null
        #     }
        # }

        # Function to create a scheduled task
        function CreateScheduledTask {
            $taskName = GetConfigValue("ScheduledTaskName")
            $bgCheckerURL = "https://raw.githubusercontent.com/Harmless05/Yim-AutoUpdater/main/updateChecker.ps1"

            # Download the updater script to the script folder and delete old if exists
            if (Test-Path -Path $bgCheckerPath) {
                Remove-Item -Path $bgCheckerPath -Force
                Write-Host "Downloading the updater script..." -ForegroundColor Yellow
                Invoke-WebRequest -Uri $bgCheckerURL -OutFile $bgCheckerPath
            } else {
                Write-Host "Downloading the updater script..." -ForegroundColor Yellow
                Invoke-WebRequest -Uri $bgCheckerURL -OutFile $bgCheckerPath
            }

            # Check if the task already exists
            if (Get-ScheduledTask | Where-Object {$_.TaskName -eq $taskName}) {
                Write-Host "Scheduled task already exists" -ForegroundColor Yellow
            } else {
                # Check if the user is admin
                if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
                    Write-Host "You need to run the script as administrator to create the scheduled task!" -ForegroundColor Red
                    return
                }
                SetConfigValue -propertyName "ScheduledTask" -newValue $true
                $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $bgCheckerPath"
                $taskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 365)
                $taskTrigger2 = New-ScheduledTaskTrigger -AtStartup
                $taskSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
                Register-ScheduledTask -TaskName $taskName -Trigger $taskTrigger, $taskTrigger2 -Action $taskAction -Settings $taskSettings
                Write-Host "Scheduled task created" -ForegroundColor Green
            }
        }

        # Function to remove the scheduled task
        function RemoveScheduledTask {
            $taskName = GetConfigValue("ScheduledTaskName")
            if (Get-ScheduledTask | Where-Object {$_.TaskName -eq $taskName}) {
                # Check if the user is admin
                if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
                    Write-Host "You need to run the script as administrator to remove the scheduled task!" -ForegroundColor Red
                    return
                }
                SetConfigValue -propertyName "ScheduledTask" -newValue $false
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                Write-Host "Scheduled task removed." -ForegroundColor Green
            } else {
                SetConfigValue -propertyName "ScheduledTask" -newValue $false
                Write-Host "Scheduled task not found!" -ForegroundColor Red
            }
        }

        # Open the script folder (Located in Documents -> Yim-AutoUpdater)
        function OpenScriptFolder {
            if (Test-Path $scriptFolderPath) {
                Invoke-Item $scriptFolderPath
            } else {
                Write-Host "Script folder not found" -ForegroundColor Red
                Write-Host "Creating script folder..." -ForegroundColor Yellow
                New-Item -Path $scriptFolderPath -ItemType Directory
                Write-Host "Script folder created" -ForegroundColor Green
                Write-Host "Opening script folder..."
                Invoke-Item $scriptFolderPath
            }
        }

        # Display the current config in scripts folder
        function DisplayConfig {
            Write-Host "`nConfig:" -ForegroundColor Cyan
            # Convert json to readable format
            $config = Get-Content $configFile | ConvertFrom-Json
            $config.PSObject.Properties | ForEach-Object {
                Write-Host ("{0} : {1}" -f $_.Name, $_.Value)
            }
        }

        function RunAsAdmin {
            # Check if the script is running as admin
            function RunAsAdminCheck {
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
                    y { Clear-Host; RunAsAdminCheck; break }
                    default {Clear-Host; return}
                }
            }
        }

        # Settings Menu choice loop
        while ($true) {
            SettingsOptions
            $choice = Read-Host "`nEnter your choice"
            switch ($choice) {
                1 { Clear-Host; GetYimMenuInfo; break }
                2 { Clear-Host; OpenYimMenuFolder; break }
                3 { Clear-Host; ChangeDownloadLocation; break }
                4 { Clear-Host; ToggleConfigValue -propertyName "CheckAtStartup" -enabledMessage "Checking for YimMenu updates at startup enabled" -disabledMessage "Checking for YimMenu updates at startup disabled"; break }
                5 { Clear-Host; ToggleConfigValue -propertyName "ExitAnywhere" -enabledMessage "Exit keybind anywhere enabled" -disabledMessage "Exit keybind anywhere disabled"; break }
                6 { Clear-Host; ToggleConfigValue -propertyName "RestartAnywhere" -enabledMessage "Restart keybind anywhere enabled" -disabledMessage "Restart keybind anywhere disabled"; break }
                7 { Clear-Host; ToggleConfigValue -propertyName "TitleArt" -enabledMessage "Big Title Art enabled" -disabledMessage "Big Title Art disabled"; break }
                8 { Clear-Host; ToggleConfigValue -propertyName "SoundEffects" -enabledMessage "Sound effects enabled" -disabledMessage "Sound effects disabled"; break }
                9 { Clear-Host; ToggleConfigValue -propertyName "DebugInfo" -enabledMessage "Debug info enabled" -disabledMessage "Debug info disabled"; break }
                10 { Clear-Host; ToggleConfigValue -propertyName "CheckLuaAtStartup" -enabledMessage "Checking for Lua updates at startup enabled" -disabledMessage "Checking for Lua updates at startup disabled"; break }
                11 { Clear-Host; ToggleConfigValue -propertyName "ScanLuaAtStartup" -enabledMessage "Scanning for Lua scripts at startup enabled" -disabledMessage "Scanning for Lua scripts at startup disabled"; break }
                12 { Clear-Host; ToggleConfigValue -propertyName "SkipDisabledLuaUpdates" -enabledMessage "Skipping updates for disabled Lua scripts enabled" -disabledMessage "Skipping updates for disabled Lua scripts disabled"; break }
                13 { Clear-Host; SetInjectionDelay; break }
                14 { Clear-Host; ToggleConfigValue -propertyName "AutoLaunchGTAV" -enabledMessage "Auto launch GTAV enabled" -disabledMessage "Auto launch GTAV disabled"; break }
                15 { Clear-Host; SetPlatform; break }
                16 { Clear-Host; ToggleConfigValue -propertyName "CloseAfterInjection" -enabledMessage "Close after injection enabled" -disabledMessage "Close after injection disabled"; break }
                17 { Clear-Host; SetGitHubToken; break }
                18 { Clear-Host; RemoveGitHubToken; break }
                19 { Clear-Host; CreateScheduledTask; break }
                20 { Clear-Host; RemoveScheduledTask; break }
                21 { Clear-Host; OpenScriptFolder; break }
                22 { Clear-Host; DisplayConfig; break }
                23 { Clear-Host; ResetConfig; break }
                24 { Clear-Host; RunAsAdmin; break }
                r { Clear-Host; ReloadScript; break }
                0 { Clear-Host; return }
                default {
                    if ((GetConfigValue("RestartAnywhere") -eq $true) -and ($choice -eq "r" -or $choice -eq "R")) {
                        Clear-Host; ReloadScript; break
                    } elseif ((GetConfigValue("ExitAnywhere") -eq $true) -and ($choice -eq "e" -or $choice -eq "q" -or $choice -eq "E" -or $choice -eq "Q")) {
                        exit
                    } else {
                        Clear-Host; Write-Host "Invalid choice, please try again" -ForegroundColor Red; PlayExclamation
                    }
                }
            }
        }
    }

    function YimMenuLua {
        function GetLuaScripts {
            $jsonList = "https://harmlessdev.xyz/YimMenu-Lua.json"
            $luaScripts = Invoke-RestMethod -Uri $jsonList
            return $luaScripts
        }

        function DisplayLuaScripts {
            $luaScripts = GetLuaScripts
            Write-Host "`n~ " -NoNewline
            Write-Host "YimMenu " -NoNewline -ForegroundColor Blue
            Write-Host "Lua " -NoNewline -ForegroundColor DarkCyan
            Write-Host "Scripts" -NoNewline -ForegroundColor Blue
            Write-Host " ~`n"
            Write-Host "Please select a script to download:" -ForegroundColor Cyan
            $i = 1
            foreach ($script in $luaScripts) {
                Write-Host "`n($i) $($script.name) " -ForegroundColor Green -NoNewline
                Write-Host "by " -NoNewline
                Write-Host "$($script.creator)" -ForegroundColor Yellow
                Write-Host "Description: " -ForegroundColor DarkCyan -NoNewline
                Write-Host "$($script.description)"
                Write-Host "`nRepo URL: $($script.repo_url)"
                if ($script.libfiles) {
                    Write-Host "Libraries:"
                    foreach ($libfile in $script.libfiles) {
                        Write-Host "  - Name: $($libfile.name) by $($libfile.creator)"
                        Write-Host "    Description: $($libfile.description)"
                        Write-Host "    Lib URL: $($libfile.lib_url)"
                    }
                }
                $i++
            }
            Write-Host "`n(0) Go Back" -ForegroundColor Magenta
        }
        DisplayLuaScripts

        function GetSHA1 {
            #TODO: Implement SHA1 hash function
        }

        while ($true) {
            $luaScripts = GetLuaScripts
            $choice = Read-Host "`nEnter your choice"
            switch ($choice) {
                0 { Clear-Host; return }
                default {
                    if ($choice -ge 1 -and $choice -le $luaScripts.Count) {
                        try {
                            $script = $luaScripts[$choice - 1]
                            $scriptName = $script.name
                            $scriptURL = $script.script_url
                            $scriptSha = GetSHA1
                            Write-Host "`nDownloading $scriptName..." -ForegroundColor Yellow
                            Invoke-WebRequest -Uri $scriptURL -OutFile "$yimMenuPath\scripts\$scriptName.lua"
                            # If script has libraries, download them too
                            if ($script.libfiles) {
                                foreach ($libfile in $script.libfiles) {
                                    $libName = $libfile.name
                                    $libURL = $libfile.lib_url
                                    Write-Host "`nDownloading $libName..." -ForegroundColor Yellow
                                    Invoke-WebRequest -Uri $libURL -OutFile "$yimMenuPath\scripts\$libName.lua"
                                }
                            }
                            Write-Host "Download completed." -ForegroundColor Green
                            Write-Host "SHA1: $scriptSha" -ForegroundColor Cyan
                        } catch {
                            PlayExclamation
                            Write-Host "Failed to download the script" -ForegroundColor Red
                        }
                    } else {
                        Clear-Host
                        Write-Host "Invalid choice, please try again" -ForegroundColor Red
                    }
                }
            }
        }
    }

    function HelpMenu {
        function HelpMenuOptions {
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
            Write-Host " - Get info about the latest version of YimMenu and its hashes."
            Write-Host "`n2. Create a Scheduled Task [Toggle]" -ForegroundColor Red
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
            Write-Host "`n7. Check for updates at startup [Toggle]" -ForegroundColor Red
            Write-Host " - Every time the script is launched, it checks for YimMenu updates."
            Write-Host "`n8. Exit keybind (e/q) anywhere [Toggle]" -ForegroundColor Red
            Write-Host " - Allows you to exit the script by pressing 'e/E' or 'q/Q' anywhere in the running script."
            Write-Host "`n9. Restart keybind (r) anywhere [Toggle]" -ForegroundColor Red
            Write-Host " - Allows you to restart the script by pressing 'r/R' anywhere in the running script."
            Write-Host "`n10. Sound effects [Toggle]" -ForegroundColor Red
            Write-Host " - Enables/Disables Windows sound effects (Example: Exclamation sound on invalid input)."
            Write-Host "`n11. Debug Info [Toggle]" -ForegroundColor Red
            Write-Host " - Enables/Disables debug info (Currently not used)."
            Write-Host "`n12. Reset config" -ForegroundColor Red
            Write-Host " - Resets the config file to default values."
            Write-Host "`n13. Run As Administrator" -ForegroundColor Red
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
            HelpMenuOptions
            Write-Host "`n(0) Go Back: " -ForegroundColor Magenta -NoNewline
            $choice = Read-Host
            switch ($choice) {
                0 { Clear-Host; return }
                default {Clear-Host}
            }
        }
    }

    function DLLinject {
        function MainInjection {
            # Load the necessary functions
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class Injector {
    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("kernel32", CharSet = CharSet.Ansi, ExactSpelling = true, SetLastError = true)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);

    [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out int lpNumberOfBytesWritten);

    [DllImport("kernel32.dll")]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
}
"@ -Language CSharp

            # Wait for GTA5.exe process to start
            while (-not (Get-Process -Name "GTA5" -ErrorAction SilentlyContinue)) {
                for ($i = 1; $i -le 3; $i++) {
                    Write-Host ("Waiting for GTA5.exe to start" + "." * $i)
                    Start-Sleep -Seconds 1
                    Clear-Host
                }
            }

            $injectionDelay = [int](GetConfigValue("InjectionDelay"))
            for ($i = $injectionDelay; $i -ge 0; $i -= 1000) {
                Clear-Host
                Write-Host "Waiting $i ms before injecting the DLL..." -ForegroundColor Yellow
                Start-Sleep -Milliseconds 1000
            }

            # Get GTA5.exe process ID
            $procId = (Get-Process -Name "GTA5").Id
            # Get handle
            $procHandle = [Injector]::OpenProcess(0x1F0FFF, $false, $procId)
            # Get handle to kernel32
            $loadLibAddr = [Injector]::GetProcAddress([Injector]::GetModuleHandle("kernel32.dll"), "LoadLibraryA")
            # Allocate memory
            $allocMemAddress = [Injector]::VirtualAllocEx($procHandle, [IntPtr]::Zero, 0x1000, 0x3000, 0x40)
            $yimDLLPath = GetConfigValue("DownloadLocation")
            # Write the DLL path to the allocated memory
            $writeMemoryResult = [Injector]::WriteProcessMemory($procHandle, $allocMemAddress, [System.Text.Encoding]::ASCII.GetBytes("$yimDLLPath\yimmenu.dll"), 0x1000, [ref]0)
            # Create a remote thread
            $createThreadResult = [Injector]::CreateRemoteThread($procHandle, [IntPtr]::Zero, 0, $loadLibAddr, $allocMemAddress, 0, [IntPtr]::Zero)

            # Check if the injection was successful
            if ($createThreadResult -eq [IntPtr]::Zero) {
                PlayExclamation
                Write-Host "Injection failed" -ForegroundColor Red
            } else {
                Write-Host "Injection successful" -ForegroundColor Green
                if (GetConfigValue("CloseAfterInjection") -eq $true) {
                    Write-Host "Closing the script in 10 seconds..." -ForegroundColor Yellow
                    Write-Host "Press any button to cancel"
                    for ($i = 0; $i -lt 10; $i++) {
                        if ($Host.UI.RawUI.KeyAvailable) {
                            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                            Clear-Host
                            return
                        }
                        Start-Sleep -Seconds 1
                    }
                    exit
                }
            }
            # Close the handle to the process
            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($procHandle)
        }

        function PlatformChecks {
            # Checks before injecting the DLL
            $autoLaunch = GetConfigValue("AutoLaunchGTAV")
            $platform = GetConfigValue("Platform")

            if ($autoLaunch -eq $true -and $platform -notlike "4") {
                if ($platform -eq "1") { # Steam
                    Write-Host "Starting Steam GTA5..."
                    $uri = "steam://run/271590"
                    Start-Process -FilePath $uri
                    MainInjection
                } elseif ($platform -eq "2") { # Epic Games
                    Write-Host "Starting Epic Games GTA5..."
                    $uri = "com.epicgames.launcher://apps/9d2d0eb64d5c44529cece33fe2a46482?action=launch&silent=true"
                    Start-Process -FilePath $uri
                    MainInjection
                } elseif ($platform -eq "3") { # Rockstar Games Launcher
                    Write-Host "Starting Rockstar Games Launcher GTA5..."
                    $keys = @("HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\GTAV", "HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\Grand Theft Auto V", "HKLM:\SOFTWARE\Rockstar Games\Grand Theft Auto V", "HKLM:\SOFTWARE\Rockstar Games\GTAV")
                    $selfGTAV_dirPath = $null
                    foreach ($key in $keys) {
                        $selfGTAV_dirPath = Get-ItemPropertyValue -Path $key -Name "InstallFolder" -ErrorAction SilentlyContinue
                        if ($selfGTAV_dirPath) { break }
                    }
                    if (-not $selfGTAV_dirPath) {
                        $keysSteam = @("HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\GTAV", "HKLM:\SOFTWARE\Rockstar Games\GTAV", "HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\Grand Theft Auto V", "HKLM:\SOFTWARE\Rockstar Games\Grand Theft Auto V")
                        foreach ($key in $keysSteam) {
                            $selfGTAV_dirPath = Get-ItemPropertyValue -Path $key -Name "InstallFolderSteam" -ErrorAction SilentlyContinue
                            if ($selfGTAV_dirPath) { break }
                        }
                    }
                    Start-Process -FilePath "$selfGTAV_dirPath\PlayGTAV.exe"
                    MainInjection
                }
            } elseif ($autoLaunch -eq $true -and $platform -like "4") { # Auto launch is enabled but no platform is selected
                PlayExclamation
                Write-Host "Auto launch is enabled but no platform is selected. Please select a platform or disable auto launch!" -ForegroundColor Red
            }
        }
        PlatformChecks
    }

    while ($true) {
        Options
        $choice = Read-Host "`nEnter your choice"
        switch ($choice) {
            1 { Clear-Host; CheckForYimUpdates; break }
            2 { Clear-Host; CheckAndDownloadYimUpdates; break }
            3 { Clear-Host; ScriptSettings; break}
            4 { Clear-Host; YimMenuLua; break }
            5 { Clear-Host; DLLinject; break }
            h { Clear-Host; HelpMenu; break }
            0 { exit }
            default {
                if ((GetConfigValue("RestartAnywhere") -eq $true) -and ($choice -eq "r" -or $choice -eq "R")) {
                    Clear-Host; ReloadScript; break
                } elseif ((GetConfigValue("ExitAnywhere") -eq $true) -and ($choice -eq "e" -or $choice -eq "q" -or $choice -eq "E" -or $choice -eq "Q")) {
                    exit
                } else {
                    Clear-Host; Write-Host "Invalid choice, please try again" -ForegroundColor Red; PlayExclamation
                }
            }
        }
    }
}
YimAutoUpdater