# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

This is an `ansible-pull` repository for configuring a Debian machine. Instead of pushing from a control node, the target machine pulls and runs playbooks against itself (`hosts: localhost`, `become: true`).

### Playbooks

- `debian-base.yml` — Core Debian setup: reads `meta/install-list/apt` and installs all listed packages via `apt`.
- `debian-base-ai.yml` — AI-focused variant (in progress, currently empty).

### Package list

`meta/install-list/apt` — One package name per line. Read at runtime via `slurp` using `{{ playbook_dir }}` so the path works regardless of what hostname ansible-pull uses for its checkout directory.

## Running playbooks

Run manually on the target host:
```bash
ansible-pull -U <repo-url> debian-base.yml
```

Or run locally without pull (for testing):
```bash
ansible-playbook debian-base.yml
```

Dry run:
```bash
ansible-playbook --check debian-base.yml
```

Lint:
```bash
ansible-lint debian-base.yml
```
