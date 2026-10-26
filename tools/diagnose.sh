#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROLE="${1:-sender}"
APP_DIR="${OPENAIR_DIAG_APPS:-$ROOT/build/Build/Products/Debug}"
if [[ "$ROLE" == receiver ]]; then
  APP="$APP_DIR/OpenAirDisplay Receiver Dev.app"
  [[ -d "$APP" ]] || { print "Missing diagnostic receiver build: $APP"; exit 1; }
  if pgrep -x "OpenAirDisplay Receiver Dev" >/dev/null; then
    print "Quit OpenAirDisplay Receiver Dev first, then run this command again."; exit 1
  fi
  if lsof -nP -iTCP:9000 -sTCP:LISTEN >/dev/null 2>&1; then
    print "Port 9000 is already in use. Quit the existing receiver before starting the diagnostic receiver."; exit 1
  fi
  open "$APP" --args -SUEnableAutomaticChecks NO -diagnostics YES
  print 'Diagnostic receiver launched. Leave it open; run the sender command on the sending Mac.'
  exit 0
fi
[[ "$ROLE" == sender ]] || { print 'Usage: diagnose.sh sender RECEIVER_IP [SECONDS_PER_PHASE] | receiver'; exit 1; }
HOST="${2:?Supply the receiver IP}"
SECONDS_PER_PHASE="${3:-20}"
[[ "$SECONDS_PER_PHASE" == <-> && "$SECONDS_PER_PHASE" -ge 5 && "$SECONDS_PER_PHASE" -le 120 ]] || { print 'Phase duration must be 5–120 seconds.'; exit 1; }
APP="$APP_DIR/OpenAirDisplay Dev.app"
[[ -d "$APP" ]] || { print "Missing diagnostic sender build: $APP"; exit 1; }
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$HOME/Desktop/OpenAirDisplay-Diagnostics-$STAMP"
mkdir -p "$OUT"
START="$(date +%s)"
if pgrep -x "OpenAirDisplay Dev" >/dev/null; then
  print "Quit OpenAirDisplay Dev first, then run this command again."; exit 1
fi
open "$APP" --args -SUEnableAutomaticChecks NO -diagnostics YES -diagnosticHost "$HOST" -autostart NO
print 'Confirm Screen Recording permission and wait until the receiver shows the desktop.'
read 'REPLY?Press Enter when video is visible: '
START="$(date +%s)"
for PHASE in 'Idle: do not move the mouse' 'Cursor: move the mouse continuously over the receiving display, without dragging' 'Drag: drag a window continuously around the receiving display'; do
  print "\n$PHASE — $SECONDS_PER_PHASE seconds"
  print "$(date -u +%Y-%m-%dT%H:%M:%SZ) $PHASE" >> "$OUT/phases.txt"
  say "${PHASE%%:*}" >/dev/null 2>&1 || true
  sleep "$SECONDS_PER_PHASE"
done
# Let the final aggregate reach the sender.
sleep 3
LOG="$HOME/Library/Logs/OpenAirDisplay Dev/opendisplay.log"
[[ -f "$LOG" ]] || { print "Log not found: $LOG"; exit 1; }
# Export only diagnostic records from this run, not prior log contents.
python3 - "$LOG" "$START" "$OUT/timings.log" <<'PY'
import json, sys
from pathlib import Path
lines = []
for line in Path(sys.argv[1]).read_text(errors='replace').splitlines():
    if 'DIAG {' not in line: continue
    try:
        if json.loads(line.split('DIAG ', 1)[1]).get('time', 0) >= float(sys.argv[2]):
            lines.append(line)
    except (ValueError, TypeError): pass
Path(sys.argv[3]).write_text('\n'.join(lines) + '\n')
PY
python3 "$ROOT/tools/diagnostic-report.py" "$OUT/timings.log" "$START" > "$OUT/report.txt"
cat "$OUT/report.txt"
print "\nSaved: $OUT"
open "$OUT"
