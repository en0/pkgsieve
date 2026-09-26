# pkgsieve

Sift AUR PKGBUILDs for supply-chain malware before you build them.

`pkgsieve` is a dependency-free Bash tool that vets an AUR package directory
*before* you run `makepkg`. It was built in response to the 2026 "Atomic Arch"
AUR supply-chain campaign, in which 1500+ packages had their PKGBUILDs rewritten
to pull an infostealer / eBPF rootkit via `npm install atomic-lockfile`,
`bun install js-digest`, and friends.

It is meant to gate a build:

```bash
pkgsieve ~/.aur/idasen && makepkg -sirc
```

## What it checks

1. **Blocklist name match** — the package name against a live list of
   known-compromised AUR packages, sourced from
   [`lenucksi/aur-malware-check`](https://github.com/lenucksi/aur-malware-check)
   (~1900+ packages across the `aur-infected`, `chaos-rat`, and `russian-spam`
   campaigns). The list self-updates, keyed on the upstream commit SHA.
2. **Payload indicators** — greps `PKGBUILD`, `*.install`, and `.SRCINFO` for:
   - known malicious npm/bun payload names (`atomic-lockfile`, `js-digest`, …),
   - Node package-manager `install`/`add`/`dlx` invocations (a strong smell in
     a native Arch package),
   - `curl … | sh` / `wget … | sh` remote-exec,
   - `base64 -d` blobs, `eval "$(…)"`, `bash -c "$(…)"`,
   - raw `/dev/tcp/` sockets and inline python network one-liners.
3. **Source host sanity** — flags `source=` URLs whose host is not in a
   curated trusted-host list (warning only; a human decides).

## Exit codes

| Code | Meaning                                            |
|------|----------------------------------------------------|
| 0    | Clean — no indicators found                        |
| 1    | Suspicious findings — do not build without review  |
| 2    | Usage / environment error                          |
| 3    | Aborted at the staleness prompt                    |

## Usage

```bash
pkgsieve <package-dir> [<package-dir>...]   # scan one or more package dirs
pkgsieve --installed                        # audit installed foreign packages
pkgsieve --update                           # refresh the cached blocklist
```

Useful flags:

- `--no-update` — skip the automatic blocklist refresh for this run.
- `-y`, `--yes` — assume "yes" to the staleness acknowledgement (for
  non-interactive use, e.g. piping into `makepkg`). Also via
  `PKGSIEVE_ASSUME_YES=1`.
- `-q`, `--quiet` — only warnings, failures, and the final verdict.

## Staleness guard

Threat intelligence goes stale fast. `pkgsieve` embeds a `LAST_REVIEWED` date.
If it is older than `STALE_AFTER_DAYS` (default 30, override with
`PKGSIEVE_STALE_DAYS`), the tool warns and requires an interactive
acknowledgement before it will trust a PASS. This is a deliberate nudge to go
re-read the current advisories:

- <https://github.com/lenucksi/aur-malware-check>
- <https://archlinux.org/news/>

After reviewing, bump `LAST_REVIEWED` in the script.

## Blocklist cache

Lists are cached under `${XDG_CACHE_HOME:-~/.cache}/pkgsieve/`:

- `blocklist.txt` — merged, deduped package names
- `npm-payloads.txt` — malicious npm/bun payload names
- `blocklist.sha` — the upstream commit SHA the cache was built from

## Install

This repo is its own AUR-style package. Clone it into your local AUR tree and
build it with `makepkg` — no AUR helper required:

```bash
git clone <this-repo> ~/.aur/pkgsieve
cd ~/.aur/pkgsieve
makepkg -sirc
```

That installs the `pkgsieve` command to `/usr/bin/pkgsieve`.

## Tests

Dependency-free, offline test harness:

```bash
./tests/run.sh
```

## Limitations

`pkgsieve` is a heuristic pre-flight check, not a guarantee. It cannot detect a
novel payload, an obfuscation it has no rule for, or malicious upstream source
code pulled from an otherwise-trusted host. **Always read the PKGBUILD
yourself.** A PASS means "no known indicators found," not "safe."

## License

MIT. See [LICENSE](LICENSE). Community tool, no warranty — use at your own risk.
