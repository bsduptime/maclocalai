# obsidian-sync

Keep an [Obsidian](https://obsidian.md) vault in sync between this Mac and one or more peers (another Mac, a Linux box, a Jetson, an iPhone) using [Syncthing](https://syncthing.net) — peer-to-peer, end-to-end encrypted, no cloud account, no per-device subscription.

This stack installs Syncthing (and optionally Obsidian itself), starts the daemon as a login service, and gives you two ways to pair with a peer: the standard web GUI, or a copy-pasteable REST recipe that skips the GUI entirely.

## What this gives you

- A Syncthing daemon running on this Mac, autostart on login
- A local web GUI at http://localhost:8384 for status / device management
- A standard layout: vault lives at `~/obsidian-vault` (configurable at pair time)
- Bidirectional sync — edits on either side propagate in seconds over LAN or Tailscale
- No cloud, no Obsidian Sync subscription, no Dropbox in the path

## Install

```bash
bash install.sh
```

The installer:

1. Installs `syncthing` via Homebrew if it's not already there
2. Offers to install the Obsidian desktop app (skip if you already have it)
3. Starts the daemon as a Homebrew service (autostarts on login)
4. Waits for the config to generate, then prints this Mac's **device ID**

The device ID is what you give a peer so they can add you as a remote.

## Pair with a peer

You need two pieces of info from the other machine:

- Its **device ID** (a long `XXXX-XXXX-…-XXXX` string)
- Optionally its **Tailscale IP** (so pairing works even when you're off the same LAN)

How to get those on the peer:

```bash
# Linux/macOS peer with the daemon running:
curl -s -H "X-API-Key: $(grep -oE '<apikey>[^<]+' ~/.config/syncthing/config.xml | sed 's/<apikey>//')" \
     http://localhost:8384/rest/system/status \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["myID"])'
```

Then pair using either approach below.

### Option A — GUI (easiest)

1. Open this Mac's GUI: `open http://localhost:8384`
2. **Add Remote Device** → paste the peer's device ID → name it → Advanced → Addresses: `tcp://<peer-tailscale-ip>:22000, dynamic` → Save
3. On the peer's GUI, do the mirror: add this Mac's device ID as a remote
4. On whichever side owns the vault, edit the folder → **Sharing** tab → tick the peer → Save
5. On the receiving side, accept the folder banner that appears, pick a local path (e.g. `~/obsidian-vault`)

Vault populates in seconds for a typical Obsidian vault (hundreds of KB to low MB).

### Option B — REST API (no clicking)

If you already have the peer's device ID in hand, you can pair entirely via curl. Set the variables at the top, then run the block.

```bash
# This Mac
API_KEY=$(grep -oE '<apikey>[^<]+' "$HOME/Library/Application Support/Syncthing/config.xml" | sed 's/<apikey>//')
MAC_ID=$(curl -s -H "X-API-Key: $API_KEY" http://localhost:8384/rest/system/status \
         | python3 -c 'import json,sys; print(json.load(sys.stdin)["myID"])')

# Peer (fill these in)
PEER_ID="XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX"
PEER_TS_IP="100.x.x.x"             # peer's Tailscale IP
LOCAL_PATH="$HOME/obsidian-vault"  # where the vault lives on this Mac
FOLDER_ID="obsidian-vault"         # must match the folder ID on the peer

# 1. Add the peer as a remote device
curl -s -X PUT -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
  "http://localhost:8384/rest/config/devices/$PEER_ID" \
  -d "{
    \"deviceID\": \"$PEER_ID\",
    \"name\": \"peer\",
    \"addresses\": [\"tcp://$PEER_TS_IP:22000\", \"dynamic\"],
    \"compression\": \"metadata\"
  }"

# (On the peer, do the mirror: add $MAC_ID. Share the obsidian-vault folder with us.)

# 2. Wait for the connection to come up, then for the folder offer
mkdir -p "$LOCAL_PATH"
for i in $(seq 1 30); do
  curl -s -H "X-API-Key: $API_KEY" "http://localhost:8384/rest/cluster/pending/folders?device=$PEER_ID" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d else 1)' && break
  sleep 2
done

# 3. Accept the folder offer at $LOCAL_PATH
curl -s -X PUT -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
  "http://localhost:8384/rest/config/folders/$FOLDER_ID" \
  -d "{
    \"id\": \"$FOLDER_ID\",
    \"label\": \"Obsidian Vault\",
    \"path\": \"$LOCAL_PATH\",
    \"type\": \"sendreceive\",
    \"devices\": [{\"deviceID\": \"$MAC_ID\"}, {\"deviceID\": \"$PEER_ID\"}],
    \"rescanIntervalS\": 3600,
    \"fsWatcherEnabled\": true,
    \"fsWatcherDelayS\": 10
  }"
```

When the folder state is `idle` with `need=0`, you're synced:

```bash
curl -s -H "X-API-Key: $API_KEY" "http://localhost:8384/rest/db/status?folder=$FOLDER_ID" \
  | python3 -m json.tool | grep -E 'state|need|localBytes|globalBytes'
```

## Use the vault in Obsidian

1. Open Obsidian
2. **Open folder as vault** → pick `~/obsidian-vault`
3. That's it — Obsidian indexes the existing notes; future edits sync back to the peer automatically

## Why Syncthing (vs. alternatives)

- **Obsidian Sync** (paid subscription per vault) — works fine, but it's a recurring cost and routes through Obsidian's servers
- **iCloud / Dropbox / Google Drive** — sync conflicts on Obsidian's hidden `.obsidian/` folder are a known headache, and you're trusting the cloud with notes
- **Git** — great for versioning, terrible for live multi-device editing (conflicts, manual push/pull)
- **Syncthing** — peer-to-peer, encrypted in transit, free, handles `.obsidian/` config files cleanly, instant propagation

The tradeoff: at least one of your peers needs to be online when you want sync. For a Mac + always-on home server (Jetson, NAS, Raspberry Pi) that's a non-issue.

## How it works

```
This Mac                                            Peer (e.g. Jetson)
─────────                                           ──────────────────
Obsidian writes to ~/obsidian-vault                 Obsidian writes to /path/to/vault
        │                                                   │
        ▼                                                   ▼
Syncthing daemon (port 22000)  ◄── encrypted, P2P ──►  Syncthing daemon (port 22000)
        │                                                   │
        └── GUI: http://localhost:8384                      └── GUI: http://host:8384
```

Both daemons authenticate by device ID (a hash of the device's TLS certificate). Once paired, they discover each other over LAN broadcast, Tailscale, or Syncthing's relay network — whatever works first.

## Troubleshooting

```bash
# Status / connection state
brew services list | grep syncthing
curl -s -H "X-API-Key: $API_KEY" http://localhost:8384/rest/system/connections \
  | python3 -m json.tool

# Restart
brew services restart syncthing

# Logs
log show --predicate 'process == "syncthing"' --last 5m
# or tail the log it writes:
tail -f ~/Library/Application\ Support/Syncthing/syncthing.log 2>/dev/null
```

If the GUI is unreachable, the daemon binds to `127.0.0.1:8384` by default — that's correct, you don't want it exposed on LAN. Open with `open http://localhost:8384`.

If a peer over Tailscale won't connect: confirm both sides are on the tailnet (`tailscale status`) and that you put `tcp://<peer-tailscale-ip>:22000, dynamic` in the addresses field. `dynamic` lets Syncthing fall back to its own discovery if the static address fails.

## Uninstall

```bash
brew services stop syncthing
brew uninstall syncthing
# config + keys stay at ~/Library/Application Support/Syncthing/
# delete that directory only if you're sure — losing the device key means re-pairing every peer
```

## See also

- [Syncthing docs](https://docs.syncthing.net/)
- [Obsidian](https://obsidian.md)
