#!/bin/bash

PAYLOAD="payload.json"
cat > ${PAYLOAD} <<EOF
{
  "data": {
    "sig_secret": "my-signature-secret",
    "tok_secret": "my-token-secret"
  }
}
EOF

vault_ip=$(docker inspect --format='{{.NetworkSettings.Networks.secure_link_default.IPAddress}}' vault)
curl \
    --silent \
    --header "X-Vault-Token: my-root-token" \
    --request POST \
    --data @${PAYLOAD} \
    -o /dev/null \
    http://${vault_ip}:8200/v1/secret/data/seclink

rm -f ./${PAYLOAD}

curl \
    --silent \
    --header "X-Vault-Token: my-root-token" \
    http://${vault_ip}:8200/v1/secret/data/seclink

