#!/bin/bash
set -e
[ "$DEBUG" ] && set -x

supported_releases="bookworm osaka unstable jammy noble"
supported_arches="amd64 arm64"
base_path="$(realpath "$(pwd)")"
repo_dir="$base_path/repo"
download_dir="$base_path/download"

command -v apt-ftparchive >/dev/null || { echo "apt-ftparchive required"; exit 1; }

# (optional) import signing key
if [ -n "${APT_GPG_KEY_FILE:-}" ] && [ -f "$APT_GPG_KEY_FILE" ] && command -v gpg >/dev/null; then
  gpg --batch --import "$APT_GPG_KEY_FILE" || true
fi

rm -rf "$repo_dir"
mkdir -p "$repo_dir"

# 🔎 NEW: find *.deb anywhere under download/, route by .../<release>_<arch>/...
while IFS= read -r -d '' deb; do
  # expect path segments like: .../<release>_<arch>/pkg.deb
  seg="$(echo "$deb" | grep -oE '(bookworm|osaka|unstable|jammy|noble)_(amd64|arm64)' | tail -n1 || true)"
  [ -z "$seg" ] && { echo "[skip] cannot detect release/arch for $deb"; continue; }
  release_name="${seg%_*}"
  arch="${seg#*_}"

  pool_dir="$repo_dir/pool/main/$release_name"
  dists_dir="$repo_dir/dists/$release_name/main/binary-$arch"
  mkdir -p "$pool_dir" "$dists_dir"

  cp -n "$deb" "$pool_dir"/
done < <(find "$download_dir" -type f -name '*.deb' -print0)

# build Packages per release/arch we actually populated
for release_name in $supported_releases; do
  for arch in $supported_arches; do
    pool_dir="$repo_dir/pool/main/$release_name"
    dists_dir="$repo_dir/dists/$release_name/main/binary-$arch"
    [ -d "$dists_dir" ] || continue
    cd "$repo_dir"
    # If no .deb, skip creating empty indexes
    if ! ls "$pool_dir"/*.deb >/dev/null 2>&1; then
      echo "[i] no packages for $release_name/$arch, skipping indexes"
      rm -rf "$dists_dir"
      continue
    fi
    dpkg-scanpackages --arch "$arch" "pool/main/$release_name" > "$dists_dir/Packages"
    gzip -9c "$dists_dir/Packages" > "$dists_dir/Packages.gz"
  done
done

cd "$repo_dir"

# Release & signing — include Components/Architectures present
for release_name in $supported_releases; do
  release_dir="$repo_dir/dists/$release_name"
  [ -d "$release_dir" ] || { echo "[i] skip Release for $release_name (no dists)"; continue; }

  # Compute actual components/arches
  comps="main"
  archs="$(find "$release_dir" -type d -name 'binary-*' -printf '%f\n' | sed 's/^binary-//' | sort -u | tr '\n' ' ' | sed 's/ $//')"
  [ -n "$archs" ] || { echo "[i] skip Release for $release_name (no binaries)"; rm -rf "$release_dir"; continue; }

  release_file="$release_dir/Release"
  apt-ftparchive release "dists/$release_name" > "$release_file"

  # normalize Suite/Codename + force Components/Architectures
  sed -i "/^Suite:/d;/^Codename:/d;/^Components:/d;/^Architectures:/d" "$release_file"
  {
    echo "Suite: $release_name"
    echo "Codename: $release_name"
    echo "Components: $comps"
    echo "Architectures: $archs"
  } >> "$release_file"

  # Sign if key available
  if [ -n "${APT_GPG_KEY_ID:-}" ] && command -v gpg >/dev/null && gpg --list-secret-keys "$APT_GPG_KEY_ID" >/dev/null 2>&1; then
    gpg_args=(--batch --yes --pinentry-mode loopback -u "$APT_GPG_KEY_ID")
    [ -n "${APT_GPG_PASSPHRASE:-}" ] && gpg_args+=(--passphrase "$APT_GPG_PASSPHRASE")
    gpg "${gpg_args[@]}" --output "$release_dir/Release.gpg" --detach-sign "$release_file"
    gpg "${gpg_args[@]}" --output "$release_dir/InRelease" --clearsign "$release_file"
  else
    echo "[i] unsigned Release for $release_name (no key)"
  fi
done
