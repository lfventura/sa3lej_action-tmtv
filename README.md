<p align="center">
  <img src="icon.svg" width="64" height="64" alt="tmtv">
</p>

<h1 align="center">action-tmtv</h1>

<p align="center">
  SSH into your CI runner for interactive debugging.<br>
  Drop-in replacement for <code>action-tmate</code>.
</p>

---

## Quick start

```yaml
- name: Debug via tmtv
  if: failure()
  uses: sa3lej/action-tmtv@v1
  with:
    limit-access-to-actor: true
```

When the step runs, you'll see SSH tokens in the job log. Connect with:

```
ssh <TOKEN>@tmtv.se
```

You get a full interactive shell inside the runner. Poke around, check logs, run tests manually. When you're done, either:
- Detach from tmtv (`Ctrl-B d`) and let the job timeout
- `touch /tmp/tmtv-continue` to resume the pipeline immediately

## Migrating from action-tmate

tmate is unmaintained — stuck on tmux 2.4 since 2019. tmtv is the modern replacement, rebased on **tmux 3.6a**.

The migration is a one-line diff:

```diff
- uses: mxschmitt/action-tmate@v3
+ uses: sa3lej/action-tmtv@v1
```

That's it. Same workflow, same concept, modern tmux underneath.

### What you get over action-tmate

- **tmux 3.6a** — popup menus, extended keys, sixel graphics, Unicode improvements
- **Actively maintained** — regular releases, security fixes, CI pipeline
- **Password protection** — lock down debug sessions with `-p`
- **Web viewer** — share a browser link if someone doesn't have SSH handy
- **Static binaries** — zero dependencies, works on any Linux runner

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `limit-access-to-actor` | Only allow the GitHub actor's SSH keys | `false` |
| `timeout-minutes` | Minutes before auto-resuming the pipeline | `30` |
| `server-host` | tmtv server host | `tmtv.se` |
| `server-port` | tmtv server SSH port | `22` |
| `server-rsa-fingerprint` | Expected SHA256 fingerprint of the server RSA host key | _(unset)_ |
| `server-ed25519-fingerprint` | Expected SHA256 fingerprint of the server ED25519 host key | _(unset)_ |
| `install-url` | URL to install script | `https://tmtv.se/install.sh` |

## Self-hosted server

If you run your own tmtv-server, point the action at it:

```yaml
- uses: sa3lej/action-tmtv@v1
  with:
    server-host: tmtv.example.com
    server-port: 2222
    server-rsa-fingerprint: SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    server-ed25519-fingerprint: SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

The fingerprint options are optional — if omitted, tmtv uses its default
(the `tmtv.se` keys). Set them when pointing at a self-hosted server so the
client verifies the host keys instead of trusting on first use.

## Examples

### Debug on failure

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test
      - name: Debug on failure
        if: failure()
        uses: sa3lej/action-tmtv@v1
        with:
          limit-access-to-actor: true
          timeout-minutes: 15
```

### Always debug (manual trigger)

```yaml
on:
  workflow_dispatch:

jobs:
  debug:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Start debug session
        uses: sa3lej/action-tmtv@v1
        with:
          limit-access-to-actor: true
```

## Support

If tmtv is useful to you, [buy me a coffee](https://buymeacoffee.com/lejo).

## License

ISC — same as [tmtv](https://github.com/sa3lej/tmtv).
