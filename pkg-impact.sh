#!/usr/bin/env python3
# Lists manually installed packages sorted by how many packages
# would be removed (including cascading deps) if each were purged.
# Loads apt cache once — no per-package subprocesses.

import apt
import subprocess

cache = apt.Cache()
manual = subprocess.check_output(['apt-mark', 'showmanual']).decode().splitlines()

results = []
for pkg_name in sorted(p.strip() for p in manual):
    if pkg_name not in cache or not cache[pkg_name].is_installed:
        continue
    cache.clear()
    try:
        cache[pkg_name].mark_delete(purge=True)
        for p in cache:
            if p.is_installed and p.is_auto_removable:
                p.mark_delete(purge=True)
        count = sum(1 for p in cache if p.marked_delete)
    except Exception:
        count = 1
    results.append((count, pkg_name))

cache.clear()
results.sort(reverse=True)

print(f"{'REMOVES':<10} PACKAGE")
print(f"{'-------':<10} -------")
for count, name in results:
    print(f"{count:<10} {name}")
