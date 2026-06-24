# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

This is an `ansible-pull` repository for configuring a fresh Debian (Forky) machine after a standard netinstall. The target machine pulls and runs playbooks against itself (`hosts: localhost`, `become: true`).

### Provisioning flow

1. Run a standard Debian server netinstall — user, password, SSH already set up by the installer.
2. Run `bootstrap.sh` (as sudo) — installs `ansible-core` and `git`, writes the GitHub deploy key for the private dotfiles repo, then fires `ansible-pull`.
3. `ansible-pull` clones this repo and runs the playbook. On completion the machine reboots.

```bash
sudo bash bootstrap.sh
```

The `cloud-init` branch preserves an alternative path for Proxmox/cloud-image provisioning.

### Playbooks

- `debian-base.yml` — Full setup: system config, packages, Docker CE, dotfiles.

### Role structure

`roles/debian-base/tasks/` is split into focused files imported in order:

- `system.yml` — hostname, user directories
- `packages.yml` — reads `meta/install-list/apt`, installs packages, symlinks `batcat → bat`
- `docker.yml` — Docker CE via official apt repo (suite pinned to `trixie` for Forky compatibility)
- `dotfiles.yml` — clones dotfiles repo as `sigil`, symlinks `files/` tree into `$HOME`, installs TPM and fortune files

### Package list

`meta/install-list/apt` — one package per line. Read at runtime via `slurp` using `{{ playbook_dir }}` so the path works regardless of ansible-pull's checkout directory name.

## Running playbooks

Bootstrap (first run on a fresh install):
```bash
sudo bash bootstrap.sh
```

Re-run manually after bootstrap:
```bash
ansible-pull -U https://github.com/Zurtar/ansible.git debian-base.yml
```

Dry run:
```bash
ansible-playbook --check debian-base.yml
```

Lint:
```bash
ansible-lint debian-base.yml
```
