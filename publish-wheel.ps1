# publish-wheel.ps1
# Uploads a wheel to the L337-ai build-tools GitHub Pages PyPI index.
#
# Usage:
#   .\publish-wheel.ps1 -WheelPath "C:\_code\wheels\cp311\cryptography-46.0.5-cp311-abi3-win_arm64.whl"
#
# After running, the index is live at:
#   https://l337-ai.github.io/build-tools/simple/

param(
    [Parameter(Mandatory=$true)]
    [string]$WheelPath
)

$repo      = "L337-ai/build-tools"
$baseUrl   = "https://l337-ai.github.io/build-tools"
$wheelName = Split-Path $WheelPath -Leaf
$hash      = (Get-FileHash $WheelPath -Algorithm SHA256).Hash.ToLower()

Write-Host "Publishing $wheelName (sha256=$hash)"

# 1. Upload the wheel binary
$wheelBytes = [IO.File]::ReadAllBytes($WheelPath)
$wheelB64   = [Convert]::ToBase64String($wheelBytes)

# Check if the file already exists (need its sha for updates)
$existing = gh api "repos/$repo/contents/docs/packages/$wheelName" 2>$null | ConvertFrom-Json
$body = @{ message = "publish: $wheelName"; content = $wheelB64 }
if ($existing.sha) { $body.sha = $existing.sha }
$body | ConvertTo-Json | gh api "repos/$repo/contents/docs/packages/$wheelName" --method PUT --input -

# 2. Update docs/simple/cryptography/index.html
$cryptoIndex = @"
<!DOCTYPE html>
<html>
  <head><title>Links for cryptography</title></head>
  <body>
    <h1>Links for cryptography</h1>
    <a href="$baseUrl/packages/$wheelName#sha256=$hash">$wheelName</a>
  </body>
</html>
"@
$cryptoBytes = [Text.Encoding]::UTF8.GetBytes($cryptoIndex)
$cryptoB64   = [Convert]::ToBase64String($cryptoBytes)

$existingIdx = gh api "repos/$repo/contents/docs/simple/cryptography/index.html" 2>$null | ConvertFrom-Json
$body = @{ message = "publish: update cryptography index for $wheelName"; content = $cryptoB64 }
if ($existingIdx.sha) { $body.sha = $existingIdx.sha }
$body | ConvertTo-Json | gh api "repos/$repo/contents/docs/simple/cryptography/index.html" --method PUT --input -

# 3. Ensure root index exists
$rootIndex = @"
<!DOCTYPE html>
<html>
  <head><title>L337-ai ARM64 Wheels</title></head>
  <body>
    <h1>L337-ai ARM64 Wheels</h1>
    <a href="cryptography/">cryptography</a>
  </body>
</html>
"@
$rootBytes = [Text.Encoding]::UTF8.GetBytes($rootIndex)
$rootB64   = [Convert]::ToBase64String($rootBytes)

$existingRoot = gh api "repos/$repo/contents/docs/simple/index.html" 2>$null | ConvertFrom-Json
$body = @{ message = "publish: update simple index root"; content = $rootB64 }
if ($existingRoot.sha) { $body.sha = $existingRoot.sha }
$body | ConvertTo-Json | gh api "repos/$repo/contents/docs/simple/index.html" --method PUT --input -

Write-Host ""
Write-Host "Done. Pages index will be live within ~60s at:"
Write-Host "  $baseUrl/simple/"
