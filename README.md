# chap-sandbox

The front page of https://chap-sandbox.dhis2.org, the NREC host where the Chap
team publishes static things: learning material, demos and simple mockups. The
host itself is described in
[dhis2-chap/climate-sre](https://github.com/dhis2-chap/climate-sre) under
`hosts/chap-sandbox/`.

`site/index.html` is the whole page: plain HTML with inline CSS, no build step
and no dependencies. It links to what is served on the host. When a directory
is added to the host (see "Content" in the climate-sre README), add a link to
it here, since the front page replaced the directory listing at `/`.

## Deploy

The page is copied by hand to the web root on the host, as the `ubuntu` user:

```bash
rsync -az site/index.html ubuntu@158.39.75.126:/mnt/data/www/index.html
```

It is live at once; pages on the host are served with `Cache-Control: no-cache`,
so a reload shows the new version.

## Check locally

```bash
python3 -m http.server -d site 8000
```

Then open http://localhost:8000/. The links point at the host's paths, so they
only resolve on the host.
