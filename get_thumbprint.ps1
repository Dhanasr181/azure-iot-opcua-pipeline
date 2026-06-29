# PowerShell script to extract certificate thumbprint for Azure IoT Hub

$certPath = ".\certs\device.crt"

if (-not (Test-Path $certPath)) {
    Write-Host "Error: Certificate not found at $certPath" -ForegroundColor Red
    exit 1
}

Write-Host "Extracting certificate thumbprint..." -ForegroundColor Green
Write-Host ""

# Extract SHA1 thumbprint
$thumbprintSha1 = & openssl x509 -in $certPath -noout -fingerprint -sha1 | ForEach-Object { $_ -replace "SHA1 Fingerprint=", "" } | ForEach-Object { $_ -replace ":", "" }
Write-Host "Certificate Thumbprint (SHA1):" -ForegroundColor Yellow
Write-Host $thumbprintSha1
Write-Host ""

# Extract SHA256 thumbprint
$thumbprintSha256 = & openssl x509 -in $certPath -noout -fingerprint -sha256 | ForEach-Object { $_ -replace "SHA256 Fingerprint=", "" } | ForEach-Object { $_ -replace ":", "" }
Write-Host "Certificate Thumbprint (SHA256):" -ForegroundColor Yellow
Write-Host $thumbprintSha256
Write-Host ""

# Save to files
$thumbprintSha1 | Out-File -FilePath ".\certs\thumbprint_sha1.txt" -Encoding ASCII -NoNewline
$thumbprintSha256 | Out-File -FilePath ".\certs\thumbprint_sha256.txt" -Encoding ASCII -NoNewline

Write-Host "✓ Thumbprints saved to .\certs\thumbprint_sha1.txt and .\certs\thumbprint_sha256.txt" -ForegroundColor Green
Write-Host ""
Write-Host "Use this thumbprint in Azure IoT Hub device registration:" -ForegroundColor Cyan
Write-Host $thumbprintSha1 -ForegroundColor Magenta
