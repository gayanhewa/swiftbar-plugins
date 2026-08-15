# swiftbar-plugins

My [SwiftBar](https://github.com/swiftbar/SwiftBar) (xbar-compatible) menu bar plugins.

## Plugins

### `gh-reviews.5m.sh`

Lists open PRs where your review is requested, plus your own open PRs. Refreshes every 5 minutes.

**Dependencies:** [`gh`](https://cli.github.com/), [`jq`](https://jqlang.github.io/jq/)

**Setup:**

```sh
gh auth login
cp .gh-reviews.config.example .gh-reviews.config
# edit .gh-reviews.config to scope the search
```

Then symlink or copy the script into your SwiftBar plugin folder, alongside your
`.gh-reviews.config` (the script reads the config from its own directory).

`GH_PR_REPOS` / `GH_PR_OWNERS` in the environment override the config file.

### `colima.1m.sh`

Shows Colima VM status per profile in the menu bar (🐳 with a running count).
Each instance gets start/stop/restart actions in the dropdown. Refreshes every
minute.

**Dependencies:** [`colima`](https://github.com/abiosoft/colima), [`jq`](https://jqlang.github.io/jq/)

No config. It reads `colima list -j` and acts on whatever profiles exist.

### `nix-rebuild.10m.sh`

Discovers the darwin hosts in your flake(s) via `nix eval` and shows them in
the menu bar (❄️, with a `*` when a flake repo is dirty). Each host gets
**Switch** and **Build only** actions that open a terminal, so `sudo` can
prompt. Shows the current system generation.

**Dependencies:** `nix`, [`jq`](https://jqlang.github.io/jq/), `darwin-rebuild`

Defaults to `~/Workspace/mydots`. To point it elsewhere, drop a
`.nix-rebuild.config` next to the script:

```sh
FLAKES="~/Workspace/mydots ~/Workspace/other-flake"
```

### `claude-usage.5m.sh`

Shows Claude quota in the menu bar (✳️ with the session window's % remaining,
orange under 25%, red under 10%). The dropdown lists each quota window with
its reset time and burn pace, then a per-session breakdown of output tokens
spent inside the current session window, computed from the transcripts in
`~/.claude/projects/`. Quota data comes from `quota-axi`.

**Dependencies:** `quota-axi`, [`jq`](https://jqlang.github.io/jq/)

**Setup:** run `quota-axi --allow-keychain-prompt` once and approve Keychain
access so it can read the live quota.

## Install

Point SwiftBar at this directory as its plugin folder, or symlink individual
plugins into your existing one.
