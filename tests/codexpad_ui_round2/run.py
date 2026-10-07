"""Compile actual Foundation reading sources and run native Swift regressions."""

from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main() -> int:
    swiftc = shutil.which("swiftc")
    if not swiftc:
        print("NOT RUN: swiftc was not found; this suite needs a native Swift toolchain.", file=sys.stderr)
        return 2

    suite = Path(__file__).resolve().parent
    root = suite.parents[1]
    sources = [
        root / "app/CodexPad/CodexDiffModels.swift",
        root / "app/CodexPad/CodexFilePreview.swift",
        root / "app/CodexPad/CodexCodeRendering.swift",
        suite / "ReadingRegression.swift",
    ]
    missing = [str(path) for path in sources if not path.is_file()]
    if missing:
        print("FAIL: missing regression inputs: " + ", ".join(missing), file=sys.stderr)
        return 1

    # No UIKit, SwiftUI, simulator, RPC, model call or connected device is used.
    # Compile production sources rather than a translated/mocked parser.
    with tempfile.TemporaryDirectory(prefix="codexpad-reading-") as scratch:
        executable = Path(scratch) / ("reading-regression.exe" if sys.platform == "win32" else "reading-regression")
        command = [
            swiftc, "-parse-as-library", "-swift-version", "5",
            *map(str, sources), "-o", str(executable),
        ]
        print("Compiling native Foundation reading regressions", flush=True)
        subprocess.run(command, check=True, timeout=120)
        print("Running native reading assertions", flush=True)
        subprocess.run([str(executable)], check=True, timeout=30)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, subprocess.SubprocessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1) from error
