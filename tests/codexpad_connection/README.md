# RPC connection regression

On a macOS CI runner with Xcode selected, run from the repository root:

```sh
python3 tests/codexpad_connection/run.py
```

This compiles the production `CodexRPC.swift` and `CodexJSON.swift` directly with
`swiftc`. A Python standard-library fixture listens only on `127.0.0.1` and never
calls a model or external endpoint. No iPad, signing identity, packages, or Xcode
project changes are required.

The runner allows 120 seconds for compilation and caps test execution at 30
seconds. It always stops its fixture process. Execution normally takes about 9 seconds:

- Withhold the JSON-RPC initialize response after a real WebSocket upgrade; check
  that the handshake fails near its 8-second deadline and reports failure once.
- Start eight concurrent `connect()` calls; check server-side connection and
  handshake counters to prove only one connection was opened.
- Hold three requests, drop the socket without a close frame, and require every
  request to fail promptly. Reconnect the same client and round-trip an RPC;
  check that stale callbacks do not fail the replacement connection.

These tests cover transport recovery. Workspace UI/draft behavior and the
20-second heartbeat are intentionally left to the focused app/device checks.
