#!/bin/bash

#create a new debian repo with packages from previous artifact

set -e
if [ "$DEBUG" ]; then
  set -x
fi

supported_releases="bookworm osaka unstable jammy noble"
supported_arches="amd64 arm64"
base_path="$(realpath $(pwd))"
repo_dir="$base_path/repo"
download_dir="$base_path/download"

if ! command -v apt-ftparchive &> /dev/null; then
  echo "apt-ftparchive is required to build Release metadata."
  exit 1
fi

if [ -n "$APT_GPG_KEY_FILE" ] && [ -f "$APT_GPG_KEY_FILE" ]; then
  if command -v gpg &> /dev/null; then
    gpg --batch --import "$APT_GPG_KEY_FILE"
  else
    echo "gpg not found; skipping import of $APT_GPG_KEY_FILE"
  fi
fi

ls -R "$download_dir"

rm -rf $repo_dir || true
mkdir -p $repo_dir

for release_name in $supported_releases; do
  for arch in $supported_arches; do
    cd $base_path

    if [ ! -d "$download_dir/${release_name}_${arch}/" ]; then
      echo "skipping ${release_name} ${arch}, no packages found"
      continue
    fi

    pool_dir="$repo_dir/pool/main/$release_name"
    dists_dir="$repo_dir/dists/$release_name/main/binary-$arch"
    mkdir -p $dists_dir
    mkdir -p $pool_dir
    cp "$download_dir/${release_name}_${arch}/"*.deb $pool_dir
    rm $pool_dir/*dbgsym* || true
    rm $pool_dir/*udev* || true

    cd $repo_dir
    dpkg-scanpackages --arch $arch pool/main/$release_name > $dists_dir/Packages
    cat $dists_dir/Packages | gzip -9 > $dists_dir/Packages.gz
  done
done

cd $repo_dir

for release_name in $supported_releases; do
  release_dir="$repo_dir/dists/$release_name"
  if [ ! -d "$release_dir" ]; then
    echo "skipping release metadata for $release_name, directory missing"
    continue
  fi

  apt-ftparchive release "dists/$release_name" > "$release_dir/Release"

  if [ -n "$APT_GPG_KEY_ID" ] && command -v gpg &> /dev/null; then
    if gpg --list-secret-keys "$APT_GPG_KEY_ID" &> /dev/null; then
      gpg_args=(--batch --yes --pinentry-mode loopback -u "$APT_GPG_KEY_ID")
      if [ -n "$APT_GPG_PASSPHRASE" ]; then
        gpg_args+=(--passphrase "$APT_GPG_PASSPHRASE")
      fi

      gpg "${gpg_args[@]}" --output "$release_dir/Release.gpg" --detach-sign "$release_dir/Release"
      gpg "${gpg_args[@]}" --output "$release_dir/InRelease" --clearsign "$release_dir/Release"
    else
      echo "Secret key $APT_GPG_KEY_ID not available; skipping signing for $release_name"
    fi
  else
    echo "APT_GPG_KEY_ID not set or gpg unavailable; skipping signing for $release_name"
  fi
done
