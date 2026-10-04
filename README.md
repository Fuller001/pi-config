# Pi Config

Portable Pi package configuration for migrating the same Pi setup between devices.

## Included

- `packages.json`: the 26 Pi packages used by this setup, pinned to the current npm versions or git commits.
- `config/rtk-optimizer.json`: RTK optimizer preferences.
- `config/settings.fragment.json`: optional non-secret UI preferences.
- `config/auto-provider.example.json`: the current provider layout with a command-backed key reference, not the key itself.
- `config/bark.example.json`: Bark configuration template with the device key removed.
- `scripts/install.sh`: an idempotent migration script.

The repository intentionally excludes `models.json`, `models-store.json`, `auth.json`, API keys, Bark device keys, caches, sessions, and workspace history. Pi's generated dependency lockfile is also not included because Pi installs each package under its own managed package root.

## Migrate a device

Requirements: Pi 1.0.2 or newer, Node.js 24.21.0 or newer, npm, git, and access to this private GitHub repository. The package sources are fetched from npm and GitHub, so network access is required.

```bash
git clone https://github.com/Fuller001/pi-config.git
cd pi-config
./scripts/install.sh
```

The script backs up the existing Pi settings, updates only the package declarations, and preserves the other settings and device-specific configuration. It does not overwrite provider credentials, Bark credentials, or RTK preferences except when explicitly requested.

If GitHub is not reachable directly, configure the network before running the script. For example:

```bash
export http_proxy=http://127.0.0.1:7892
export https_proxy=http://127.0.0.1:7892
export all_proxy=http://127.0.0.1:7892
```

Use `--apply-settings` when you want to apply the tracked theme, Alps UI settings, and built-in MCP preference:

```bash
./scripts/install.sh --apply-settings
```

Use `--force-config` only when you intentionally want to replace the existing RTK preferences:

```bash
./scripts/install.sh --force-config
```

## Configure device-specific credentials

The default install does not create credential files. Copy and edit the templates explicitly:

```bash
PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
cp config/auto-provider.example.json "$PI_DIR/auto-provider.json"
cp config/bark.example.json "$PI_DIR/bark.json"
```

Replace `YOUR_BARK_DEVICE_KEY` and `YOUR_DEVICE_NAME` in `bark.json`. The Bark endpoint contains a device credential and must not be committed.

The provider template expects the key at `~/.config/pi/my-proxy-api-key`:

```bash
mkdir -p ~/.config/pi
printf '%s\n' 'your-provider-key' > ~/.config/pi/my-proxy-api-key
chmod 600 ~/.config/pi/my-proxy-api-key
```

Edit `auto-provider.json` if the provider endpoint or key location differs. The auto-provider extension also supports `$ENV_VAR` and `${ENV_VAR}` references.

After starting a new Pi session, type `/bark` to enable Bark notifications for that session. Use `/rtk show` to inspect the RTK optimizer, and `pi list` to verify the installed packages.

## Update this snapshot

When the source device changes package versions, regenerate the package entries from the installed Pi package directory, update the two pinned git commits, review the diff for secrets, and push the change. Do not copy the whole `~/.pi/agent` directory into this repository.
