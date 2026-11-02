param(
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)]
    [ValidateSet('org.moonfin.androidtv.videobaseline', 'org.moonfin.androidtv.videoexperiment')]
    [string]$PackageName,
    [ValidateRange(1, 20)][int]$Samples = 5,
    [ValidateRange(5, 60)][int]$SettleSeconds = 15,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
function Invoke-Adb {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    $output = & adb -s $Serial @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $($output -join [Environment]::NewLine)" }
    return $output -join [Environment]::NewLine
}

$installed = Invoke-Adb @('shell', 'pm', 'path', $PackageName)
if ($installed -notmatch 'package:') { throw "$PackageName is not installed on $Serial" }
$device = [ordered]@{
    Model = (Invoke-Adb @('shell', 'getprop', 'ro.product.model')).Trim()
    Android = (Invoke-Adb @('shell', 'getprop', 'ro.build.version.release')).Trim()
    Abis = (Invoke-Adb @('shell', 'getprop', 'ro.product.cpu.abilist')).Trim()
}
$samplesTaken = @()
for ($index = 1; $index -le $Samples; $index++) {
    # Stops only the separately installed test package. App data is retained.
    Invoke-Adb @('shell', 'am', 'force-stop', $PackageName) | Out-Null
    $launch = Invoke-Adb @('shell', 'am', 'start', '-W', '-n', "$PackageName/org.moonfin.androidtv.MainActivity")
    if ($launch -notmatch 'Status:\s+ok') { throw "Activity did not start: $launch" }
    Start-Sleep -Seconds $SettleSeconds
    $appPid = (Invoke-Adb @('shell', 'pidof', $PackageName)).Trim()
    if (!$appPid) { throw "$PackageName exited during startup" }
    $memory = Invoke-Adb @('shell', 'dumpsys', 'meminfo', $PackageName)
    $pssMatch = [regex]::Match($memory, 'TOTAL PSS:\s+(\d+)')
    if (!$pssMatch.Success) { $pssMatch = [regex]::Match($memory, '(?m)^\s+TOTAL\s+(\d+)') }
    $totalTime = [regex]::Match($launch, 'TotalTime:\s+(\d+)')
    if (!$totalTime.Success -or !$pssMatch.Success) { throw 'Missing launch-time or PSS measurement' }
    $samplesTaken += [ordered]@{
        Sample = $index
        ActivityTotalTimeMs = [int]$totalTime.Groups[1].Value
        SettledProcessPssKb = [int]$pssMatch.Groups[1].Value
        LaunchOutput = $launch
        MemoryOutput = $memory
    }
    Write-Host "Sample $index/$Samples recorded"
}
$result = [ordered]@{
    MeasuredAtUtc = [DateTime]::UtcNow.ToString('o')
    PackageName = $PackageName
    Device = $device
    SettleSeconds = $SettleSeconds
    Note = 'Activity launch time is not time to actionable Home. Record sign-in, route, cache and renderer state alongside results.'
    Samples = $samplesTaken
}
$parent = Split-Path -Parent ([IO.Path]::GetFullPath($OutputPath))
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "Saved $OutputPath"
