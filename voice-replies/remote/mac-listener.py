#!/usr/bin/env python3
# voice-listener — accept WAV bytes over HTTP and play them via afplay.
#
# Lets remote Claude Code sessions (e.g. running on the Jetson) make sound
# come out of this Mac. The remote side does TTS synthesis itself on its own
# localhost and POSTs the resulting WAV here — synthesis bytes cross the
# network once, never twice.
#
# Bind defaults to 0.0.0.0; Tailscale ACL is the practical access boundary.
# Set VOICE_LISTENER_ADDR to a specific IP to restrict further.
#
# Endpoints:
#   POST /play     body = WAV bytes; plays via afplay; 204 on accept
#   GET  /health   200 "ok"

import http.server
import os
import shlex
import socketserver
import subprocess
import sys
import tempfile

LISTEN_ADDR = os.environ.get("VOICE_LISTENER_ADDR", "0.0.0.0")
LISTEN_PORT = int(os.environ.get("VOICE_LISTENER_PORT", "18082"))
MAX_BYTES = 20 * 1024 * 1024  # 20 MB; TTS WAVs are usually <2 MB


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"ok\n")
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path != "/play":
            self.send_error(404)
            return

        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > MAX_BYTES:
            self.send_error(413, "bad or oversized body")
            return

        body = self.rfile.read(length)
        if len(body) < 44:  # minimum WAV header
            self.send_error(400, "body too small to be WAV")
            return

        # Kill any in-flight playback so narrations don't stack
        subprocess.run(["pkill", "-x", "afplay"], check=False)

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(body)
            path = tmp.name

        quoted = shlex.quote(path)
        subprocess.Popen(
            ["sh", "-c", f"afplay {quoted}; rm -f {quoted}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        self.send_response(204)
        self.end_headers()

    def log_message(self, format, *args):
        # Only log errors (4xx/5xx) to keep the journal quiet
        if args and isinstance(args[1], str) and args[1].startswith(("4", "5")):
            sys.stderr.write("%s - %s\n" % (self.address_string(), format % args))


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    server = ThreadedHTTPServer((LISTEN_ADDR, LISTEN_PORT), Handler)
    print(f"voice-listener on {LISTEN_ADDR}:{LISTEN_PORT}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
