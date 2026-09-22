"""Compile the actual RPC sources and run loopback regressions on macOS (30s cap)."""

from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import time


def main():
    if sys.platform != "darwin":
        raise SystemExit("This regression requires macOS Foundation/Combine and swiftc.")
    swiftc = shutil.which("swiftc")
    if not swiftc:
        raise SystemExit("swiftc was not found; select Xcode before running this regression.")
    suite = Path(__file__).resolve().parent
    root = suite.parents[1]
    deadline = time.monotonic() + 30

    def remaining():
        left = deadline - time.monotonic()
        if left <= 0:
            raise TimeoutError("30-second regression budget exceeded")
        return left

    with tempfile.TemporaryDirectory(prefix="codexpad-connection-") as scratch:
        scratch = Path(scratch)
        executable = scratch / "connection-regression"
        subprocess.run([
            swiftc, "-parse-as-library", "-swift-version", "5",
            "-target", f"{platform.machine()}-apple-macosx13.0",
            str(root / "app/CodexPad/CodexJSON.swift"),
            str(root / "app/CodexPad/CodexRPC.swift"),
            str(suite / "ConnectionRegression.swift"), "-o", str(executable),
        ], check=True, timeout=120)
        # Xcode's first compilation can warm module caches for over 30 seconds.
        # Bound the actual network regression separately from compiler startup.
        deadline = time.monotonic() + 30
        print("Compiled RPC regression; starting loopback fixture", flush=True)
        port_file = scratch / "port"
        fixture = subprocess.Popen([
            sys.executable, str(suite / "fake_websocket.py"), "--port-file", str(port_file),
        ])
        try:
            while not port_file.exists():
                remaining()
                if fixture.poll() is not None:
                    raise RuntimeError("WebSocket fixture exited before listening")
                time.sleep(0.025)
            port = int(port_file.read_text(encoding="ascii"))
            print("Fixture ready; running RPC regression", flush=True)
            subprocess.run([str(executable), str(port)], check=True, timeout=remaining())
        finally:
            fixture.terminate()
            try:
                fixture.wait(timeout=2)
            except subprocess.TimeoutExpired:
                fixture.kill()
                fixture.wait()


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, TimeoutError, subprocess.SubprocessError) as error:
        raise SystemExit(f"FAIL: {error}") from error
