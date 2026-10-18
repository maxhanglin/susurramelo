#!/usr/bin/env bash
# Creates a local self-signed code-signing identity in the login Keychain (run once per Mac).
# It does not need to be trusted: macOS only needs the same certificate on every build so that
# Keychain access and privacy permissions survive rebuilds.
set -euo pipefail

NAME="${SIGN_IDENTITY:-Susurramelo Local Signing}"
if security find-certificate -c "$NAME" >/dev/null 2>&1; then
    echo "Identity '$NAME' already exists."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cfg" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cfg" \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
PASS="$(openssl rand -hex 16)"
# -legacy: macOS `security` cannot read OpenSSL 3's default PKCS#12 encryption.
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" \
    -out "$TMP/id.p12" -passout "pass:$PASS"
security import "$TMP/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P "$PASS" -T /usr/bin/codesign
echo "Created signing identity '$NAME'."
