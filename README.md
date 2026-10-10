# dracut-remote-luks-unlock

Dracut-based remote LUKS unlock over a WireGuard tunnel, with WiFi + Ethernet
support.

Boot your LUKS-encrypted machine behind NAT and unlock it remotely by SSHing
through a WireGuard tunnel — even over WiFi.

## How it works

Three dracut modules are installed into the initramfs:

| Module | Purpose |
|--------|---------|
| `99wifi-net` | WiFi + Ethernet via NetworkManager. Copies all saved NM connection profiles, auto-detects WiFi drivers and firmware, enables wpa_supplicant with D-Bus plumbing. |
| `99pubexp` | WireGuard client that joins the public-exposure tunnel. Waits for network, then brings up the embedded tunnel config. |
| `99crypt-ssh` | SSH server in initramfs via dropbear. Accepts connections for LUKS passphrase entry. |

## Usage

### Full install (all modules)

```bash
sudo bash setup.sh \
    --pubexp-conf /path/to/pubexp-pre0.wg \
    --user imranr
```

### Individual modules

```bash
sudo bash setup.sh --module pubexp --pubexp-conf /path/to/pubexp-pre0.wg
sudo bash setup.sh --module wifi-net
sudo bash setup.sh --module crypt-ssh --user imranr
```

### Skip rebuild (caller manages it)

```bash
sudo bash setup.sh ... --no-rebuild
```

## Requirements

- Fedora (or any distribution with dracut, NetworkManager, and dnf)
- NetworkManager with at least one saved connection profile
- A WireGuard peer (hub) reachable from the target machine
- `wg` (wireguard-tools) installed on the host
- `rd.neednet=1 ip=dhcp` on the kernel command line (added automatically)

## Security

- All saved NM WiFi profiles (including pre-shared keys) are copied into the initramfs, which lives on the unencrypted `/boot` partition. Anyone with physical access can extract these credentials.
- SSH host keys for the initramfs SSH server are stored in `/etc/dracut-crypt-ssh-keys/`.
- The WireGuard private key is embedded in the initramfs. Use a separate key for the preboot client (not the same one used post-boot).
- The authorized_keys file is copied from the specified user's home directory.

## Files

```
dracut-remote-luks-unlock/
├── setup.sh                        # CLI entrypoint
├── lib/
│   └── common.sh                   # Shared helpers
├── modules/
│   ├── 99pubexp/                   # WireGuard client module
│   │   ├── module-setup.sh
│   │   ├── start-pubexp.sh
│   │   └── stop-pubexp.sh
│   ├── 99wifi-net/                 # WiFi + Ethernet module
│   │   ├── module-setup.sh
│   │   └── wait-for-network.sh
│   └── 99crypt-ssh/                # SSH config drop-in
│       └── crypt-ssh.conf
└── installers/
    ├── pubexp.sh                   # Installs pubexp module + embedded conf
    ├── wifi-net.sh                 # Installs wifi-net module
    └── crypt-ssh.sh                # Installs crypt-ssh package + keys
```
