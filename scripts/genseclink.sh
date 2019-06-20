#!/bin/bash

URI="/hls/playlist.m3u8"

# Obtain the secret from Vault
vault_ip=$(docker inspect --format='{{.NetworkSettings.Networks.secure_link_default.IPAddress}}' vault)
>&2 echo "VAULT IP: ${vault_ip}"

sig_secret="$(curl -s --header "X-Vault-Token: my-root-token" \
    http://${vault_ip}:8200/v1/secret/data/seclink \
    | jq --raw-output .data.data.sig_secret)"
>&2 echo "SIG_SECRET: ${sig_secret}"

# Generate the secure a link that will expire in 120 seconds
remote_addr=$(docker inspect --format='{{.NetworkSettings.Networks.secure_link_default.Gateway}}' resty)
>&2 echo "REMOTE ADDRESS: ${remote_addr}"

expires=$(date -d "today + 120 seconds" +%s)
>&2 echo "EXPIRES: ${expires}"

signature=$(echo -n "${expires}${URI}${remote_addr} ${sig_secret}" | openssl sha256 -hex | cut -d" " -f2)
>&2 echo "SIGNATURE: ${signature}"

tok_secret="$(curl -s --header "X-Vault-Token: my-root-token" \
    http://${vault_ip}:8200/v1/secret/data/seclink \
    | jq --raw-output .data.data.tok_secret)"
>&2 echo "TOK_SECRET: ${tok_secret}"

t=$(echo -n ${signature} | openssl dgst -sha256 -hex -hmac ${tok_secret} | cut -d" " -f2)
>&2 echo "TOKEN: ${t}"

resty_ip=$(docker inspect --format='{{.NetworkSettings.Networks.secure_link_default.IPAddress}}' resty)
>&2 echo "RESTY IP: ${resty_ip}"

secure_link="http://${resty_ip}:8080${URI}?t=${t}&e=${expires}"
echo ${secure_link}
