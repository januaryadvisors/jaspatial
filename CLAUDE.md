# CLAUDE.md — jaspatial

Shared geospatial helpers for January Advisors. Consumed by ~20 repos via
`library(jaspatial)`. Read this before editing.

## What this package is

Four original functions (`ja_base_map`, `clean_shape`, `load_geo_packages`,
`set_geo_options`) plus the CARTO basemap layer added in 0.2.0. Two packaged
datasets, `tx_counties` and `wgs84`.

## Traps in this package specifically

**`NAMESPACE` is `exportPattern("^[[:alpha:]]+")`, not roxygen-managed.** Every object
whose name starts with a letter is exported whether you tagged it `@export` or not,
including datasets. **Name internals with a leading dot** (`.carto_key`,
`.CARTO_VARIANTS`) or they land in the public API. Adding `@export` tags does nothing;
roxygen will not narrow the pattern unless someone deliberately rewrites NAMESPACE.

**A package cannot read files at load time.** `here::here()` inside an installed package
resolves against the *consumer's* project, not this one. The `.env` read in
`ja_carto_key()` is lazy, inside the accessor, guarded by both `requireNamespace()` and
`file.exists()`. The version this was lifted from
(`purpose-built/helpers/basemap.R`) called `dotenv::load_dot_env(here::here(".env"))` at
file top level, which is fine in a repo script and wrong here. Follow `jastyle/R/zzz.R`
for the pattern: guarded, wrapped in `try()`, never blocks `library()`.

**Optional dependencies belong in Suggests and must be `requireNamespace()`-guarded.**
`dotenv`, `config` and `here` are all optional; the package works without any of them.

## CARTO basemaps

CARTO watermarks raster tiles requested without an API key. See `R/carto.R`, whose header
comment carries the reasoning; the essentials:

**`addProviderTiles()` can never carry a key.** Its URL is resolved at runtime by the
bundled leaflet-providers JS, and the CartoDB entry in that registry has no `{apikey}`
placeholder, though several other providers do (verified in leaflet.providers 3.0.0,
line ~729). Keyed maps must pass the URL explicitly through `addTiles()`.

**Two tile options are load-bearing.** `addProviderTiles` inherited `maxZoom = 20` and
`subdomains = "abcd"` from the provider registry; `addTiles` defaults to `maxZoom = 18`,
which silently costs two zoom levels on every map. Both are set explicitly in
`.carto_tile_options()`. The URL uses the `{s}.basemaps.cartocdn.com` host form so
`subdomains` actually shards.

**The key is public by design.** It ships in rendered HTML because that is how browser
basemaps work. Keeping it out of the source tree is about rotation, not secrecy. It is
currently **not domain-restricted** (tested: clean tiles from any referer, including
none), so anyone can lift it from a published page. Restricting it in the CARTO dashboard
is worth doing, but the PBC dashboards are iframed on client sites, so those domains need
allowlisting or they start watermarking.

**Missing key warns, never stops.** ~20 JA map apps deploy to shinyapps.io, which does not
carry a project `.env`. Hard-failing would mean a broken deploy instead of a watermark.
The warning fires once per session via `.jaspatial_state`, because `ja_base_map()` adds
two tile layers and a naive warning fires twice per map.

## `ja_audit_basemaps()` — both failure modes it was calibrated against

Changing the matching logic risks reintroducing one of these. Both were real, found by
running it against repos whose state was already known.

**False positive:** `LeafletWidget.methods.addProviderTiles = function(...)` is *defined*
in the leaflet binding on every leaflet page, called or not. Matching the bare identifier
flagged 8 clean pages. It now matches the serialized `"method":"addProviderTiles"` call
and captures the provider name, so only CartoDB calls count.

**False negative:** a page that loads leaflet-providers from a CDN calls
`addProviderTiles("CartoDB.Positron")` without the string `cartocdn.com` appearing
anywhere in the file. Gating on that string alone missed 9 genuinely watermarked pages.
The no-basemap check needs both signals absent.

An unkeyed `.../{variant}/...` template inside bundled providers JS is inert unless
something calls it, so it is reported as `latent`, not as a finding.

Calibration targets: `purpose-built/docs` should come back clean (89 basemaps, all keyed);
`civicap-data-creation` should report ~68 unkeyed.

## Shipping a change

No CI, no version pinning. Push to `januaryadvisors/jaspatial` and each consumer picks it
up on its next `remotes::install_github()`. **Promoting a fix here does not retroactively
fix anything already rendered or deployed.**

Bump `Version:` in DESCRIPTION, run `roxygen2::roxygenise(".")`, install, test, commit
`man/` alongside `R/`.

`devtools::build_readme()` currently fails in this environment for two pre-existing
reasons: a missing `proj.db` (PROJ/sf config) and the leaflet widget in the README not
rendering to GitHub markdown. Edit `README.Rmd` and mirror prose changes into `README.md`
by hand until that is sorted.

## Known machine issue: `install_github()` fails on David's machine

A stray `econ_scan_perfile.csv` sits in
`/Library/Frameworks/R.framework/Resources/bin/exec/` (dated 2026-07-27). R lists that
directory to enumerate sub-architectures, so **every** source-package install tries to
build for an architecture named after the CSV and fails:

```
ERROR: sub-architecture 'econ_scan_perfile.csv' is not installed
```

Confirmed pre-existing by reproducing it on an older jaspatial commit. Affects any
package, not just this one. `devtools::install(".")` from a local checkout still works.
Deleting the stray file fixes it; it has not been deleted because it sits in a system
path.
