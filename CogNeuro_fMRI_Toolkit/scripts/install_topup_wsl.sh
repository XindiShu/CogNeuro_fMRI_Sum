#!/usr/bin/env bash
# Install official FSL TOPUP packages inside Ubuntu WSL, not on /mnt/c or /mnt/d.
set -euo pipefail

linux_user=bx210
linux_home=/home/bx210
topup_env=/home/bx210/fsl-topup
micromamba_url=https://anaconda.org/conda-forge/micromamba/2.8.1/download/linux-64/micromamba-2.8.1-0.tar.bz2

if [[ $(id -u) -ne 0 ]]; then
    echo 'Run this installer as root inside Ubuntu WSL.' >&2
    exit 1
fi

if ! id "$linux_user" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$linux_user"
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl tar bzip2 libgomp1

if [[ ! -x /usr/local/bin/micromamba ]]; then
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    archive="$script_dir/micromamba-2.8.1-0.tar.bz2"
    if [[ ! -f "$archive" ]]; then
        archive=$(mktemp --suffix=.tar.bz2)
        trap 'rm -f "$archive"' EXIT
        curl -fL --retry 3 "$micromamba_url" -o "$archive"
    fi
    tar -xjf "$archive" -C /usr/local bin/micromamba
    chmod 755 /usr/local/bin/micromamba
fi

if [[ ! -x "$topup_env/bin/topup" ]]; then
    runuser -u "$linux_user" -- env HOME="$linux_home" \
        MAMBA_ROOT_PREFIX="$linux_home/.micromamba" \
        /usr/local/bin/micromamba create -y -p "$topup_env" \
        --override-channels \
        -c https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/public/ \
        -c conda-forge fsl-topup fsl-avwutils
fi

echo "TOPUP executable: $topup_env/bin/topup"
test -x "$topup_env/bin/topup"
help_text=$(runuser -u "$linux_user" -- env FSLDIR="$topup_env" \
    "$topup_env/bin/topup" --help 2>&1) || true
grep -qi topup <<<"$help_text"
printf '%s\n' "$help_text" | sed -n '1,15p'
test -x "$topup_env/bin/applytopup"
test -f "$topup_env/etc/flirtsch/b02b0.cnf"
runuser -u "$linux_user" -- env HOME="$linux_home" \
    MAMBA_ROOT_PREFIX="$linux_home/.micromamba" \
    /usr/local/bin/micromamba list -p "$topup_env" | grep -E 'fsl-(topup|avwutils)'
