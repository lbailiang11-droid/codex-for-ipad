"""Loopback-only WebSocket fault fixture. No packages or model API calls."""

import argparse
import base64
import hashlib
import json
from pathlib import Path
import socket
import struct
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class FixtureServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self):
        super().__init__(("127.0.0.1", 0), FixtureHandler)
        self.lock = threading.Lock()
        self.stats = {
            path: dict(connections=0, initialize=0, initialized=0, pending=0)
            for path in ("normal", "silent")
        }

    def increment(self, path, key):
        with self.lock:
            self.stats[path][key] += 1


class FixtureHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_args):
        pass

    def do_GET(self):
        if self.path in ("/health", "/stats"):
            with self.server.lock:
                body = json.dumps(self.server.stats).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        path = self.path.lstrip("/")
        key = self.headers.get("Sec-WebSocket-Key")
        if path not in self.server.stats or not key:
            self.send_error(404)
            return
        accept = base64.b64encode(hashlib.sha1(
            (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()
        ).digest()).decode()
        self.send_response(101, "Switching Protocols")
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept)
        self.end_headers()
        self.wfile.flush()
        self.server.increment(path, "connections")
        self.close_connection = True
        self.connection.settimeout(20)
        try:
            while True:
                opcode, payload = self.read_frame()
                if opcode == 8:
                    self.write_frame(payload, opcode=8)
                    return
                if opcode == 9:
                    self.write_frame(payload, opcode=10)
                    continue
                if opcode != 1:
                    continue
                message = json.loads(payload)
                method = message.get("method")
                if method == "initialize":
                    self.server.increment(path, "initialize")
                    if path == "silent":
                        continue
                    # Hold the handshake open so concurrent connect() calls overlap.
                    time.sleep(0.3)
                    self.reply(message["id"], {})
                elif method == "initialized":
                    self.server.increment(path, "initialized")
                elif method == "hold":
                    self.server.increment(path, "pending")
                elif method == "close":
                    # No WebSocket close frame or RPC reply: simulate a dead server.
                    self.connection.shutdown(socket.SHUT_RDWR)
                    return
                elif method == "echo":
                    self.reply(message["id"], message.get("params"))
                elif "id" in message:
                    raise ValueError("Unexpected test method")
        except (EOFError, OSError):
            pass

    def read_exact(self, count):
        data = self.rfile.read(count)
        if len(data) != count:
            raise EOFError()
        return data

    def read_frame(self):
        first, second = self.read_exact(2)
        if not first & 0x80 or first & 0x70 or not second & 0x80:
            raise ValueError("Expected a final, masked client frame without extensions")
        size = second & 0x7F
        if size == 126:
            size = struct.unpack("!H", self.read_exact(2))[0]
        elif size == 127:
            size = struct.unpack("!Q", self.read_exact(8))[0]
        if size > 1024 * 1024:
            raise ValueError("Oversized test frame")
        mask = self.read_exact(4)
        payload = self.read_exact(size)
        return first & 0x0F, bytes(value ^ mask[i % 4] for i, value in enumerate(payload))

    def write_frame(self, payload, opcode=1):
        size = len(payload)
        header = bytes((0x80 | opcode, size)) if size < 126 else (
            bytes((0x80 | opcode, 126)) + struct.pack("!H", size)
        )
        self.wfile.write(header + payload)
        self.wfile.flush()

    def reply(self, request_id, result):
        self.write_frame(json.dumps({"id": request_id, "result": result}).encode())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port-file", type=Path, required=True)
    args = parser.parse_args()
    with FixtureServer() as server:
        ready_file = args.port_file.with_suffix(".tmp")
        ready_file.write_text(str(server.server_port), encoding="ascii")
        ready_file.replace(args.port_file)
        server.serve_forever(poll_interval=0.1)


if __name__ == "__main__":
    main()
