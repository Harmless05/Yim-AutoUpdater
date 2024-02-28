# Yim-AutoUpdater

This is a simple PowerShell script that will allow you to update your [YimMenu](https://github.com/YimMenu/YimMenu) without having to check for and download a newer version each time.

## How to use it

All you have to do is to run the `Yim-AutoUpdater.ps1` by **Right Clicking** on it and selecting `"Run with PowerShell"` or open a PowerShell window and run the script.

The script will check for the latest version of YimMenu and download it if it's not already installed.

## I got an error

If you get an error when you run the script, such as `"\yim-autoupdater.ps1 cannot be loaded because running scripts is disabled on this system"`, you can fix this by running the following command in PowerShell:

### Change the Execution Policy Temporarily

You can change the execution policy only for the current PowerShell session. It does not affect the system-wide execution policy:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Change the Execution Policy Permanently

You can permanently change the run policy for all PowerShell sessions. Open a PowerShell window with the 'Run as administrator' option selected, and run:

```powershell
Set-ExecutionPolicy RemoteSigned
```

### Bypass Execution Policy at Run-time

You can also bypass the execution policy at run-time with this command:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\FILE\LOCATION\Yim-AutoUpdater.ps1"
```

## NB! :warning:
These setting enables the execution of both locally written unsigned scripts and signed scripts from the internet.

:warning: **These changes are permanent.**  To return to the default setting, run:

```powershell
Set-ExecutionPolicy Restricted
```

## Feedback

If you have any feedback or suggestions, feel free to open an issue on the [GitHub Yim-AutoUpdater Issues](https://github.com/Harmless05/Yim-AutoUpdater/issues) page.

## Download the latest version

You can download the latest version of Yim-AutoUpdater from the [Releases](https://github.com/Harmless05/Yim-AutoUpdater/releases/latest) page.

# Future ideas

- [ ] Check for updates on a schedule
- [ ] Check for updates on startup
- [ ] Change download location
- [ ] Don't replace the old version (keep both)
