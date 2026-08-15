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

## Install

Point SwiftBar at this directory as its plugin folder, or symlink individual
plugins into your existing one.
