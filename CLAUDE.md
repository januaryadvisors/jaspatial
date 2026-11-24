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

## Two keys: production and local (0.3.0)

The production key (`CARTO_API_KEY`) is domain-restricted, so it watermarks on David's
machine. CARTO's rule: a key that lists `localhost`, `127.0.0.1` or `*.localhost` cannot
also list public sites, and `[::1]` is not supported. So local work needs a second key,
`CARTO_API_KEY_LOCAL`, resolved by `ja_carto_key_local()` through the same chain as
`ja_carto_key()` (option `jaspatial.carto_key_local` first). Both share `.carto_lookup()`.

**Precedence:** option, then project `.env`, then `Sys.getenv()` (`~/.Renviron`), then
`config.yml` (`carto: CARTO_API_KEY_LOCAL`).

**Why the switch is in the browser, not at render time.** Static pages are rendered on
David's machine and then published (purpose-built docs on GitHub Pages). At render time
there is no way to know whether a file will be previewed or published, so picking a key
in R would either watermark the published page or bake in the wrong key. Instead the tile
URL always carries the production key, and `.carto_local_swap()` attaches an `onRender`
hook that rewrites `key=` to the local key only when the hostname is `localhost`,
`127.0.0.1` or `*.localhost`. That covers the RStudio/Positron viewer, local Shiny and
local preview servers. shinyapps.io, GitHub Pages and client iframes keep the production
key (verified with Playwright, 2026-11-24).

**`file://` cannot work with either key.** Browsers send no Referer from a file opened
off disk, and CARTO answers 403 to a keyed request without one (curl-tested both keys,
2026-11-24: production key 200 only on its domains; local key 200 on 127.0.0.1 and
localhost, 403 on github.io and with no Referer). Off-domain requests get a 403 and a
blank tile, not the watermark; the watermark is for unkeyed requests. Preview knitted
HTML through a local server (`servr::httd()`, `python3 -m http.server`).

**The local key ships in every page rendered on a machine that has it.** That is safe only
because CARTO refuses it on public domains. `ja_audit_basemaps()` reports these pages in
its `local_switch` column and says so in its summary; that is expected, not a finding.

**No local key, no change.** `.carto_local_swap()` returns the map untouched, so teammates
and CI render byte-for-byte what 0.2.0 did. The hook is added once per map (it checks for
`.CARTO_LOCAL_MARKER` in `map$jsHooks`), though `ja_base_map()` adds two tile layers.

**Not covered:** tile layers added later through `leaflet::leafletProxy()`.

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

Calibration targets: `purpose-built/docs` should come back clean (90 basemaps, all keyed,
as of 2026-11-24); `civicap-data-creation` reported ~68 unkeyed in September and 46 on
2026-11-24 after some pages were keyed. Re-baseline with the previous commit's audit code
before blaming a change.

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
