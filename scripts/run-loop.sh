#!/bin/bash
cd "$HOME/developer/Quickey"

INTERVAL=1800  # 30 minutes

echo "[loop] Starting Quickey loop job (interval: ${INTERVAL}s)"

while true; do
  echo "[loop] $(date '+%Y-%m-%d %H:%M:%S') - Running iteration..."
  claude --dangerously-skip-permissions \
    --max-turns 50 \
    --output-format text \
    -p "$(cat $HOME/developer/Quickey/docs/loop-prompt.md)"
  echo "[loop] $(date '+%Y-%m-%d %H:%M:%S') - Iteration done. Sleeping ${INTERVAL}s..."
  sleep $INTERVAL
done
