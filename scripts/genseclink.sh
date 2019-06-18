#!/bin/bash

URI="/hls/playlist.m3u8"

# Obtain the secret from Vault
vault_ip=$(docker inspect --format='{{.NetworkSettings.Networks.secure_link_default.IPAddress}}' vault)
echo "VAULT IP: ${vault_ip}"

sig_secret="$(curl -s --header "X-Vault-Token: my-root-token" \
    http://${vault_ip}:8200/v1/secret/data/seclink \
    | jq --raw-output .data.data.sig_secret)"
echo "SIG_SECRET: ${sig_secret}"

# Generate the secure a link that will expire in 120 seconds
remote_addr=$(docker inspect --format='{{.NetworkSettings.Networks.secure_link_default.Gateway}}' resty)
echo "REMOTE ADDRESS: ${remote_addr}"

expires=$(date -d "today + 120 seconds" +%s)
echo "EXPIRES: ${expires}"

signature=$(echo -n "${expires}${URI}${remote_addr} ${sig_secret}" | openssl sha256 -hex | cut -d" " -f2)
echo "SIGNATURE: ${signature}"

tok_secret="$(curl -s --header "X-Vault-Token: my-root-token" \
    http://${vault_ip}:8200/v1/secret/data/seclink \
    | jq --raw-output .data.data.tok_secret)"
echo "TOK_SECRET: ${tok_secret}"

t=$(echo -n ${signature} | openssl dgst -sha256 -hex -hmac ${tok_secret} | cut -d" " -f2)
echo "TOKEN: ${t}"

resty_ip=$(docker inspect --format='{{.NetworkSettings.Networks.secure_link_default.IPAddress}}' resty)
echo "RESTY IP: ${resty_ip}"

secure_link="http://${resty_ip}${URI}?t=${t}&e=${expires}"
echo "SECURE LINK: ${secure_link}"
