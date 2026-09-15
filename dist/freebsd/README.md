# FreeBSD `rc.d` service files

Ready-to-install service scripts for running Max under FreeBSD's
[`daemon(8)`](https://man.freebsd.org/cgi/man.cgi?daemon%288%29) supervisor.
FreeBSD is not a target of `max service install`, so these are installed by
hand. The full walkthrough — build from source, provider auth, logs, and the
rationale behind every `daemon(8)` flag — is in the handbook under
**Setup → FreeBSD** (`docs/book/src/setup/freebsd.md`).

| File | Installs as | Purpose |
|---|---|---|
| `max-run.sh` | `/usr/local/libexec/max-run.sh` | Launcher: sets `PATH`, execs `max daemon`. `HOME` comes from `daemon -u`. |
| `max.rc` | `/usr/local/etc/rc.d/max` | Basic single-instance service. |
| `max-hardened.rc` | `/usr/local/etc/rc.d/max` | Hardened variant for unattended/remote operation. Use this **or** `max.rc`, not both. |
| `rc.conf.max` | `/etc/rc.conf.d/max` | Optional per-service `rc.conf` drop-in (`max_enable`, `max_runas`) — a file alternative to the `sysrc` lines below. |
| `jail.conf.sample` | append to `/etc/jail.conf` | Sample thick-jail entry for running the service inside a jail. |
| `max-jail-setup.sh` | run on the host | Helper that provisions the jail end to end (dataset, base extract, jail.conf entry, service files) — see [Running in a jail](#running-in-a-jail). |

The two `rc.d` scripts carry a `@@MAX_USER@@` placeholder for the owning
account — substitute it on install. The launcher needs no substitution: it runs
through `daemon -u <user>`, which sets `HOME` from the service account's passwd
entry before exec.

## Install (hardened variant)

```sh
user=youruser     # the account that owns ~/.max

# Launcher: no substitution needed (derives HOME from the daemon -u account).
doas install -m 755 max-run.sh /usr/local/libexec/max-run.sh

sed "s/@@MAX_USER@@/${user}/g" max-hardened.rc \
    | doas tee /usr/local/etc/rc.d/max >/dev/null
doas chmod 755 /usr/local/etc/rc.d/max

doas sysrc max_enable=YES
doas service max start
doas service max status
```

Swap `max-hardened.rc` for `max.rc` if you want the basic service.

To set the rc.conf knobs from a file instead of `sysrc`, install the drop-in:

```sh
doas install -m 644 rc.conf.max /etc/rc.conf.d/max   # edit youruser first
```

## Running in a jail

To run the service inside a thick jail, provision it end to end with the helper
(run on the host as root); it creates the jail, extracts a matching base, adds
the `/etc/jail.conf` entry, starts the jail, and installs the launcher + hardened
`rc.d` script inside it:

```sh
doas sh max-jail-setup.sh
# override defaults via env, e.g.:
#   JAIL_NAME=zc ZPOOL=tank MAX_USER=agent doas sh max-jail-setup.sh
```

It prints the remaining steps (install the `max` binary, set up auth, start
the service). To do it by hand instead, `jail.conf.sample` is the entry to append
to `/etc/jail.conf`; the full manual walkthrough is in the handbook under
**Setup → FreeBSD → Running in a jail**.

## Why the hardened variant

It addresses three `daemon(8)` behaviours that surface the moment you drive the
service over `ssh` or restart it unattended:

- **Remote `service start` hangs** — `daemon -r` inherits the caller's std fds,
  so an `ssh host 'service max start'` never gets EOF. The hardened start
  detaches the supervisor's own descriptors (`</dev/null >/dev/null 2>&1`); the
  child's output still goes to the logfile via `-o`.
- **Repeated `start` stacks orphan supervisors** that fight over the gateway
  port. The hardened start refuses when a live supervisor already exists.
- **A stale pidfile breaks stop/status.** The hardened script identifies its
  supervisor by the `daemon(8)` process retitle (`daemon: …max-run.sh…`),
  not by trusting the pidfile alone, and verifies the supervisor actually died.

The handbook page documents the FreeBSD-specific traps these work around
(`pgrep -f` ignoring a leading `^` anchor; `daemon -P` pidfiles having no
trailing newline) for anyone adapting the scripts — e.g. to a multi-instance
pool.
