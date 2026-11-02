param(
    [ValidateSet('release', 'profile')][string]$Configuration = 'release',
    [ValidateSet('android-arm64', 'android-arm', 'android-x64')][string]$Architecture = 'android-arm64',
    [ValidatePattern('^\.[a-z][a-z0-9.]*$')][string]$ApplicationIdSuffix = '.videoexperiment'
)

$ErrorActionPreference = 'Stop'
$previousSuffix = $env:MOONFIN_TEST_ID_SUFFIX
$previousName = $env:MOONFIN_TEST_APP_NAME
Push-Location $PSScriptRoot
try {
    # An isolated id is the default so this never replaces the regular app.
    $env:MOONFIN_TEST_ID_SUFFIX = $ApplicationIdSuffix
    $env:MOONFIN_TEST_APP_NAME = 'Moonfin Video Experiment'
    & flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed' }
    $arguments = @(
        'build', 'apk', "--$Configuration",
        '--flavor', 'androidTv', "--target-platform=$Architecture",
        '--dart-define=MOONFIN_FORCE_TV=true',
        '--dart-define=MOONFIN_VIDEO_ONLY=true',
        '--dart-define=DISTRIBUTION_CHANNEL=android_tv_apk'
    )
    if ($Configuration -eq 'release') { $arguments += '--analyze-size' }
    & flutter @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Android TV build failed' }
    $output = Join-Path $PSScriptRoot "artifacts/android-tv-video/$Configuration-$Architecture"
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    $apkPath = Join-Path $output 'moonfin-video-experiment.apk'
    Copy-Item -LiteralPath "build/app/outputs/flutter-apk/app-androidtv-$Configuration.apk" -Destination $apkPath
    $revision = (& git rev-parse HEAD).Trim()
    & "$PSScriptRoot/scripts/measure-apk.ps1" -ApkPath $apkPath -SourceRevision $revision -OutputPath (Join-Path $output 'apk-size.json') | Out-Null
    Write-Host "Created $apkPath"
} finally {
    Pop-Location
    $env:MOONFIN_TEST_ID_SUFFIX = $previousSuffix
    $env:MOONFIN_TEST_APP_NAME = $previousName
}
