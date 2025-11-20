<#  v.1.5
 Compresses multiple directoryies into a ZIP file while preserving full paths.
 Generates a .sha256 hash file for integrity checking.

 Scheduler
 powershell.exe
-File "C:\AT\backup-pc.ps1" -ExecutionPolicy Bypass
#>

clear

Add-Type -AssemblyName System.IO.Compression.FileSystem

# Directories to include
$packthis = @(
    "C:\Users\xxxxx\temp",
    "C:\temp",
    "C:\Users\xxxxxx\Desktop"
)

# Target location
$target = "\\servername\share"

# Job name
$jobname = "backup-pc"

# Date in ISO-8601
$today = Get-Date -Format "yyyy-MM-dd"

# Zip filename
$zipfilename = "${today}_${jobname}.zip"
$zipfilepath = Join-Path -Path $target -ChildPath $zipfilename

# Remove old zip file
if (Test-Path $zipfilepath) {
    Remove-Item $zipfilepath -Force
}

# Create empty ZIP
[System.IO.Compression.ZipFile]::Open($zipfilepath, 'Create').Dispose()

foreach ($src in $packthis) {

    Write-Host "Packing: $src"

    # Normalize root (remove drive letter)
    $relativeRoot = $src -replace "^[A-Za-z]:\\", ""

    # Open ZIP for update
    $zip = [System.IO.Compression.ZipFile]::Open($zipfilepath, 'Update')

    # Add all files from directory
    Get-ChildItem -Recurse -File $src | ForEach-Object {

        $fullPath = $_.FullName

        # Convert Windows path → ZIP path
        $entryPath = $fullPath `
            -replace "^[A-Za-z]:\\", "" `
            -replace "\\", "/"

        # Add file to ZIP
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip,
            $fullPath,
            $entryPath,
            [System.IO.Compression.CompressionLevel]::Optimal
        )
    }

    $zip.Dispose()
}

Write-Host "Compression complete. Zip file saved to: $zipfilepath"

# -------------------------------------------------------
#   SHA-256 HASH GENERATION
# -------------------------------------------------------

Write-Host "Generating SHA256 checksum..."

$hashObject = Get-FileHash -Path $zipfilepath -Algorithm SHA256

# SHA256 file name (remove .zip extension)
$hashFilename = [System.IO.Path]::GetFileNameWithoutExtension($zipfilename) + ".sha256"
$hashFile = Join-Path -Path $target -ChildPath $hashFilename

# Format: <hash>  <filename>
$hashLine = "{0}  {1}" -f $hashObject.Hash.ToLower(), $zipfilename

# Save the .sha256 file
Set-Content -Path $hashFile -Value $hashLine -Encoding ASCII

Write-Host "SHA256 hash saved to: $hashFile"
Write-Host "Done."

