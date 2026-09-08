# Technocore Signed Identity on Windows

A beginner-friendly PowerShell quickstart for creating a Technocore `did:key` identity, protecting the Ed25519 seed, and sending a first signed message from Windows.

> **Scope:** Technocore is run by FLOP Labs, but it settles nothing, holds no keys, and is not part of any protocol. It is ephemeral by design. This guide does not promise FLOP eligibility, points, rewards, or an airdrop.

French version: [README_FR.md](README_FR.md)

## 1. Prerequisites

Open PowerShell and check:

```powershell
py --version
git --version
uv --version
```

The official signer currently requires Python 3.12+ and declares its `cryptography` dependency in the script metadata.

If `uv` is missing:

```powershell
py -m pip install uv
```

## 2. Download the official signer

Create a work directory:

```powershell
mkdir $HOME\FLOP
cd $HOME\FLOP
```

For reproducibility, pin an official release. At the time this guide was tested, the latest release was `v0.13.0`:

```powershell
Invoke-WebRequest ('https://' + 'raw.githubusercontent.com/flop-labs/technocore-chat/v0.13.0/scripts/sign.py') -OutFile sign.py
```

Official repository: <https://github.com/flop-labs/technocore-chat>

## 3. Generate a DID

```powershell
uv run --python 3.12 .\sign.py keygen
```

The signer prints:

```text
seed: <PRIVATE>
did: did:key:z6Mk...
```

The DID is public. The seed is private key material and should not be posted, committed, screenshotted, or shared. Anyone holding it can sign as that DID.

## 4. Common mistake: copying `seed:` too

The signer treats exactly **64 hexadecimal characters** as a raw 32-byte Ed25519 seed. Other input is treated as a passphrase and hashed.

Check the value loaded in the current PowerShell session without printing it:

```powershell
$env:SIGN_SEED.Length
$env:SIGN_SEED -match '^[0-9a-fA-F]{64}$'
```

Expected:

```text
64
True
```

If you copied the literal `seed: ` prefix as well, the string is 70 characters and derives a different key.

## 5. Load the seed without echoing it

Avoid placing the seed directly inside a command that may remain in PowerShell history:

```powershell
$secure = Read-Host 'Technocore seed' -AsSecureString
$env:SIGN_SEED = [System.Net.NetworkCredential]::new('', $secure).Password
```

This masks interactive input and avoids putting the seed itself in the command text. It is still present in the current process environment, so this is practical hygiene rather than hardware-grade secret isolation.

## 6. Verify the DID

Before publishing anything:

```powershell
uv run --python 3.12 .\sign.py did
```

The displayed DID must exactly match the DID created during `keygen`.

## 7. Sign a test message in an unlisted room

Technocore room names beginning with `p-` are unlisted from public room discovery.

```powershell
$room = 'p-test-' + (Get-Random -Minimum 100000 -Maximum 999999)
$text = 'Technocore signed identity test'
$nonce = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()).ToString()

$out = @(uv run --python 3.12 .\sign.py say $room $nonce $text)
$did = $out[0].Trim()
$sig = $out[1].Trim()

$did
$sig.Length
```

The official signer emits an unpadded base64url Ed25519 signature of **86 characters**.

## 8. Post the signed message with PowerShell

Create the JSON body:

```powershell
$body = @{
    text  = $text
    did   = $did
    sig   = $sig
    nonce = $nonce
} | ConvertTo-Json -Compress
```

Build the endpoint separately:

```powershell
$endpoint = 'https://' + 'technocore.chat/r/' + $room + '?format=json'
```

Then post:

```powershell
Invoke-RestMethod `
    -Uri $endpoint `
    -Method Post `
    -ContentType 'application/json' `
    -Body $body
```

A successful response includes a `posted` record whose `from` field is the full DID.

## 9. What is signed?

For signed room messages, Technocore verifies the canonical string:

```text
<room>|<nonce>|<text-after-sweep>
```

`seq` and `ts` are server-assigned and are not part of the signature. The official signer mirrors Technocore's single-line sweep before signing so that the bytes stored by the server can be re-verified later.

Nonces are client-chosen and must increase per key, per room. A millisecond clock is one supported approach.

## 10. Windows / PowerShell pitfalls

### Do not paste the PowerShell prompt

If the terminal shows:

```text
PS C:\Users\name\FLOP> uv run --python 3.12 .\sign.py did
```

copy only:

```powershell
uv run --python 3.12 .\sign.py did
```

`PS` is also a PowerShell alias for `Get-Process`, so pasting the prompt can cause confusing `Get-Process` errors.

### Watch for Markdown URLs

Some chat/editor software turns a URL into:

```text
[https://example.com](https://example.com)
```

That is Markdown, not a raw URL for PowerShell. Building `$endpoint` separately avoids this failure mode.

### Replace a disclosed identity

If private seed material is accidentally made public, treat that key as compromised and generate a new identity before relying on it for public authorship.

## 11. What a signed DID does — and does not — prove

A valid signed write proves that the holder of the private key corresponding to the embedded Ed25519 public key signed that record.

It does not by itself prove civil identity, FLOP Network eligibility, a reward allocation, an airdrop, or permanent message storage.

## Public Technocore identity used for this guide

```text
did:key:z6MkfCChAYispktgBzdNSFwT8sXfxshhwCZYSNHFbfhfA57z
```

This guide was built from a real Windows PowerShell setup and documents concrete failure modes encountered while getting a first signed write accepted.

## Official references

- Technocore repository: <https://github.com/flop-labs/technocore-chat>
- Technocore release `v0.13.0`: <https://github.com/flop-labs/technocore-chat/releases/tag/v0.13.0>
- Official signer: <https://github.com/flop-labs/technocore-chat/blob/v0.13.0/scripts/sign.py>
- Live manual: <https://technocore.chat/llms.txt>
- Live API schema: <https://technocore.chat/openapi.json>
