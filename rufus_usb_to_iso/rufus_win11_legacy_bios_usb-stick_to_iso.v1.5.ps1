<#
.SYNOPSIS
    Creates a bootable Windows 11 ISO from a customized RUFUS USB installation media.

.DESCRIPTION
    This script converts a RUFUS-created Windows 11 USB installation drive
    into a fully bootable ISO file suitable for virtualization platforms
    such as Hyper-V, Proxmox, VMware, and VirtualBox.

    It preserves any RUFUS customizations (e.g. bypassed TPM, Secure Boot,
    or CPU requirements) and rebuilds the media into a dual-mode ISO
    supporting:

        • Legacy BIOS
    perhaps supporting:
        • UEFI (this is untested)

    The resulting ISO can be used for:
        - Virtual machines
        - Lab environments
        - Backup of customized install media
        - Deployment scenarios

.PARAMETER OutputISO
    (Future implementation)
    Specifies the full path where the ISO file should be created.

.PARAMETER UnattendFile
    (Planned feature)
    Optional path to an unattend.xml file to inject into the ISO.

.EXAMPLE
    PS C:\> .\rufus_win11_legacy_bios_usb-stick_to_iso.v1.5.ps1

    Lists available USB disks, prompts for selection,
    then asks for output ISO path and builds a bootable ISO.

.EXAMPLE
    PS C:\> .\Convert-RufusUsbToIso.ps1
    Enter Disk Number: 1 SanDisk Cruzer Blade
    Enter ISO path: C:\temp\CustomWin11.iso

.REQUIREMENTS

    ✔ A mounted RUFUS Windows 11 USB installation drive
      
    ✔ oscdimg.exe (from Windows ADK Deployment Tools)
      Download here: https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install
      or find it where you found this script

      During installation:
        → Select "Deployment Tools" only

      Typical location:
      C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe

      Copy oscdimg.exe to the same directory as this script.

    ✔ Script must be run as Administrator.

.NOTES
    Author  : Richard Schalander
    Version : 1.5
    Date    : 2026-02-19
    License : GPL-3.0 license

    Change Log:
    v1.5  - Improved robocopy reliability
          - Enhanced boot file validation
#>


Write-Host "=== Custom Windows 11 (Legacy BIOS) USB -> ISO Creator ===" -ForegroundColor Cyan

# ---- CONFIG ----
$oscdimg = Join-Path $PSScriptRoot "oscdimg.exe"
$tempFolder = "C:\ISO_BUILD"

# Verify oscdimg exists
if (!(Test-Path $oscdimg)) {
    Write-Host "ERROR: oscdimg.exe not found at path:" -ForegroundColor Red
    Write-Host $oscdimg
    exit
}

# List USB disks
Get-Disk | Where-Object {$_.BusType -eq "USB"} | Format-Table -AutoSize

$diskNumber = Read-Host "Enter the Disk Number of your USB"

$usbVolume = Get-Partition -DiskNumber $diskNumber |
             Get-Volume |
             Where-Object {$_.DriveLetter -ne $null}

if (!$usbVolume) {
    Write-Host "ERROR: Could not detect mounted USB volume." -ForegroundColor Red
    exit
}

$driveLetter = $usbVolume.DriveLetter + ":"
Write-Host "Detected USB Drive: $driveLetter"

$outputISO = Read-Host "Enter full path for new ISO (example C:\Temp\CustomWin11.iso)"

# Clean previous temp folder
if (Test-Path $tempFolder) {
    Remove-Item $tempFolder -Recurse -Force
}

New-Item -ItemType Directory -Path $tempFolder | Out-Null

Write-Host "Copying files from USB..."
# robocopy $driveLetter $tempFolder /E /NFL /NDL /NJH /NJS /XD "System Volume Information"
robocopy $driveLetter $tempFolder /E /R:0 /W:0 /NFL /NDL /NJH /NJS /XD "System Volume Information"


if ($LASTEXITCODE -ge 8) {
    Write-Host "ERROR: Robocopy failed." -ForegroundColor Red
    exit
}

# Verify boot files exist
$bootFile = "$tempFolder\boot\etfsboot.com"

if (!(Test-Path $bootFile)) {
    Write-Host "ERROR: etfsboot.com not found. This is required for BIOS boot." -ForegroundColor Red
    exit
}

$biosBoot = "$tempFolder\boot\etfsboot.com"
$uefiBoot = "$tempFolder\efi\microsoft\boot\efisys.bin"

if (!(Test-Path $biosBoot)) {
    Write-Host "ERROR: BIOS boot file etfsboot.com not found." -ForegroundColor Red
    exit
}

if (!(Test-Path $uefiBoot)) {
    Write-Host "ERROR: UEFI boot file efisys.bin not found." -ForegroundColor Red
    exit
}

# ISO build section
Write-Host "Building BIOS bootable ISO..."

$bootData = "2#p0,e,b`"$biosBoot`"#pEF,e,b`"$uefiBoot`""

$arguments = @(
    "-m",
    "-o",
    "-u2",
    "-udfver102",
    "-bootdata:$bootData",
    $tempFolder,
    $outputISO
)

$process = Start-Process -FilePath $oscdimg `
                         -ArgumentList $arguments `
                         -Wait `
                         -PassThru `
                         -NoNewWindow

if ($process.ExitCode -ne 0) {
    Write-Host "ERROR: oscdimg failed with exit code $($process.ExitCode)" -ForegroundColor Red
    exit
}

Write-Host "ISO creation complete!" -ForegroundColor Green
Write-Host "ISO saved at: $outputISO"
