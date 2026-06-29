#!/bin/bash

# Extract certificate thumbprint from device certificate
if [ ! -f /certs/device.crt ]; then
  echo "Error: /certs/device.crt not found"
  exit 1
fi

echo "Extracting certificate thumbprint..."
THUMBPRINT=$(openssl x509 -in /certs/device.crt -noout -fingerprint -sha1 | cut -d= -f2 | tr -d ':')
echo "Certificate Thumbprint (SHA1):"
echo "$THUMBPRINT"

# Also extract SHA256 thumbprint
THUMBPRINT_SHA256=$(openssl x509 -in /certs/device.crt -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':')
echo ""
echo "Certificate Thumbprint (SHA256):"
echo "$THUMBPRINT_SHA256"

# Save to file for reference
echo "$THUMBPRINT" > /certs/thumbprint_sha1.txt
echo "$THUMBPRINT_SHA256" > /certs/thumbprint_sha256.txt
echo ""
echo "✓ Thumbprints saved to /certs/thumbprint_sha1.txt and /certs/thumbprint_sha256.txt"
