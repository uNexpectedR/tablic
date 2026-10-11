#!/usr/bin/env bash
# Local preview without Nix/Basecamp — uses Qt 6 qmlscene.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QMLSCENE="${QMLSCENE:-}"
if [[ -z "$QMLSCENE" ]]; then
  if command -v qmlscene-qt6 >/dev/null 2>&1; then
    QMLSCENE="qmlscene-qt6"
  elif [[ -x /usr/lib/qt6/bin/qmlscene ]]; then
    QMLSCENE="/usr/lib/qt6/bin/qmlscene"
  elif command -v qmlscene >/dev/null 2>&1; then
    QMLSCENE="qmlscene"
  else
    echo "Qt 6 qmlscene not found. Install qmlscene-qt6 or use: nix run" >&2
    exit 1
  fi
fi
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-}"
cd "$ROOT"
exec "$QMLSCENE" Preview.qml
