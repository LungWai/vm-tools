#!/usr/bin/env bash
set -euo pipefail

# ======== configurable defaults ========
: "${MNT:=/mnt/repos}"                # mount point
: "${LABEL:=data}"                    # filesystem label
: "${FSOPTS:=defaults,nofail}"        # fstab options
OWNER_USER="${OWNER_USER:-${SUDO_USER:-$USER}}"
OWNER_GROUP="${OWNER_GROUP:-$OWNER_USER}"
# ======================================

if [[ $EUID -ne 0 ]]; then
  echo "This script must run as root. Try: sudo bash $0"
  exit 1
fi

have() { command -v "$1" >/dev/null 2>&1; }

# 0) Choose a device:
#    - If DEV is provided, use it (e.g., DEV=/dev/nvme0n1).
#    - Else auto-pick the first unmounted whole-disk device that's not the root disk, CDROM, or loop.
if [[ -z "${DEV:-}" ]]; then
  # List whole-disk block devices (TYPE=disk), ignore loop, rom/sr*, and the disk that backs '/'
  ROOT_DISK="$(findmnt -no SOURCE / | sed 's/[0-9]*$//; s/p[0-9]*$//')" || ROOT_DISK=""
  CANDIDATES=$(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}' | grep -Ev '^/dev/(loop|sr|rom)')
  for d in $CANDIDATES; do
    [[ "$d" == "$ROOT_DISK" ]] && continue
    # skip if it already has any mounted partitions
    if ! lsblk -nrpo NAME,MOUNTPOINT "$d" | awk 'NF==2 && $2!=""{exit 1}'; then
      continue
    fi
    DEV="$d"
    break
  done
fi

if [[ -z "${DEV:-}" || ! -b "$DEV" ]]; then
  echo "No suitable data disk found. Provide DEV=/dev/sdb (or nvme device) explicitly."
  exit 1
fi

# Partition name differs for NVMe (uses p-suffix)
if [[ "$DEV" =~ nvme[0-9]+n[0-9]+$ ]]; then
  PART="${PART:-${DEV}p1}"
else
  PART="${PART:-${DEV}1}"
fi

echo "[+] Using device: $DEV"
echo "[+] Partition:    $PART"
echo "[+] Mount point:  $MNT"
echo "[+] Owner:        $OWNER_USER:$OWNER_GROUP"

# 1) ensure tools
need_pkgs=()
have parted || need_pkgs+=("parted")
have blkid  || need_pkgs+=("util-linux")
if ((${#need_pkgs[@]})); then
  echo "[+] Installing tools: ${need_pkgs[*]}"
  apt-get update -y && apt-get install -y "${need_pkgs[@]}"
fi

# 2) create partition if missing
if [[ ! -b "$PART" ]]; then
  echo "[+] Creating GPT and primary partition on $DEV..."
  parted -s "$DEV" mklabel gpt
  parted -s "$DEV" mkpart primary ext4 0% 100%
  udevadm settle || true
  sleep 2
fi

# 3) create filesystem if missing
FSTYPE="$(lsblk -no FSTYPE "$PART" || true)"
if [[ -z "$FSTYPE" ]]; then
  echo "[+] Formatting $PART as ext4 (label: $LABEL)..."
  mkfs.ext4 -L "$LABEL" "$PART"
else
  echo "[=] $PART already has filesystem: $FSTYPE (skipping format)"
fi

# 4) ensure mount point
mkdir -p "$MNT"

# 5) add/update fstab by UUID
UUID="$(blkid -s UUID -o value "$PART")"
if [[ -z "${UUID:-}" ]]; then
  echo "[-] Could not read UUID for $PART"
  exit 1
fi

FSTAB_LINE="UUID=${UUID} ${MNT} ext4 ${FSOPTS} 0 2"
if grep -q "UUID=${UUID}" /etc/fstab 2>/dev/null; then
  echo "[=] fstab already has an entry for UUID=${UUID} (leaving as-is)"
else
  echo "[+] Adding to /etc/fstab:"
  echo "    $FSTAB_LINE"
  echo "$FSTAB_LINE" >> /etc/fstab
fi

# 6) (re)mount and set ownership
mountpoint -q "$MNT" && umount "$MNT" || true
echo "[+] Mounting from fstab..."
mount -a

# verify
MOUNTED_UUID="$(blkid -s UUID -o value "$(findmnt -no SOURCE "$MNT")" 2>/dev/null || true)"
if [[ "$MOUNTED_UUID" != "$UUID" ]]; then
  echo "[-] Unexpected mount at $MNT (got UUID=$MOUNTED_UUID, expected $UUID)"
  exit 1
fi

echo "[+] Setting ownership on $MNT to ${OWNER_USER}:${OWNER_GROUP}..."
chown -R "${OWNER_USER}:${OWNER_GROUP}" "$MNT"

echo
echo "[✓] Done. Mounted ${MNT} (UUID=${UUID})"
df -h "$MNT" | awk 'NR==1 || NR==2 {print}'
