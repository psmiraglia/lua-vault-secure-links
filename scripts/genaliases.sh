#!/bin/bash

resty_ip=$(docker inspect --format='{{.NetworkSettings.Networks.secure_link_default.IPAddress}}' resty)
frontend_ip=$(docker inspect --format='{{.NetworkSettings.Networks.secure_link_default.IPAddress}}' frontend)

cat <<EOF
${resty_ip} resty
${frontend_ip} frontend
EOF
