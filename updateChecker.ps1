# Scheduled Task Script for Yim-AutoUpdater
# In the background, this script checks for a new version of YimMenu and downloads it if available
# The script is scheduled to run every 30 minutes and at user logon

# You don't need to download this file manually.

# Set the path to the log file to Documents folder
$API_URL = "https://api.github.com/repos/YimMenu/YimMenu/releases/latest"
$DLL_URL = "https://github.com/YimMenu/YimMenu/releases/download/nightly/YimMenu.dll"
#$logFile = "C:\Users\$env:USERNAME\Documents\Yim-AutoUpdater\Yim-AutoUpdater.log"
$ScriptFolderPath = "C:\Users\$env:USERNAME\Documents\Yim-AutoUpdater"
$configFile = Join-Path -Path $ScriptFolderPath -ChildPath "config.json"
$defaultDownloadLocation = "C:\Users\$env:USERNAME\Desktop"
$defaultConfig = @{
    "ConfigVersion" = $configVersion
    "DownloadLocation" = $defaultDownloadLocation
    "ScheduledTask" = $false
    "ScheduledTaskName" = "YimMenu AutoUpdater"
    "LastCheck" = "EmptyDate"
}

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

$downloadLocation = getConfigValue("DownloadLocation")
# Check if the download location exists, if not then set default location
if (-not $downloadLocation) {
    setConfigValue -propertyName "DownloadLocation" -newValue $defaultDownloadLocation
    $downloadLocation = $defaultDownloadLocation
}
$fileName = "YimMenu.dll"
$fullPath = Join-Path -Path $downloadLocation -ChildPath $fileName

# Function to get the hashes of the local and web DLLs
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


# Function to check for a new version of YimMenu and download it if available
function RunUpdateChecker {
    $hashes = getHashes
    # Set the last check date
    setConfigValue -propertyName "LastTaskCheck" -newValue (Get-Date)
    if ($hashes.WebHash -ne $hashes.LocalHash) {
        $wsh = New-Object -ComObject Wscript.Shell
        $result = $wsh.Popup("Do you want to download the latest version of YimMenu?", 0, "A newer version of YimMenu is available!", 68)
        if ($result -eq 6) { # User clicked Yes
            try {
                Remove-Item $fullPath -ErrorAction Stop
            } catch {
                $result = $wsh.Popup("Failed to delete the old version", 0, "Error", 16)
                break
            }
            Invoke-WebRequest -Uri $DLL_URL -OutFile $fullPath
            setConfigValue -propertyName "LastTaskCheck" -newValue (Get-Date)
        }# elseif ($result -eq 7) {}
    } #else {
        #$wsh = New-Object -ComObject Wscript.Shell
        #$result = $wsh.Popup("There are no newer versions of YimMenu available.", 0, "YimMenu is up to date!", 64)
    #}
}
RunUpdateChecker