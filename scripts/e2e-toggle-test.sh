#!/usr/bin/env bash
# End-to-end test for issues #80 and #82: toggle loop detection + rapid consecutive toggle
# Usage: ./scripts/e2e-toggle-test.sh
#
# Prerequisites:
# - Quickey.app built (./scripts/package-app.sh)
# - Accessibility + Input Monitoring permissions granted to Quickey.app
#
# This script:
# 1. Clears the debug log
# 2. Launches Quickey
# 3. Waits for event tap to start
# 4. Sends a shortcut key via osascript (System Events)
# 5. Monitors the log for toggle loop patterns
# 6. Kills Quickey
# 7. Analyzes the results
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_DIR/build/Quickey.app"
LOG_FILE="$HOME/.config/Quickey/debug.log"
LOG_BACKUP="$HOME/.config/Quickey/debug.log.e2e-backup"
TEST_DURATION=10  # seconds to monitor after shortcut press
LOOP_THRESHOLD=3  # number of MATCHED entries that indicate a loop

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Helpers to avoid repeated tail|grep|tr invocations
log_line_count() { wc -l < "$LOG_FILE" | tr -d ' '; }
count_in_slice() { echo "$1" | grep -c "$2" || true; }

echo "=== Quickey E2E Toggle Loop Test (Issue #80) ==="
echo ""

# Check prerequisites
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}ERROR: Quickey.app not found at $APP_PATH. Run: ./scripts/package-app.sh${NC}"
    exit 1
fi

# Kill any existing Quickey instance
pkill -f "Quickey.app/Contents/MacOS/Quickey" 2>/dev/null || true
sleep 1

# Backup and clear the debug log
if [ -f "$LOG_FILE" ]; then
    cp "$LOG_FILE" "$LOG_BACKUP"
    echo "    Backed up debug.log to debug.log.e2e-backup"
fi
: > "$LOG_FILE"
echo "    Cleared debug.log"

# Launch Quickey
echo ""
echo "==> Launching Quickey.app..."
open "$APP_PATH"

# Wait for event tap to start
echo "    Waiting for event tap to start..."
TAP_STARTED=false
for i in $(seq 1 30); do
    if grep -q "Event tap started" "$LOG_FILE" 2>/dev/null; then
        TAP_STARTED=true
        echo -e "    ${GREEN}Event tap started successfully${NC}"
        break
    fi
    if grep -q "tapCreate.*failed" "$LOG_FILE" 2>/dev/null; then
        echo -e "${RED}ERROR: Event tap creation failed. Check permissions:${NC}"
        echo "    System Settings > Privacy & Security > Accessibility → add Quickey"
        echo "    System Settings > Privacy & Security > Input Monitoring → add Quickey"
        pkill -f "Quickey.app/Contents/MacOS/Quickey" 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

if [ "$TAP_STARTED" = false ]; then
    echo -e "${YELLOW}WARNING: Event tap did not start within 30s. Checking log...${NC}"
    cat "$LOG_FILE"
    echo ""
    echo "You may need to grant permissions manually:"
    echo "    System Settings > Privacy & Security > Accessibility → add Quickey"
    echo "    System Settings > Privacy & Security > Input Monitoring → add Quickey"
    echo "Then re-run this script."
    pkill -f "Quickey.app/Contents/MacOS/Quickey" 2>/dev/null || true
    exit 1
fi

# Record the line count before the test
PRE_LINES=$(log_line_count)
echo ""
echo "==> Sending Safari shortcut (Shift+Cmd+S) via osascript..."
echo "    (Test duration: ${TEST_DURATION}s)"

# Make sure Safari is running
open -a Safari --background 2>/dev/null || true
sleep 1

# Send the shortcut via System Events (osascript goes through session event tap)
osascript -e 'tell application "System Events" to keystroke "s" using {shift down, command down}'

# Monitor the log for the test duration
echo "    Monitoring debug.log for toggle loop patterns..."
sleep "$TEST_DURATION"

# Capture log slice once for consistent counting
POST_LINES=$(log_line_count)
NEW_LINES=$((POST_LINES - PRE_LINES))
LOG_SLICE=$(tail -n "$NEW_LINES" "$LOG_FILE")

MATCHED_COUNT=$(count_in_slice "$LOG_SLICE" "MATCHED:")
BLOCKED_DEBOUNCE=$(count_in_slice "$LOG_SLICE" "DEBOUNCE_BLOCKED")
BLOCKED_COOLDOWN=$(count_in_slice "$LOG_SLICE" "BLOCKED cooldown")
BLOCKED_REENTRY=$(count_in_slice "$LOG_SLICE" "BLOCKED re-entry")
SWALLOW_COUNT=$(count_in_slice "$LOG_SLICE" "EVENT_TAP_SWALLOW")

