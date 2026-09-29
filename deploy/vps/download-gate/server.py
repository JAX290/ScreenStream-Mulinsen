#!/usr/bin/env python3
import html
import json
import mimetypes
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

APK_ROOT = Path(os.environ.get("APK_ROOT", "/srv/apk1")).resolve()
STATE_FILE = Path(os.environ.get("STATE_FILE", "/data/state.json"))
ADMIN_ORIGIN = os.environ.get("ADMIN_ORIGIN", "http://api.mulinsen.win").rstrip("/")
LOCK = threading.Lock()
DEFAULT_STATE = {"mode": "closed", "expires_at": 0, "remaining": 0}


def load_state():
    try:
        data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        if data.get("mode") not in {"closed", "timed", "count", "permanent"}:
            raise ValueError("invalid mode")
        return data
    except (OSError, ValueError, json.JSONDecodeError):
        return dict(DEFAULT_STATE)


def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    temporary = STATE_FILE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, ensure_ascii=False), encoding="utf-8")
    temporary.replace(STATE_FILE)


def normalize_state(state):
    if state["mode"] == "timed" and int(state.get("expires_at", 0)) <= int(time.time()):
        state = dict(DEFAULT_STATE)
        save_state(state)
    elif state["mode"] == "count" and int(state.get("remaining", 0)) <= 0:
        state = dict(DEFAULT_STATE)
        save_state(state)
    return state


def state_snapshot():
    with LOCK:
        return normalize_state(load_state())


def reserve_download():
    with LOCK:
        state = normalize_state(load_state())
        if state["mode"] == "closed":
            return False
        if state["mode"] == "count":
            state["remaining"] = int(state["remaining"]) - 1
            if state["remaining"] <= 0:
                state = dict(DEFAULT_STATE)
            save_state(state)
        return True


def latest_apk():
    candidates = list((APK_ROOT / "latest").glob("*.apk"))
    if not candidates:
        candidates = list(APK_ROOT.glob("**/*.apk"))
    return max(candidates, key=lambda item: item.stat().st_mtime) if candidates else None


def status_text(state):
    mode = state["mode"]
    if mode == "closed":
        return "当前未开放下载"
    if mode == "permanent":
        return "当前永久开放"
    if mode == "count":
        return f"剩余 {int(state['remaining'])} 次下载"
    remaining = max(0, int(state["expires_at"]) - int(time.time()))
    minutes, seconds = divmod(remaining, 60)
    return f"剩余 {minutes} 分 {seconds} 秒"


