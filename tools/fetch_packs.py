#!/usr/bin/env python3
"""Download free Quaternius packs from itch.io (CC0) via the public widget flow."""
import json
import re
import sys
import urllib.request

PACKS = [
    "universal-base-characters",
    "universal-animation-library",
    "stylized-nature-megakit",
    "downtown-city-megakit",
]
BASE = "https://quaternius.itch.io"
OUT = "/tmp/claude-0/-root-college-sports-rpg/a5f1b4fb-902e-441b-bb11-7880300fb7ae/scratchpad/packs"


def fetch(url, data=None, cookies=""):
    req = urllib.request.Request(url, data=data, headers={
        "User-Agent": "Mozilla/5.0",
        "Cookie": cookies,
    })
    with urllib.request.urlopen(req, timeout=120) as resp:
        set_cookie = "; ".join(
            v.split(";")[0] for k, v in resp.headers.items() if k.lower() == "set-cookie"
        )
        return resp.read(), set_cookie


for slug in PACKS:
    page, cookies = fetch(f"{BASE}/{slug}")
    csrf = re.search(rb'csrf_token" value="([^"]+)"', page).group(1).decode()
    body = f"csrf_token={urllib.parse.quote(csrf)}".encode()

    dl_page_raw, _ = fetch(f"{BASE}/{slug}/download_url", data=body, cookies=cookies)
    dl_url = json.loads(dl_page_raw)["url"]
    key = dl_url.rsplit("/download/", 1)[1]

    dl_page, _ = fetch(dl_url, cookies=cookies)
    upload_ids = re.findall(rb'data-upload_id="(\d+)"', dl_page)
    if not upload_ids:
        print(f"{slug}: NO UPLOADS FOUND", file=sys.stderr)
        continue

    uid = upload_ids[0].decode()
    cdn_raw, _ = fetch(f"{BASE}/{slug}/file/{uid}?source=game_download",
                       data=body, cookies=cookies)
    cdn = json.loads(cdn_raw)["url"]
    dest = f"{OUT}/{slug}.zip"
    urllib.request.urlretrieve(cdn, dest)
    import os
    print(f"{slug}: {os.path.getsize(dest):,} bytes")