echo ""
echo "=== Test Results ==="
echo "    New log lines:        $NEW_LINES"
echo "    EVENT_TAP_SWALLOW:    $SWALLOW_COUNT"
echo "    MATCHED:              $MATCHED_COUNT"
echo "    DEBOUNCE_BLOCKED:     $BLOCKED_DEBOUNCE"
echo "    TOGGLE COOLDOWN:      $BLOCKED_COOLDOWN"
echo "    RE-ENTRY BLOCKED:     $BLOCKED_REENTRY"
echo ""

# Show the relevant log entries
echo "=== Log Entries (test window) ==="
echo "$LOG_SLICE" | head -50
echo ""

# Verdict
if [ "$MATCHED_COUNT" -gt "$LOOP_THRESHOLD" ]; then
    echo -e "${RED}FAIL: Toggle loop detected! $MATCHED_COUNT MATCHED entries in ${TEST_DURATION}s${NC}"
    echo "    This indicates the fix did not fully prevent the loop."
    echo ""
    echo "    Defense layers that fired:"
    [ "$BLOCKED_DEBOUNCE" -gt 0 ] && echo "      - Debounce blocked: $BLOCKED_DEBOUNCE events"
    [ "$BLOCKED_COOLDOWN" -gt 0 ] && echo "      - Toggle cooldown blocked: $BLOCKED_COOLDOWN events"
    [ "$BLOCKED_REENTRY" -gt 0 ] && echo "      - Re-entry guard blocked: $BLOCKED_REENTRY events"
    RESULT=1
elif [ "$MATCHED_COUNT" -le 2 ]; then
    echo -e "${GREEN}PASS: No toggle loop detected. $MATCHED_COUNT MATCHED entries in ${TEST_DURATION}s${NC}"
    if [ "$MATCHED_COUNT" -eq 2 ]; then
        echo "    (2 MATCHED = normal toggle on + toggle off)"
    elif [ "$MATCHED_COUNT" -eq 1 ]; then
        echo "    (1 MATCHED = single toggle on)"
    fi
    RESULT=0
else
    echo -e "${YELLOW}WARNING: $MATCHED_COUNT MATCHED entries. Possible mild loop.${NC}"
    RESULT=0
fi

# === Rapid Consecutive Toggle Test (Issue #82) ===
# 0.8s interval > toggleCooldown (0.4s) + typical toggle duration (~300ms), so all presses should pass
echo ""
echo "=== Rapid Consecutive Toggle Test (Issue #82) ==="
echo "    Sending 3 shortcut presses at 0.8s intervals..."
echo ""

RAPID_PRE_LINES=$(log_line_count)

for i in 1 2 3; do
    osascript -e 'tell application "System Events" to keystroke "s" using {shift down, command down}'
    sleep 0.8
done
sleep 2  # Wait for last toggle to complete

RAPID_POST_LINES=$(log_line_count)
RAPID_NEW_LINES=$((RAPID_POST_LINES - RAPID_PRE_LINES))
RAPID_SLICE=$(tail -n "$RAPID_NEW_LINES" "$LOG_FILE")

RAPID_MATCHED=$(count_in_slice "$RAPID_SLICE" "MATCHED:")
RAPID_DEBOUNCE=$(count_in_slice "$RAPID_SLICE" "DEBOUNCE_BLOCKED")
RAPID_COOLDOWN=$(count_in_slice "$RAPID_SLICE" "BLOCKED cooldown")

echo "    Rapid test results (3 presses @ 0.8s):"
echo "    MATCHED:              $RAPID_MATCHED"
echo "    DEBOUNCE_BLOCKED:     $RAPID_DEBOUNCE"
echo "    COOLDOWN_BLOCKED:     $RAPID_COOLDOWN"
echo ""

echo "=== Rapid Test Log Entries ==="
echo "$RAPID_SLICE" | head -30
echo ""

# Informational verdict for rapid test (not a hard pass/fail gate)
if [ "$RAPID_MATCHED" -ge 2 ]; then
    echo -e "${GREEN}RAPID TEST: $RAPID_MATCHED/3 presses produced MATCHED events (good responsiveness)${NC}"
else
    echo -e "${YELLOW}RAPID TEST: Only $RAPID_MATCHED/3 presses produced MATCHED events (may need further tuning)${NC}"
fi

# Cleanup: kill Quickey
echo ""
echo "==> Stopping Quickey..."
pkill -f "Quickey.app/Contents/MacOS/Quickey" 2>/dev/null || true
echo "    Done."

exit $RESULT
