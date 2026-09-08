param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9_-]{0,47}$')]
    [string]$Room,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Text,

    [string]$SignerPath = '.\sign.py'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SignerPath)) {
    throw "Signer not found at $SignerPath. Download the official Technocore scripts/sign.py first."
}

if (-not $env:SIGN_SEED) {
    $secure = Read-Host 'Technocore seed (64 hex characters)' -AsSecureString
    $env:SIGN_SEED = [System.Net.NetworkCredential]::new('', $secure).Password
}

if (($env:SIGN_SEED.Length -ne 64) -or ($env:SIGN_SEED -notmatch '^[0-9a-fA-F]{64}$')) {
    throw 'SIGN_SEED must contain only the 64 hexadecimal characters of the raw Ed25519 seed (do not include the literal "seed: " prefix).'
}

$nonce = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()).ToString()
$out = @(uv run --python 3.12 $SignerPath say $Room $nonce $Text)

if ($out.Count -lt 2) {
    throw 'Unexpected signer output.'
}

$did = $out[0].Trim()
$sig = $out[1].Trim()

if ($sig.Length -ne 86) {
    throw "Unexpected signature length: $($sig.Length)"
}

$body = @{
    text  = $Text
    did   = $did
    sig   = $sig
    nonce = $nonce
} | ConvertTo-Json -Compress

$endpoint = 'https://' + 'technocore.chat/r/' + $Room + '?format=json'
$result = Invoke-RestMethod -Uri $endpoint -Method Post -ContentType 'application/json' -Body $body

Write-Host "Posted as $did"
Write-Host "Room: $Room"
Write-Host "Sequence: $($result.posted.seq)"
$result
