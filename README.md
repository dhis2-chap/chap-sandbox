# chap-sandbox

The front page of https://chap-sandbox.dhis2.org, the NREC host where the Chap
team publishes static things: learning material, demos and simple mockups. The
host itself is described in
[dhis2-chap/climate-sre](https://github.com/dhis2-chap/climate-sre) under
`hosts/chap-sandbox/`.

`site/index.html` is the whole page: plain HTML with inline CSS, no build step
and no dependencies. It links to what is served on the host. When something new
is published there (see below), add a link to it here, since the front page
replaced the directory listing at `/`.

## Publishing something new

Every directory under `/mnt/data/www/` on the host is served at
`https://chap-sandbox.dhis2.org/<directory>/`: its `index.html` if it has one,
otherwise a file listing. The directory name is the URL path. There are three
ways to put something there, from simplest to most work.

Whichever you pick:

- **Everything is public** as soon as it is on the host, with no login. No
  credentials, personal data, partner details or unpublished results.
- **Keep the source in a GitHub repository**, even for a one-off demo. The host
  is not where the source lives: files copied there by hand exist only there,
  so the repository is how they get back if the host is rebuilt, and how
  others find and change them.
- **Add a link** to `site/index.html` in this repository, or the page is only
  reachable by its URL.
- **To take something down**, delete its directory on the host and its link
  here.

### 1. Static files, copied by hand

For a demo or mockup that rarely changes: a directory of HTML, CSS, JavaScript
and images, or a built site with relative paths. Someone with SSH access to the
host as `ubuntu` copies it there:

```bash
rsync -az --delete ./my-demo/ ubuntu@158.39.75.126:/mnt/data/www/my-demo/
```

It is live at once at `https://chap-sandbox.dhis2.org/my-demo/`. Only the people
who maintain the host have that SSH access (the keys are listed in climate-sre),
so if you are not one of them, ask one of them and say which repository and
directory to copy.

### 2. Deployed from its own repository on every push

For something that changes often, do what this repository and
[learning-material](https://github.com/dhis2-chap/learning-material) do: a
GitHub Actions workflow rsyncs the build to the host on every push to `main`.
That needs one-time setup on both sides.

On the host (someone with SSH access, as above):

1. Create `/mnt/data/www/<directory>`, owned by `deploy`.
2. Generate a new ED25519 key pair for the repository. Add the public half to
   `/home/deploy/.ssh/authorized_keys` with the prefix
   `restrict,command="/usr/bin/rrsync /mnt/data/www/<directory>"`, so the key can
   write to that directory and nothing else.
3. Record the key in the climate-sre README for the host, beside the existing
   ones.

In the repository:

1. Store the private half as the repository secret `CHAP_SANDBOX_SSH_KEY`, then
   delete every other copy of it.
2. Copy [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) from this
   repository and change `site/` to the directory your build writes. Keep the
   pinned host key line.
3. Build with relative asset paths (Vite: `base: './'`), so the site works under
   `/<directory>/`.

### 3. Something that needs a server

An API or anything else that runs a process, like learning-material's quiz
answers service at `/quiz-api`, is a Docker Compose stack on the host with a
Traefik route, both kept in climate-sre under `hosts/chap-sandbox/`. That is a
change to the host, so agree it with the people who maintain it first.

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
