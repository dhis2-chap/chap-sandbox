# chap-sandbox

The front page of https://chap-sandbox.dhis2.org, the NREC host where the Chap
team publishes static things: learning material, demos and simple mockups. The
host itself is described in
[dhis2-chap/climate-sre](https://github.com/dhis2-chap/climate-sre) under
`hosts/chap-sandbox/`.

`site/index.html` is the whole page: plain HTML with inline CSS, no build step
and no dependencies. It links to what is served on the host. When a directory
is added to the host, add a link to it here, since the front page replaced the
directory listing at `/`.

To put a new page or app on the host at `/<name>/`, follow
[AGENTS.md](AGENTS.md): `scripts/add-app.sh` sets up the directory and deploy
key, and other repositories deploy with the shared
[`.github/actions/deploy`](.github/actions/deploy/action.yml) action.

## Deploy

Every push to `main` runs the "Deploy to chap-sandbox" workflow
([`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)), which rsyncs
`site/` to `/mnt/data/www/front-page/` on the host as the `deploy` account. The
host's root `index.html` is a symlink to `front-page/index.html`, so the page
is live as soon as the run is green; pages are served with
`Cache-Control: no-cache`, so a reload shows the new version.

The workflow's key is the `CHAP_SANDBOX_SSH_KEY` repository secret, one
ED25519 key that the server restricts to that directory (`rrsync`). The server
side, including how to rotate the key, is documented in the climate-sre README
for the host.

To deploy by hand, use the workflow's "Run workflow" button, or from a checkout
with the key: `rsync -az --delete site/ deploy@158.39.75.126:/` (the path after
the colon is relative to the rrsync root).

## Check locally

```bash
python3 -m http.server -d site 8000
```

Then open http://localhost:8000/. The links point at the host's paths, so they
only resolve on the host.
