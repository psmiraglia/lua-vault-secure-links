local cjson = require "cjson"
local hmac = require "resty.hmac"
local http = require "resty.http"
local sha256 = require "resty.sha256"
local str = require "resty.string"


-- Generate the token
local function _token(expires, uri, remote_addr, sig_s, tok_s)
    local md = sha256:new()
    md:update(expires .. uri .. remote_addr .. " " .. sig_s)
    local signature = str.to_hex(md:final())
    ngx.log(ngx.STDERR, "SIGNATURE: " .. signature)

    local token = hmac:new(tok_s, hmac.ALGOS.SHA256)
    token:update(signature)
    return str.to_hex(token:final())
end


-- Fetch secrets
local function _fetch_secrets(vault_url, vault_token)
    local httpc = http.new()
    local res, err = httpc:request_uri(vault_url, {
        headers = {
            ["X-Vault-Token"] = vault_token
        }
    })

    if not res then
        ngx.say("failed request: ", err)
        return "", ""
    end

    local secrets = cjson.decode(res.body)["data"]["data"]
    return secrets["sig_secret"], secrets["tok_secret"]
end


-- Fetch the secret from a remote vault (e.g. HashiCorp Vault)
local sig_s, tok_s = _fetch_secrets("http://vault:8200/v1/secret/data/seclink", "my-root-token")
ngx.log(ngx.STDERR, "FETCHED SECRETS: " .. sig_s .. ", " .. tok_s)

-- Get the current time
local now = ngx.time()
ngx.log(ngx.STDERR, "NOW: " .. now)

-- Read the expiration time from the query string
local arg_e = ngx.var.arg_e
ngx.log(ngx.STDERR, "EXPIRES: " .. arg_e)

-- Read the signature from the query string
local arg_t = ngx.var.arg_t
ngx.log(ngx.STDERR, "TOKEN: " .. arg_t)

-- Get the remote address
local remote_addr = ngx.var.remote_addr
ngx.log(ngx.STDERR, "REMOTE ADDR: " .. remote_addr)

-- Get the request URI
local uri = ngx.var.uri
ngx.log(ngx.STDERR, "URI: " .. uri)

-- If all the parameters  have a value...
if uri and arg_t and arg_e and tonumber(arg_e) ~= nil then
    -- If the link is still valid...
    if tonumber(arg_e) >= now then
        -- Locally compute the token
        local local_t = _token(arg_e, uri, remote_addr, sig_s, tok_s)
        ngx.log(ngx.STDERR, "COMPUTED TOKEN: " .. local_t)

        -- Compare with the received one
        if arg_t ~= local_t then
            ngx.exit(ngx.HTTP_FORBIDDEN)
        end
    else
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end
else
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

-- vim: filetype=lua
