# chap-sandbox

This repository is the front page of https://chap-sandbox.dhis2.org/ and the
shared tooling for putting things on that host. Everything else on the host
(learning material, demos, mockups) lives in its own repository and deploys
itself to its own directory. The host is documented in
[dhis2-chap/climate-sre](https://github.com/dhis2-chap/climate-sre/blob/main/hosts/chap-sandbox/README.md).

## How the host works

- nginx serves `/mnt/data/www/<name>/` at `https://chap-sandbox.dhis2.org/<name>/`.
  It is static files only: no server-side code, no `/chap-api` proxy, no SPA
  fallback for unknown paths.
- Every directory has its own ED25519 key on the `deploy` account. The key is
  forced through `rrsync` into that one directory, so a repository can only
  overwrite (and `--delete` inside) its own directory.
- Each repository keeps its key as the Actions secret `CHAP_SANDBOX_SSH_KEY`
  and deploys with the shared action in
  [`.github/actions/deploy`](.github/actions/deploy/action.yml).
- `/` is this repository's `site/index.html`, served from `front-page/`. It
  replaced the directory listing, so anything not linked from it is hard to find.
- Pages are `Cache-Control: no-cache`; Vite's hashed `assets/` are immutable.
  Everything served is public: no tokens or credentials in a build.

Current directories:

| Path | Repository | Built from |
| --- | --- | --- |
| `/` (`front-page/`) | dhis2-chap/chap-sandbox | `site/` |
| `/learning-material/` | dhis2-chap/learning-material | `site/` |
| `/blocks/` | dhis2-chap/chap-blocks | `apps/blocks-demo/dist/` |

Update this table when you add or remove one.

## Adding a page or app at `/<name>/`

Four steps. Steps 1 and 4 happen here; step 2 needs someone with SSH to the host.

### 1. Make the build work under a subpath

The app is served at `/<name>/`, not `/`, and the host does no rewrites.

- **Vite:** set `base: './'` (relative asset URLs, works at any path, also at a
  domain root on Vercel). Or `base: '/<name>/'` if the app needs absolute URLs.
- **Routing:** use hash routing (`#/page`), or only links to real files. Browser
  history routes such as `/<name>/settings` 404 on reload.
- **No backend.** Relative API paths like `/chap-api` or `/quiz-api` do not exist
  unless climate-sre adds a stack for them. Pick an app that works offline, or
  point it at an absolute API URL that allows CORS.
- **Plain HTML:** use relative links (`href="page.html"`, not `href="/page.html"`).

Check it: build, then serve the parent directory so the build is at a subpath:

```bash
mkdir -p /tmp/sandbox && ln -sfn "$PWD/dist" /tmp/sandbox/<name>
python3 -m http.server -d /tmp/sandbox 8000   # open http://localhost:8000/<name>/
```

### 2. Create the directory and deploy key (once per directory)

From a checkout of this repository, with SSH to `ubuntu@158.39.75.126` and
`gh` admin on the target repository:

```bash
scripts/add-app.sh <name> <owner/repo>
```

It creates `/mnt/data/www/<name>`, adds a new rrsync-restricted key, and sets
`CHAP_SANDBOX_SSH_KEY` on the repository. The private key never leaves a temp
directory that is deleted afterwards. If one repository deploys two
directories, pass a third argument to use a different secret name.

Then add the directory and the printed key fingerprint to the "Disk layout"
and deploy tables in climate-sre's `hosts/chap-sandbox/README.md`.

Do not reuse another repository's key, and do not point a key at
`/mnt/data/www` itself: either one lets that repository's `--delete` remove
other sites.

### 3. Add the deploy workflow to the app's repository

`.github/workflows/deploy-sandbox.yml` in that repository, adjusting the build
steps and `dir`:

```yaml
name: Deploy to chap-sandbox

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: deploy-chap-sandbox-<name>
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
        with:
          persist-credentials: false

      # Build however the project builds. For a pnpm + Vite project:
      - uses: pnpm/action-setup@fc06bc1257f339d1d5d8b3a19a8cae5388b55320 # v4.4.0
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0
        with:
          node-version: 22
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm build

      - uses: dhis2-chap/chap-sandbox/.github/actions/deploy@main
        with:
          ssh-key: ${{ secrets.CHAP_SANDBOX_SSH_KEY }}
          dir: dist
          path: /<name>/
```

The action refuses to upload a directory without an `index.html`. The first
push to `main` (or "Run workflow") puts the site live; check
`curl -sI https://chap-sandbox.dhis2.org/<name>/` returns 200.

### 4. Link it from the front page

Once `/<name>/` serves, add a box to `site/index.html` here and push:

```html
<a class="box box-small" href="/<name>/">Title</a>
```

`class="box"` alone is the large style, for top-level entries. Add it last so
the front page never links to a 404. Then add the row to the table above.

## Removing a directory

Remove the front-page link first. On the host: delete the key's line from
`/home/deploy/.ssh/authorized_keys` and the directory, then delete the
repository's secret and workflow, and update climate-sre's README.

## Editing this repository

- `site/index.html` is the whole front page: plain HTML, inline CSS, no build
  step, no external requests. Keep the light/dark `:root` tokens and the 16px
  side gutter.
- Every push to `main` deploys `site/` to `/`. Check locally with
  `python3 -m http.server -d site 8000`.
- `.github/actions/deploy/action.yml` is used by other repositories at `@main`:
  keep its inputs backwards compatible. It pins the host key; if the instance
  is rebuilt, update that line and every deploy starts working again.
- Check changes with `actionlint` and `shellcheck scripts/*.sh`.