def page(title, body):
    return f"""<!doctype html><html lang=\"zh-CN\"><meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>{html.escape(title)}</title>
<style>body{{font-family:system-ui;margin:40px auto;max-width:680px;padding:0 18px;color:#202124}}
.card{{border:1px solid #ddd;border-radius:14px;padding:22px}}button,input{{font:inherit;padding:10px;margin:6px}}
button{{cursor:pointer}}.status{{font-size:1.2rem;font-weight:700}}a{{color:#065fd4}}</style>
<body><div class=\"card\"><h1>{html.escape(title)}</h1>{body}</div></body></html>""".encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    server_version = "MulinsenDownloadGate/1.0"

    def send_bytes(self, status, data, content_type="text/html; charset=utf-8"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(data)

    def public_page(self):
        state = state_snapshot()
        apk = latest_apk()
        description = html.escape(status_text(state))
        if state["mode"] == "closed" or apk is None:
            extra = "<p>管理员尚未开放下载，请稍后再试。</p>" if apk else "<p>服务器尚未放置 APK。</p>"
        else:
            relative = apk.relative_to(APK_ROOT).as_posix()
            extra = f'<p><a href="/apk1/{html.escape(relative)}">下载 {html.escape(apk.name)}</a></p>'
        self.send_bytes(200, page("ScreenStream APK 下载", f'<p class="status">{description}</p>{extra}'))

    def admin_page(self, notice=""):
        state = state_snapshot()
        notice_html = f"<p>{html.escape(notice)}</p>" if notice else ""
        body = f"""<p class=\"status\">{html.escape(status_text(state))}</p>{notice_html}
<form method=\"post\" action=\"/download-control\">
<p><button name=\"action\" value=\"close\">立即关闭</button>
<button name=\"action\" value=\"permanent\">永久开放</button></p>
<p><input name=\"minutes\" type=\"number\" min=\"1\" max=\"10080\" value=\"10\">
<button name=\"action\" value=\"timed\">按分钟开放</button></p>
<p><input name=\"count\" type=\"number\" min=\"1\" max=\"10000\" value=\"5\">
<button name=\"action\" value=\"count\">按下载次数开放</button></p></form>
<p><a href=\"http://view.mulinsen.win/apk1\">检查公网下载页</a></p>"""
        self.send_bytes(200, page("APK 下载控制", body))

    def do_GET(self):
        path = unquote(urlparse(self.path).path)
        if path in {"/apk1", "/apk1/"}:
            self.public_page()
            return
        if path in {"/download-control", "/download-control/"}:
            self.admin_page()
            return
        if path.startswith("/apk1/"):
            requested = (APK_ROOT / path.removeprefix("/apk1/")).resolve()
            try:
                requested.relative_to(APK_ROOT)
            except ValueError:
                self.send_error(403)
                return
            if requested.suffix.lower() != ".apk" or not requested.is_file():
                self.send_error(404)
                return
            if not reserve_download():
                self.send_bytes(403, page("下载未开放", "<p>下载入口当前已关闭。</p>"))
                return
            self.send_response(200)
            self.send_header("Content-Type", mimetypes.guess_type(requested.name)[0] or "application/vnd.android.package-archive")
            self.send_header("Content-Disposition", f'attachment; filename="{requested.name}"')
            self.send_header("Content-Length", str(requested.stat().st_size))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            with requested.open("rb") as source:
                while chunk := source.read(1024 * 1024):
                    self.wfile.write(chunk)
            return
        self.send_error(404)

    def do_POST(self):
        if urlparse(self.path).path.rstrip("/") != "/download-control":
            self.send_error(404)
            return
        origin = self.headers.get("Origin")
        if origin and origin.rstrip("/") != ADMIN_ORIGIN:
            self.send_bytes(403, page("请求被拒绝", "<p>控制操作只能从 Tailscale 控制页发起。</p>"))
            return
        try:
            length = min(int(self.headers.get("Content-Length", "0")), 4096)
            form = parse_qs(self.rfile.read(length).decode("utf-8"))
            action = form.get("action", [""])[0]
            with LOCK:
                if action == "close":
                    state = dict(DEFAULT_STATE)
                    notice = "下载已关闭。"
                elif action == "permanent":
                    state = {"mode": "permanent", "expires_at": 0, "remaining": 0}
                    notice = "已永久开放下载。"
                elif action == "timed":
                    value = int(form.get("minutes", ["0"])[0])
                    if not 1 <= value <= 10080:
                        raise ValueError
                    state = {"mode": "timed", "expires_at": int(time.time()) + value * 60, "remaining": 0}
                    notice = f"已开放 {value} 分钟。"
                elif action == "count":
                    value = int(form.get("count", ["0"])[0])
                    if not 1 <= value <= 10000:
                        raise ValueError
                    state = {"mode": "count", "expires_at": 0, "remaining": value}
                    notice = f"已开放 {value} 次下载。"
                else:
                    raise ValueError
                save_state(state)
            self.admin_page(notice)
        except (ValueError, OSError):
            self.send_bytes(400, page("参数错误", "<p>请输入有效的分钟数或下载次数。</p>"))

    def log_message(self, fmt, *args):
        print(f"{self.client_address[0]} - {fmt % args}", flush=True)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
