#!/usr/bin/env bash
# Give a repository its own directory on chap-sandbox, served at /<name>/.
#
#   scripts/add-app.sh <name> <owner/repo> [secret-name]
#
# Creates /mnt/data/www/<name> owned by `deploy`, generates a new ED25519 key,
# adds it to deploy's authorized_keys forced through rrsync into that
# directory, and stores the private half as a GitHub Actions secret on the repo
# (default name CHAP_SANDBOX_SSH_KEY). The private key only ever exists in a
# temporary directory, which is removed on exit.
#
# Needs: SSH as ubuntu@158.39.75.126 (sudo there) and `gh` logged in with
# admin on the repo. See AGENTS.md for the rest of the steps.
set -euo pipefail

HOST=ubuntu@158.39.75.126
WWW=/mnt/data/www

name=${1:-}
repo=${2:-}
secret=${3:-CHAP_SANDBOX_SSH_KEY}

if [[ -z $name || -z $repo ]]; then
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
fi
if [[ ! $name =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "name must be lowercase letters, digits and dashes: $name" >&2
    exit 2
fi
if [[ ! $repo =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "repo must be owner/name: $repo" >&2
    exit 2
fi
gh repo view "$repo" --json name >/dev/null

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ssh-keygen -q -t ed25519 -N '' -C "chap-sandbox $name ($repo) $(date +%F)" -f "$tmp/key"
line="restrict,command=\"/usr/bin/rrsync $WWW/$name\" $(cat "$tmp/key.pub")"

# The remote side refuses to add a second key for a directory that has one:
# rotate by editing authorized_keys by hand (see the climate-sre README).
ssh "$HOST" "set -eu
    keys=/home/deploy/.ssh/authorized_keys
    if sudo grep -qF 'rrsync $WWW/$name\"' \"\$keys\"; then
        echo 'a deploy key for $WWW/$name already exists' >&2; exit 1
    fi
    sudo install -d -o deploy -g deploy -m 755 '$WWW/$name'
    sudo tee -a \"\$keys\" >/dev/null" <<<"$line"

gh secret set "$secret" -R "$repo" <"$tmp/key"

echo
echo "Server: $WWW/$name, served at https://chap-sandbox.dhis2.org/$name/"
echo "Secret: $secret on $repo"
echo "Key:    $(ssh-keygen -lf "$tmp/key.pub")"
echo "Record the directory and the fingerprint in climate-sre hosts/chap-sandbox/README.md."
