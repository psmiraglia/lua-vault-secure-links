from flask import Flask
from flask import request

import datetime
import hashlib
import hmac
import requests
import os


URI = "/hls/playlist.m3u8"


def _expires():
    now = datetime.datetime.now()
    app.logger.debug("NOW: %s", str(now))
    delta = datetime.timedelta(minutes=2)
    app.logger.debug("EXPIRES: %s", str(now + delta))
    expires = (now + delta).strftime("%s")
    return expires


def _secrets():
    headers = {"X-Vault-Token": "my-root-token"}
    vault_url = (("http://%s:8200/v1/secret/data/seclink") %
                 (os.getenv("VAULT_HOST", "vault")))
    r = requests.get(vault_url, headers=headers)
    secrets = r.json()["data"]["data"]
    return secrets["sig_secret"], secrets["tok_secret"]


def seclink(req):
    sig_secret, tok_secret = _secrets()
    app.logger.debug("SECRETS: %s, %s", sig_secret, tok_secret)

    remote_addr = req.remote_addr
    app.logger.debug("REMOTE ADDR: %s", remote_addr)

    expires = _expires()

    # generate signature
    s = "%s%s%s %s" % (expires, URI, remote_addr, sig_secret)
    signature = hashlib.sha256(bytes(s, 'utf-8')).hexdigest()

    # generate token
    token = hmac.new(bytes(tok_secret, 'utf-8'),
                     bytes(signature, 'utf-8'),
                     hashlib.sha256).hexdigest()
    # generate secure link
    link = (("http://%s:8080%s?t=%s&e=%s") %
            (os.getenv("BACKEND_HOST", "resty"), URI, token, expires))
    return link, expires, remote_addr


app = Flask(__name__)


@app.route("/")
def index():
    link, expires, remote_addr = seclink(request)
    return '''
    <a href="%s">secure link</a> (<tt>%s</tt>)
    <p>it works if you call it from <strong>%s</strong> and will expire in
        <strong><span id="cd"></span><strong></p>
    <script>
        var countDownDate = new Date(%s * 1000).getTime();
        var x = setInterval(function() {
            var now = new Date().getTime();
            var distance = countDownDate - now;
            var days = Math.floor(distance / (1000 * 60 * 60 * 24));
            var hours = Math.floor(
                (distance %% (1000 * 60 * 60 * 24)) / (1000 * 60 * 60)
            );
            var minutes = Math.floor(
                (distance %% (1000 * 60 * 60)) / (1000 * 60)
            );
            var seconds = Math.floor((distance %% (1000 * 60)) / 1000);

            document.getElementById("cd").innerHTML = days + "d " + hours
                + "h " + minutes + "m " + seconds + "s ";

            if (distance < 0) {
                clearInterval(x);
                document.getElementById("cd").innerHTML = "EXPIRED";
            }
        }, 1000);
    </script>
    ''' % (link, link, remote_addr, expires)
