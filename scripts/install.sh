#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PI_DIR=${PI_CODING_AGENT_DIR:-"$HOME/.pi/agent"}
MANIFEST="$REPO_DIR/packages.json"
SETTINGS_FRAGMENT="$REPO_DIR/config/settings.fragment.json"
FORCE_CONFIG=0
APPLY_SETTINGS=0

usage() {
  cat <<USAGE
Usage: $0 [options]

Install the pinned Pi packages into the configured agent directory.

Options:
  --apply-settings  apply the tracked non-secret UI settings fragment
  --force-config    replace the existing RTK optimizer config
  -h, --help        show this help
USAGE
}

while (($#)); do
  case "$1" in
    --apply-settings) APPLY_SETTINGS=1 ;;
    --force-config) FORCE_CONFIG=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ ! -f "$MANIFEST" ]]; then
  echo "Missing manifest: $MANIFEST" >&2
  exit 1
fi

command -v pi >/dev/null || { echo "pi is not on PATH" >&2; exit 1; }
command -v node >/dev/null || { echo "node is not on PATH" >&2; exit 1; }

mkdir -p "$PI_DIR/extensions/pi-rtk-optimizer"

backup_file() {
  local file=$1
  if [[ -f "$file" ]]; then
    local backup="${file}.bak.$(date +%Y%m%d-%H%M%S)-$$"
    cp -p "$file" "$backup"
    echo "Backed up $file -> $backup"
  fi
}

backup_file "$PI_DIR/settings.json"

PACKAGE_COUNT=$(node - "$MANIFEST" <<'NODE'
const fs = require('fs');
const manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (!Array.isArray(manifest.packages) || manifest.packages.length === 0) {
  throw new Error('packages.json must contain a non-empty packages array');
}
console.log(manifest.packages.length);
NODE
)

echo "Installing $PACKAGE_COUNT pinned Pi packages into $PI_DIR"
while IFS= read -r source; do
  [[ -z "$source" ]] && continue
  echo "Installing $source"
  pi install "$source"
done < <(node - "$MANIFEST" <<'NODE'
const fs = require('fs');
const manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
for (const source of manifest.packages) {
  if (typeof source !== 'string' || source.length === 0) {
    throw new Error('packages.json contains an invalid package source');
  }
  console.log(source);
}
NODE
)

RTK_CONFIG="$PI_DIR/extensions/pi-rtk-optimizer/config.json"
if [[ "$FORCE_CONFIG" -eq 1 ]]; then
  backup_file "$RTK_CONFIG"
  cp "$REPO_DIR/config/rtk-optimizer.json" "$RTK_CONFIG"
  echo "Installed tracked RTK optimizer config"
elif [[ ! -f "$RTK_CONFIG" ]]; then
  cp "$REPO_DIR/config/rtk-optimizer.json" "$RTK_CONFIG"
  echo "Installed RTK optimizer config"
else
  echo "Preserved existing RTK optimizer config"
fi

if [[ "$APPLY_SETTINGS" -eq 1 ]]; then
  if [[ ! -f "$SETTINGS_FRAGMENT" ]]; then
    echo "Missing settings fragment: $SETTINGS_FRAGMENT" >&2
    exit 1
  fi
  node - "$SETTINGS_FRAGMENT" "$PI_DIR/settings.json" <<'NODE'
const fs = require('fs');
const [fragmentPath, settingsPath] = process.argv.slice(2);
const fragment = JSON.parse(fs.readFileSync(fragmentPath, 'utf8'));
const settings = fs.existsSync(settingsPath)
  ? JSON.parse(fs.readFileSync(settingsPath, 'utf8'))
  : {};
Object.assign(settings, fragment);
const tempPath = `${settingsPath}.tmp.${process.pid}`;
fs.writeFileSync(tempPath, `${JSON.stringify(settings, null, 2)}\n`, { mode: 0o600 });
fs.renameSync(tempPath, settingsPath);
NODE
  echo "Applied non-secret settings fragment"
fi

cat <<EOF2

Pi migration complete.
- Agent directory: $PI_DIR
- Installed packages: $PACKAGE_COUNT
- RTK config: $RTK_CONFIG
- Settings fragment applied: $([[ "$APPLY_SETTINGS" -eq 1 ]] && echo yes || echo no)

Configure auto-provider.json and bark.json separately from the example files when needed.
EOF2
