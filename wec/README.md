# wec — Windows Event Collector log-export

Daglig export av `ForwardedEvents`-loggen från en Windows WEC-server till extern SMB-share.

## Hur det fungerar

Ett PowerShell-script körs varje natt via scheduled task och exporterar gårdagens
händelser (00:00–23:59) till en CSV-fil på en SMB-share. Varje fil åtföljs av en
SHA256-checksumfil för integritetskontroll.

## Filer

| Fil | Beskrivning |
|-----|-------------|
| `Export-ForwardedEvents.ps1` | Huvudscript |
| `Export-ForwardedEvents.json` | Konfiguration — sökvägar och variabler |
| `Export-ForwardedEvents-import.xml` | Task Scheduler-importfil |
| `Export-ForwardedEvents-credentials.xml` | Krypterad SMB-credential (genereras lokalt, ej i git) |

## Installation

1. Kopiera `Export-ForwardedEvents.ps1` och `Export-ForwardedEvents.json` till `C:\at\`
2. Redigera `Export-ForwardedEvents.json` med rätt sökvägar
3. Importera scheduled task:
   ```
   schtasks /create /xml "Export-ForwardedEvents-import.xml" /tn "Export-ForwardedEvents"
   ```
4. Kör scriptet manuellt **som samma användare som tasken** — du promptas om SMB-credentials
5. Credentials sparas krypterat i `C:\at\Export-ForwardedEvents-credentials.xml`
6. Därefter sköts körningen automatiskt kl. 01:00 varje natt

## Output

```
\\server\share\forwardedevents\ForwardedEvents_2026-06-08.csv
\\server\share\forwardedevents\ForwardedEvents_2026-06-08.csv.sha256
```
