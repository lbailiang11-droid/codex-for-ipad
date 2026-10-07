"""Small GitHub Actions reader; existing Git credentials stay in memory."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import urllib.error
import urllib.parse
import urllib.request


REPOSITORY = "lbailiang11-droid/codex-for-ipad"


def git_executable() -> str:
    executable = os.environ.get("CODEXPAD_GIT") or shutil.which("git")
    if executable:
        return executable
    bundled = Path.home() / ".cache/codex-runtimes/codex-primary-runtime/dependencies/native/git/cmd/git.exe"
    if bundled.is_file():
        return str(bundled)
    raise RuntimeError("Git not found; set CODEXPAD_GIT to its executable path")


def credential() -> str:
    environment = {**os.environ, "GIT_TERMINAL_PROMPT": "0", "GCM_INTERACTIVE": "never"}
    result = subprocess.run(
        [git_executable(), "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n", text=True,
        capture_output=True, check=False, env=environment, timeout=30,
    )
    # Never forward credential helper stdout/stderr into logs.
    values = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    token = values.get("password")
    if result.returncode or not token:
        raise RuntimeError("No existing noninteractive GitHub credential available")
    return token


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(path: str, token: str, *, binary: bool = False, body: dict | None = None):
    if not path.startswith("/repos/") or ".." in path:
        raise ValueError("Only repository API paths are accepted")
    req = urllib.request.Request(
        "https://api.github.com" + path,
        data=json.dumps(body).encode("utf-8") if body is not None else None,
        method="POST" if body is not None else "GET",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "CodexPad-native-ui-validation",
            "Content-Type": "application/json",
        },
    )
    opener = urllib.request.build_opener(NoRedirect())
    try:
        with opener.open(req, timeout=60) as response:
            payload = response.read()
    except urllib.error.HTTPError as error:
        if binary and error.code in (301, 302, 303, 307, 308):
            target = error.headers.get("Location", "")
            parsed = urllib.parse.urlparse(target)
            if parsed.scheme != "https" or not parsed.hostname:
                raise RuntimeError("Unsafe artifact redirect rejected") from None
            # A signed storage URL receives no GitHub Authorization header.
            with urllib.request.urlopen(target, timeout=60) as response:
                return response.read()
        raise RuntimeError(f"GitHub API returned HTTP {error.code} for requested resource") from None
    return payload if binary else json.loads(payload) if payload else {"accepted": True}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["workflows", "runs", "jobs", "artifacts", "logs", "download", "contents", "dispatch"])
    parser.add_argument("--id", type=int)
    parser.add_argument("--branch")
    parser.add_argument("--workflow")
    parser.add_argument("--path")
    parser.add_argument("--ref", default="main")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    base = f"/repos/{REPOSITORY}"
    if args.command == "dispatch":
        if not args.workflow or args.ref == "main":
            parser.error("dispatch requires --workflow and an explicit non-main --ref")
        path = base + "/actions/workflows/" + urllib.parse.quote(args.workflow, safe="") + "/dispatches"
    elif args.command == "workflows":
        path = base + "/actions/workflows?per_page=100"
    elif args.command == "runs":
        suffix = f"/workflows/{urllib.parse.quote(args.workflow, safe='')}/runs" if args.workflow else "/runs"
        query = {"per_page": "10"}
        if args.branch:
            query["branch"] = args.branch
        path = base + "/actions" + suffix + "?" + urllib.parse.urlencode(query)
    elif args.command in ("jobs", "artifacts"):
        if not args.id:
            parser.error("--id must identify the workflow run")
        path = base + f"/actions/runs/{args.id}/{args.command}?per_page=100"
    elif args.command == "logs":
        if not args.id or not args.output:
            parser.error("logs requires job --id and --output")
        path = base + f"/actions/jobs/{args.id}/logs"
    elif args.command == "download":
        if not args.id or not args.output:
            parser.error("download requires artifact --id and --output")
        path = base + f"/actions/artifacts/{args.id}/zip"
    else:
        if not args.path:
            parser.error("contents requires --path")
        path = base + "/contents/" + urllib.parse.quote(args.path, safe="/") + "?ref=" + urllib.parse.quote(args.ref, safe="")
    payload = request(
        path, credential(), binary=args.command in ("logs", "download"),
        body={"ref": args.ref} if args.command == "dispatch" else None,
    )
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(payload, bytes):
            args.output.write_bytes(payload)
        else:
            args.output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(json.dumps({"saved": str(args.output), "bytes": args.output.stat().st_size}))
    else:
        print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired, urllib.error.URLError) as error:
        raise SystemExit(str(error)) from None
