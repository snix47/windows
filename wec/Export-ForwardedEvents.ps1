#Requires -Version 5.1

<#
.SYNOPSIS
    Daglig export av ForwardedEvents-loggen till extern SMB-share.

.DESCRIPTION
    Scriptet exporterar gårdagens händelser (00:00-23:59) från Windows-loggen
    "ForwardedEvents" till en CSV-fil på en SMB-share. Varje CSV-fil åtföljs av
    en SHA256-checksumfil för integritetskontroll.

    Scriptet placeras på: C:\at\Export-ForwardedEvents.ps1
    Körs via Task Scheduler kl. 01:00 varje natt.

.KONFIGURATION (Export-ForwardedEvents.json)
    Placeras i C:\at\ bredvid scriptet.

    {
      "LogName":      "ForwardedEvents",
      "SmbShare":     "\\\\logsrv01.contoso.local\\weclogs",   <- FQDN-syntax
      "SmbShare":     "\\\\192.168.10.50\\weclogs",            <- IP-syntax
      "OutputFolder": "forwardedevents",
      "FilePrefix":   "ForwardedEvents",
      "DriveLetter":  "W"
    }

    LogName:      Windows-loggens namn. Ändras sällan.
    SmbShare:     UNC-sökväg till share-roten. Dubbla backslashar i JSON.
    OutputFolder: Undermapp på sharen där CSV-filer sparas.
    FilePrefix:   Prefix i filnamnet, t.ex. ForwardedEvents_2026-06-09.csv
    DriveLetter:  Tillfällig enhetsbokstav för SMB-monteringen. Välj en ledig.

.CREDENTIALS (Export-ForwardedEvents-credentials.xml)
    Skapas automatiskt vid första körning — scriptet promptar efter användarnamn
    och lösenord för SMB-sharen och sparar dem krypterat med Windows DPAPI.
    Filen kan bara läsas av samma Windows-användare på samma maskin.
    Kör alltid första gången manuellt som den användare som Task Scheduler-jobbet
    kommer att köras som.

.OUTPUT
    C:\at\ (konfiguration och credentials)
        Export-ForwardedEvents.json
        Export-ForwardedEvents-credentials.xml

    \\logsrv01.contoso.local\weclogs\forwardedevents\ (dagliga exportfiler)
        ForwardedEvents_2026-06-09.csv
        ForwardedEvents_2026-06-09.csv.sha256

.INSTALLATION
    1. Kopiera Export-ForwardedEvents.ps1 och Export-ForwardedEvents.json till C:\at\
    2. Fyll i rätt värden i JSON-filen
    3. Importera scheduled task:
       schtasks /create /xml "Export-ForwardedEvents-import.xml" /tn "Export-ForwardedEvents"
    4. Kör scriptet manuellt som samma användare som tasken för att skapa credentials.xml
#>

$configPath = "C:\at\Export-ForwardedEvents.json"
$credPath   = "C:\at\Export-ForwardedEvents-credentials.xml"
$config     = Get-Content $configPath -Raw | ConvertFrom-Json

# Credentials — skapas vid första körning, läses därefter automatiskt
if (-not (Test-Path $credPath)) {
    Write-Host "Ingen credential-fil hittad. Ange SMB-credentials för $($config.SmbShare):"
    Get-Credential | Export-Clixml -Path $credPath
}
$cred = Import-Clixml -Path $credPath

# Montera SMB-share
$dl = $config.DriveLetter
try {
    if (Get-PSDrive -Name $dl -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name $dl -Force
    }
    New-PSDrive -Name $dl -PSProvider FileSystem -Root $config.SmbShare `
        -Credential $cred -ErrorAction Stop | Out-Null
} catch {
    Write-Error "Kunde inte ansluta till $($config.SmbShare): $_"
    exit 1
}

# Säkerställ att outputmapp finns
$outDir = "${dl}:\$($config.OutputFolder)"
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

# Tidsfilter — gårdagens kalenderdygn 00:00–23:59
$startTime = (Get-Date).Date.AddDays(-1)
$endTime   = (Get-Date).Date
$dateStr   = $startTime.ToString("yyyy-MM-dd")
$fileName  = "$($config.FilePrefix)_$dateStr.csv"
$outFile   = "$outDir\$fileName"
$hashFile  = "$outFile.sha256"

# Hämta händelser
try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName   = $config.LogName
        StartTime = $startTime
        EndTime   = $endTime
    } -ErrorAction Stop
} catch {
    if ($_.Exception.Message -match "No events were found") {
        Write-Host "Inga händelser för $dateStr"
    } else {
        Write-Error "Fel vid hämtning av händelser: $_"
    }
    Remove-PSDrive -Name $dl -Force
    exit 0
}

# Exportera CSV
$events | Select-Object TimeCreated, Id, LevelDisplayName, MachineName, ProviderName, Message |
    Export-Csv $outFile -NoTypeInformation -Encoding UTF8

# SHA256-checksumma
$hash = (Get-FileHash $outFile -Algorithm SHA256).Hash
"$hash  $fileName" | Set-Content $hashFile -Encoding UTF8

Write-Host "$($events.Count) händelser exporterade: $fileName"

Remove-PSDrive -Name $dl -Force
