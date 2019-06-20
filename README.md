# Manage secure links with OpenResty, Lua and Vault

What's the matter? I never used Lua and I need to protect (in some way) URLs.
Being inspired from [NGINX Secure Link][1] module and
[Nginx-Lua-Anti-Hotlinking-Config][2] project, I decided to write a PoC
to manage secure links. The idea is to have a centralised vault to store
secrets, which are then used by the frontend to generate the secure links
and by the backend to validate them.

[1]: http://nginx.org/en/docs/http/ngx_http_secure_link_module.html
[2]: https://github.com/C0nw0nk/Nginx-Lua-Secure-Link-Anti-Hotlinking

## How secure links are generated

The links will be structured as follows

    http://<DOMAIN>:8080<URI>?t=<TOKEN>&e=<EXPIRATION DATE>

for instance

    http://192.168.240.3:8080/hls/playlist.m3u8?t=ac18ada1ca48664e57e5ebc5c518cbd885f9b85f70c5c4377f573e356abc8621&e=1560871504

`EXPIRATION DATE` is set to `now + 120 seconds` while `TOKEN` is computed as

    SIGNATURE = SHA256(EXPIRATION DATE || URI || SOURCE IP || " " || SIG_SECRET)
    TOKEN = HMAC_SHA256(TOK_SECRET, SIGNATURE )

Both the secrets `SIG_SECRET` and `TOK_SECRET` are fetched from a vault implemented
with [Vault from HashiCorp][3].

[3]: https://www.vaultproject.io

## How to run the PoC

1.  Run the Docker stack

        $ docker-compose up --build

2.  Load the secrets to Vault

        $ cd scripts
        $ ./addsecrets.sh | jq
        {
            "request_id": "9c08d168-17e3-116e-94e3-61b2f8cfe70e",
            "lease_id": "",
            "renewable": false,
            "lease_duration": 0,
            "data": {
                "data": {
                    "sig_secret": "my-signature-secret",
                    "tok_secret": "my-token-secret"
                },
                "metadata": {
                    "created_time": "2019-06-18T16:06:33.1358935Z",
                    "deletion_time": "",
                    "destroyed": false,
                    "version": 2
                }
            },
            "wrap_info": null,
            "warnings": null,
            "auth": null
        }

3.  Generate a secure link (simulation of the frontend behaviour)

        $ cd scripts
        $ ./genseclink.sh
        VAULT IP: 172.18.0.2
        SIG_SECRET: my-signature-secret
        REMOTE ADDRESS: 172.18.0.1
        EXPIRES: 1560874223
        SIGNATURE: 09e25183a75c12bbb769044de009518d8605a914543ad8199940c1ddf643de89
        TOK_SECRET: my-token-secret
        TOKEN: e7397b6c95eea37902e99278858d7081d5a8f4d6ac237d67b9525e1bb0fbd822
        RESTY IP: 172.18.0.3
        http://172.18.0.3:8080/hls/playlist.m3u8?t=e7397b6c95eea37902e99278858d7081d5a8f4d6ac237d67b9525e1bb0fbd822&e=1560874223

4.  Use the link (until valid)

        $ curl "http://172.18.0.3:8080/hls/playlist.m3u8?t=e7397b6c95eea37902e99278858d7081d5a8f4d6ac237d67b9525e1bb0fbd822&e=1560874223"
        #EXTM3U

        #
        # Hey! This seems to be playlist!
        #

5. Once expired (after 120 seconds), you should see something like that

        $ curl "http://172.18.0.3:8080/hls/playlist.m3u8?t=e7397b6c95eea37902e99278858d7081d5a8f4d6ac237d67b9525e1bb0fbd822&e=1560874223"
        <html>
        <head><title>403 Forbidden</title></head>
        <body>
        <center><h1>403 Forbidden</h1></center>
        <hr><center>openresty/1.15.8.1</center>
        </body>
        </html>

## Use the frontend app

1.  Run the stack and load the secrets

        $ docker-compose up -d --build
        $ cd scripts
        $ ./addsecrets.sh

2.  Define in your `/etc/hosts` the aliases for `frontend` and `resty`

        $ cd scripts
        $ ./genaliases.sh | sudo tee -a /etc/hosts
        192.168.16.4 resty
        192.168.16.2 frontend

    If your containers run on a VM or on a remote machine, aliases should be
    defined as follows

        <REMOTE_OR_VM_IP> frontend resty

3. Open your browser and visit

        http://frontend

## References

*   [lua-resty-hmac](https://github.com/jkeys089/lua-resty-hmac)
*   [lua-resty-http](https://github.com/ledgetech/lua-resty-http)
