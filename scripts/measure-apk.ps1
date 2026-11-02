param(
    [Parameter(Mandatory)][string]$ApkPath,
    [Parameter(Mandatory)][string]$SourceRevision,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$apk = Get-Item -LiteralPath $ApkPath
$zip = [System.IO.Compression.ZipFile]::OpenRead($apk.FullName)
try {
    $entries = @($zip.Entries | ForEach-Object {
        $parts = $_.FullName -split '/'
        $group = if ($parts[0] -eq 'lib') { "lib/$($parts[1])" }
                 elseif ($_.FullName -like 'assets/flutter_assets/assets/*') { "assets/$($parts[3])" }
                 else { $parts[0] }
        [pscustomobject][ordered]@{
            Path = $_.FullName
            Group = $group
            Bytes = $_.Length
            CompressedBytes = $_.CompressedLength
        }
    })
    $groups = @($entries | Group-Object Group | ForEach-Object {
        [pscustomobject][ordered]@{
            Group = $_.Name
            Files = $_.Count
            Bytes = ($_.Group | Measure-Object Bytes -Sum).Sum
            CompressedBytes = ($_.Group | Measure-Object CompressedBytes -Sum).Sum
        }
    } | Sort-Object { $_.CompressedBytes } -Descending)
    $result = [ordered]@{
        SourceRevision = $SourceRevision
        ArtifactName = $apk.Name
        ArtifactBytes = $apk.Length
        ArtifactSha256 = (Get-FileHash -LiteralPath $apk.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        MeasuredAtUtc = [DateTime]::UtcNow.ToString('o')
        Groups = $groups
        NativeLibraries = @($entries | Where-Object { $_.Path -like 'lib/*/*.so' })
    }
} finally {
    $zip.Dispose()
}
$json = $result | ConvertTo-Json -Depth 8
if ($OutputPath) {
    $parent = Split-Path -Parent ([IO.Path]::GetFullPath($OutputPath))
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding utf8
}
$json
