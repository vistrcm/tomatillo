#!/usr/bin/env bash
set -euo pipefail

swift build

export TOMATILLO_WORK_SECS=7
export TOMATILLO_BREAK_SECS=15
export TOMATILLO_SNOOZE_SECS=5

exec .build/debug/Tomatillo
