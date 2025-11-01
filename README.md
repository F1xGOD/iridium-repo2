# Shimboot Debian Repository

This repo contains scripts for building the Shimboot Debian repositories.

The repository is now published at `https://DOMAIN.TLD/iridium/`, and contains the following packages:
- systemd, with patches to make it run on Chrome OS kernels
- mesa-amber

It supports the following distros, with both arm64 and amd64 packages provided:
- Debian 12 (Bookworm)
- Iridium (Osaka) *(rebuilt from the Debian Trixie sources)*
- Debian Sid (Sid)
- Ubuntu 22.04 (Jammy)
- Ubuntu 24.04 (Noble)

To consume the repository, add the following entry (with `trusted=yes` until signing is re-enabled) to your `/etc/apt/sources.list` (or a file under `/etc/apt/sources.list.d/`):

```
deb [trusted=yes] https://DOMAIN.TLD/iridium osaka main
```

## Signing status

Release files are generated but not currently signed. Package consumers **must** include the `[trusted=yes]` option (as shown above) or pin the repository in an internal mirror. To re-enable signing later, set the `APT_GPG_KEY_ID` environment variable (and optional `APT_GPG_KEY_FILE`/`APT_GPG_PASSPHRASE`) before running `build_repo.sh`; the script will detect the key and produce signed `Release`, `Release.gpg`, and `InRelease` outputs automatically. If you keep key material with the workspace, place it under `keys/` (already ignored by git).

## Copyright:
The contents of this repository are licensed under the GNU GPL v3.

```
ading2210/shimboot-repo: Scripts for building the Shimboot Debian repository
Copyright (C) 2024 ading2210

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```
