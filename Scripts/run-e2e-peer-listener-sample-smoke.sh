#!/bin/bash
# Run the local three-peer peer-listener E2E coordinator sample and validate artifacts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SESSION_ID="${SESSION_ID:-listener-$(date +%Y%m%d-%H%M%S)}"
CONFIG_PATH="$PACKAGE_DIR/Samples/IOSE2ECoordinator/sample-peer-listener-three-peer.yaml"
ARTIFACT_ROOT="$PACKAGE_DIR/.temp/e2e-peer-listener-sample/$SESSION_ID"
LOG_DIR="$PACKAGE_DIR/.temp/e2e-peer-listener-sample-smoke"
RUN_LOG="$LOG_DIR/$SESSION_ID.log"

mkdir -p "$LOG_DIR"

echo "Building e2e-listener-fake-peer..."
DEVELOPER_DIR="$DEVELOPER_DIR" \
xcrun swift build --package-path "$PACKAGE_DIR" --product e2e-listener-fake-peer

echo "Running peer-listener sample session $SESSION_ID..."
DEVELOPER_DIR="$DEVELOPER_DIR" \
xcrun swift run --package-path "$PACKAGE_DIR" ios-e2e-runner \
  --config "$CONFIG_PATH" \
  --session-id "$SESSION_ID" 2>&1 | tee "$RUN_LOG"

echo "Validating peer-listener artifacts..."
python3 - "$ARTIFACT_ROOT" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
summary_path = root / "session-summary.json"
event_log_path = root / "event-log.jsonl"
receipts_path = root / "receipts.jsonl"

for path in [summary_path, event_log_path, receipts_path]:
    if not path.exists():
        raise SystemExit(f"Missing artifact: {path}")

summary = json.loads(summary_path.read_text())
if summary.get("status") != "passed":
    raise SystemExit(f"Unexpected session status: {summary.get('status')}")

peers = {peer["name"]: peer for peer in summary.get("peers", [])}
if set(peers) != {"alpha", "beta", "observer"}:
    raise SystemExit(f"Unexpected peers: {sorted(peers)}")
for name, peer in peers.items():
    if peer.get("status") != 0:
        raise SystemExit(f"Peer {name} failed: {peer.get('status')}")

events = [json.loads(line) for line in event_log_path.read_text().splitlines() if line.strip()]
event_names = {event.get("name") for event in events}
required_events = {"alpha.ready", "beta.observed", "observer.observed", "alpha.completed"}
missing_events = required_events - event_names
if missing_events:
    raise SystemExit(f"Missing events: {sorted(missing_events)}")

alpha_ready = next(event for event in events if event.get("name") == "alpha.ready")
payload = alpha_ready.get("payload", {})
if payload.get("sample") != "peer-listener-coordinator" or payload.get("origin") != "alpha" or payload.get("ready") is not True:
    raise SystemExit(f"Unexpected alpha.ready payload: {payload}")

receipts = [json.loads(line) for line in receipts_path.read_text().splitlines() if line.strip()]
acked = [
    receipt for receipt in receipts
    if receipt.get("eventId") == alpha_ready.get("eventId")
    and receipt.get("state") == "acked"
    and set(receipt.get("ackedBy", [])) == {"beta", "observer"}
]
if not acked:
    raise SystemExit("Missing acked receipt for alpha.ready")

logs = {
    name: (root / "peers" / name / "process.log").read_text()
    for name in ["alpha", "beta", "observer"]
}
if "alpha.ready ackedBy=beta,observer" not in logs["alpha"]:
    raise SystemExit("Missing alpha ack marker")
if "beta observed alpha.ready seq=1" not in logs["beta"]:
    raise SystemExit("Missing beta observation marker")
if "observer observed alpha.ready seq=1" not in logs["observer"]:
    raise SystemExit("Missing observer observation marker")

print(f"Validated peer-listener sample artifacts: {root}")
PY

echo "Peer-listener sample smoke passed."
echo "Artifacts: $ARTIFACT_ROOT"
echo "Run log: $RUN_LOG"
