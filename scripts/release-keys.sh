#!/usr/bin/env bash
# One-time setup of the two keys releases are signed with. Run it once, on the maintainer's Mac.
#
#   scripts/release-keys.sh
#
# 1. The Sparkle update key (EdDSA). The public half goes into Resources/SparklePublicKey.txt (commit it);
#    the private half is kept in the login keychain and exported to ~/.taskmaster/sparkle-private.key for the
#    SPARKLE_PRIVATE_KEY repository secret.
# 2. A self-signed code-signing certificate, "Taskmaster Self-Signed". Signing every release with the same
#    certificate keeps the app's identity, and anything macOS has granted it, the same across updates;
#    ad-hoc signatures change with every build. Saved to ~/.taskmaster/taskmaster-signing.p12 for
#    TASKMASTER_CERT_P12.
#
# Keep ~/.taskmaster backed up: without the Sparkle key no future update can be signed, and installed copies
# would need a manual reinstall.
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"

keys="$HOME/.taskmaster"
mkdir -p "$keys"
chmod 700 "$keys"

swift package resolve --disable-sandbox >/dev/null
bin=.build/artifacts/sparkle/Sparkle/bin

if [[ -s Resources/SparklePublicKey.txt ]]; then
    echo "› Sparkle key: already set up (Resources/SparklePublicKey.txt)"
else
    "$bin/generate_keys" --account taskmaster >/dev/null
    "$bin/generate_keys" --account taskmaster -p > Resources/SparklePublicKey.txt
    "$bin/generate_keys" --account taskmaster -x "$keys/sparkle-private.key"
    chmod 600 "$keys/sparkle-private.key"
    echo "› Sparkle key: public half in Resources/SparklePublicKey.txt, private half in $keys/sparkle-private.key"
fi

if [[ -s "$keys/taskmaster-signing.p12" ]]; then
    echo "› Signing certificate: already in $keys/taskmaster-signing.p12"
else
    work=$(mktemp -d)
    cat > "$work/cert.cnf" <<'CNF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = Taskmaster Self-Signed
O = Taskmaster
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF
    openssl req -x509 -newkey rsa:2048 -nodes -days 7300 -config "$work/cert.cnf" \
        -keyout "$work/key.pem" -out "$work/cert.pem" 2>/dev/null
    password=$(openssl rand -base64 24)
    # Algorithms macOS's `security import` understands.
    openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" -name "Taskmaster Self-Signed" \
        -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
        -passout "pass:$password" -out "$keys/taskmaster-signing.p12"
    printf '%s' "$password" > "$keys/taskmaster-signing.password"
    chmod 600 "$keys/taskmaster-signing.p12" "$keys/taskmaster-signing.password"
    rm -rf "$work"
    echo "› Signing certificate: $keys/taskmaster-signing.p12 (password in $keys/taskmaster-signing.password)"
fi

cat <<EOF

Next, add the repository secrets (GitHub › Settings › Secrets and variables › Actions):

  gh secret set SPARKLE_PRIVATE_KEY < "$keys/sparkle-private.key"
  base64 -i "$keys/taskmaster-signing.p12" | gh secret set TASKMASTER_CERT_P12
  gh secret set TASKMASTER_CERT_PASSWORD < "$keys/taskmaster-signing.password"

and commit Resources/SparklePublicKey.txt. To sign local builds the same way, import the certificate:

  security import "$keys/taskmaster-signing.p12" -P "\$(cat "$keys/taskmaster-signing.password")" -T /usr/bin/codesign
EOF
