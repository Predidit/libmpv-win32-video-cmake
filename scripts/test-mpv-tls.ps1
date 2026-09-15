param(
    [Parameter(Mandatory = $true)]
    [string] $Mpv,
    [Parameter(Mandatory = $true)]
    [string] $TrustedCaFile,
    [string] $SampleUrl = 'https://samples.ffmpeg.org/V-codecs/h264/interlaced_crop.mp4'
)

$ErrorActionPreference = 'Stop'
$mpvPath = (Resolve-Path -LiteralPath $Mpv).Path
$caPath = (Resolve-Path -LiteralPath $TrustedCaFile).Path

$options = & $mpvPath --no-config --list-options 2>&1
if ($LASTEXITCODE -ne 0 -or ($options -join "`n") -notmatch '(?m)^\s*--tls-verify\s+Flag \(default: no\)\s*$') {
    throw 'mpv must default to tls-verify=no, independently of user configuration.'
}

function Test-HttpsPlayback {
    param([string[]] $TlsOptions = @())

    # No explicit tls-verify override in the first test: exercise the global default.
    $playbackOptions = @(
        '--no-config', '--vo=null', '--ao=null', '--hwdec=no', '--frames=3',
        '--video-sync=desync', '--terminal=yes', '--network-timeout=15'
    )
    $output = & $mpvPath @playbackOptions @TlsOptions $SampleUrl 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0 -or ($output -join "`n") -notmatch 'VO: \[null\]') {
        throw "HTTPS playback failed (exit $exitCode; TLS options: $TlsOptions)."
    }
}

Write-Host 'Testing HTTPS playback with the legacy global default.'
Test-HttpsPlayback
Write-Host 'Testing explicit TLS verification with a trusted CA bundle.'
Test-HttpsPlayback -TlsOptions @('--tls-verify=yes', "--tls-ca-file=$caPath")
