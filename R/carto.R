# Keyed CARTO basemaps.
#
# CARTO watermarks raster basemap tiles requested without an API key, so the
# addProviderTiles("CartoDB.*") calls JA has used for years now render with
# "API KEY REQUIRED" stamped across the map.
#
# addProviderTiles() cannot carry a key. Its URL is resolved at runtime by the
# bundled leaflet-providers JS, and the CartoDB entry in that registry has no
# {apikey} placeholder (other providers do, CartoDB does not). So keyed maps have
# to pass the URL explicitly through addTiles().
#
# The key is used client-side and is therefore visible in any rendered HTML. That
# is inherent to browser basemaps and is CARTO's intended model. Keeping it out of
# the source tree still matters for rotation, not secrecy. Restrict the key by
# domain in the CARTO dashboard, remembering that dashboards iframed on client
# sites need those domains allowed too.

# Provider-name and slug aliases. Values are the CARTO variant path segment.
# Lifted from purpose-built/rscripts/patch_carto_basemap_key.R and extended past
# Positron, because the JA fleet also uses DarkMatter and Voyager.
.CARTO_VARIANTS <- c(
  "CartoDB.Positron"            = "light_all",
  "CartoDB.PositronNoLabels"    = "light_nolabels",
  "CartoDB.PositronOnlyLabels"  = "light_only_labels",
  "CartoDB.DarkMatter"          = "dark_all",
  "CartoDB.DarkMatterNoLabels"  = "dark_nolabels",
  "CartoDB.DarkMatterOnlyLabels" = "dark_only_labels",
  "CartoDB.Voyager"             = "rastertiles/voyager",
  "CartoDB.VoyagerNoLabels"     = "rastertiles/voyager_nolabels",
  "CartoDB.VoyagerOnlyLabels"   = "rastertiles/voyager_only_labels"
)

.carto_variant <- function(variant) {
  if (length(variant) != 1L || !is.character(variant) || is.na(variant)) {
    stop("`variant` must be a single string.", call. = FALSE)
  }
  if (variant %in% names(.CARTO_VARIANTS)) {
    return(unname(.CARTO_VARIANTS[[variant]]))
  }
  # Already a raw CARTO slug, e.g. "light_all".
  variant
}

# Attribution CARTO requires, which also carries the OpenStreetMap credit.
.CARTO_ATTRIBUTION <- paste0(
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> ',
  'contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
)

.JA_ATTRIBUTION <- paste0(
  "Built by <a href='https://www.januaryadvisors.com/' target='_blank'>",
  "January Advisors</a>"
)

#' Resolve the CARTO basemap API key
#'
#' Looks in four places, in order, and returns the first non-empty value:
#'
#' \enumerate{
#'   \item \code{getOption("jaspatial.carto_key")}, a session-level override
#'   \item \code{CARTO_API_KEY} in a project \code{.env} (needs the dotenv package)
#'   \item \code{Sys.getenv("CARTO_API_KEY")}, which covers \code{~/.Renviron},
#'     CI secrets, and \code{rsconnect::deployApp(envVars = "CARTO_API_KEY")}
#'   \item a \code{carto: CARTO_API_KEY} entry in \code{config.yml} (needs the
#'     config package)
#' }
#'
#' A project \code{.env} deliberately beats \code{Sys.getenv()} so that a
#' project-specific key wins over a machine-wide default in \code{~/.Renviron}.
#'
#' Setting it once in \code{~/.Renviron} is the simplest setup and covers every
#' project on your machine:
#' \code{CARTO_API_KEY=your_key_here}
#'
#' If this key is restricted to your published domains, add a second,
#' localhost-only key as \code{CARTO_API_KEY_LOCAL} so maps you view on your
#' own machine are not watermarked. See \code{\link{ja_carto_key_local}}.
#'
#' @return The key, or \code{""} when none is configured.
#' @export
#'
#' @examples
#' \dontrun{
#' nzchar(ja_carto_key())
#' }
ja_carto_key <- function() {
  .carto_lookup("CARTO_API_KEY", "jaspatial.carto_key", config_alias = "key")
}

#' Resolve the local-development CARTO key
#'
#' CARTO keys restricted to public domains watermark tiles on your own machine.
#' CARTO's answer is a second key that lists only \code{localhost},
#' \code{127.0.0.1} and \code{*.localhost} (a key that lists those cannot also
#' list public sites). Set it as \code{CARTO_API_KEY_LOCAL}, looked up in the
#' same places as \code{\link{ja_carto_key}}, with the option
#' \code{jaspatial.carto_key_local} first.
#'
#' When it is set, \code{add_carto_basemap()} and \code{add_carto_labels()} keep
#' the production key in the tile URL and add a small script that switches to
#' the local key only when the page is served from \code{localhost},
#' \code{127.0.0.1} or \code{*.localhost}: the RStudio or Positron viewer, a local
#' Shiny app, or a local preview server. Published pages
#' keep using the production key. The switch happens in the browser because a
#' rendered HTML file cannot know at render time whether it will be published.
#'
#' The local key therefore ships inside every page rendered on a machine that has
#' it. That is safe only because CARTO refuses it on any public domain.
#'
#' An HTML file opened straight from disk (\code{file://}) shows no basemap with
#' either key, because the browser sends no referrer and CARTO refuses keyed
#' requests without one. Preview it through a local server instead, for example
#' \code{servr::httd()} or \code{python3 -m http.server}.
#'
#' @return The key, or \code{""} when none is configured.
#' @export
#'
#' @examples
#' \dontrun{
#' nzchar(ja_carto_key_local())
#' }
ja_carto_key_local <- function() {
  .carto_lookup("CARTO_API_KEY_LOCAL", "jaspatial.carto_key_local")
}

# One lookup chain for both keys: option, project .env, environment, config.yml.
.carto_lookup <- function(var, option, config_alias = NULL) {
  key <- getOption(option, "")
  if (is.character(key) && length(key) == 1L && nzchar(key)) return(key)

  # A project .env, read lazily. A package must never read files at load time,
  # and here::here() inside an installed package resolves against the *consumer's*
  # project, so this is guarded on every side.
  if (requireNamespace("dotenv", quietly = TRUE)) {
    env_path <- try(
      if (requireNamespace("here", quietly = TRUE)) here::here(".env") else ".env",
      silent = TRUE
    )
    if (!inherits(env_path, "try-error") && length(env_path) == 1L &&
        file.exists(env_path)) {
      # load_dot_env() sets process env vars, so read the value back out after.
      try(dotenv::load_dot_env(env_path), silent = TRUE)
    }
  }

  key <- Sys.getenv(var, "")
  if (nzchar(key)) return(key)

  # config.yml, where five JA map repos already keep map credentials.
  if (requireNamespace("config", quietly = TRUE) && file.exists("config.yml")) {
    cfg <- try(config::get(file = "config.yml"), silent = TRUE)
    if (!inherits(cfg, "try-error") && is.list(cfg)) {
      key <- cfg$carto[[var]] %||%
        (if (!is.null(config_alias)) cfg$carto[[config_alias]]) %||% ""
      if (is.character(key) && length(key) == 1L && nzchar(key)) return(key)
    }
  }

  ""
}

# Marker that identifies the local-key script, so a map with both a basemap and
# a label layer gets it once.
.CARTO_LOCAL_MARKER <- "/* jaspatial: carto local key */"

# Hostnames CARTO accepts on a localhost key. No IPv6: CARTO does not support
# [::1]. file:// pages are left alone: browsers send no Referer from them, and
# CARTO answers 403 to both keys without one (tested 2026-11-24).
.CARTO_LOCAL_JS <- paste0(.CARTO_LOCAL_MARKER, "
function(el, x, data) {
  var h = window.location.hostname;
  var local = h === 'localhost' || h === '127.0.0.1' || /\\.localhost$/.test(h);
  if (!local) return;
  this.eachLayer(function(layer) {
    var url = layer._url;
    if (!(layer instanceof L.TileLayer) || !url ||
        !/basemaps\\.cartocdn\\.com/.test(url)) return;
    url = /[?&]key=/.test(url) ?
      url.replace(/([?&]key=)[^&]*/, '$1' + data.key) :
      url + (url.indexOf('?') > -1 ? '&' : '?') + 'key=' + data.key;
    layer.setUrl(url);
  });
}")

# Attach the local-key switch when a local key is configured. Without one the
# widget is untouched, so teammates and CI render exactly what 0.2.0 did.
.carto_local_swap <- function(map) {
  key <- ja_carto_key_local()
  if (!nzchar(key)) return(map)
  hooks <- map$jsHooks$render
  if (any(vapply(hooks, function(h) startsWith(h$code, .CARTO_LOCAL_MARKER),
                 logical(1)))) {
    return(map)
  }
  htmlwidgets::onRender(map, .CARTO_LOCAL_JS, data = list(key = key))
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# Warn at most once per session. ja_base_map() adds two tile layers, so a naive
# warning fires twice for every map.
.warn_missing_key <- function() {
  if (isTRUE(.jaspatial_state$warned_carto)) return(invisible(NULL))
  .jaspatial_state$warned_carto <- TRUE
  warning(
    "No CARTO_API_KEY found, so basemap tiles will be watermarked ",
    "\"API KEY REQUIRED\".\n",
    "  Fix: add CARTO_API_KEY=<your key> to ~/.Renviron and restart R.\n",
    "  Get a key at https://carto.com/basemaps/apikey/\n",
    "  On shinyapps.io, deploy with ",
    "rsconnect::deployApp(envVars = \"CARTO_API_KEY\").",
    call. = FALSE
  )
  invisible(NULL)
}

#' Build a keyed CARTO tile URL
#'
#' Useful for map stacks other than leaflet that need the raw URL template.
#'
#' @param variant A leaflet-provider name (\code{"CartoDB.Positron"}) or a raw
#'   CARTO slug (\code{"light_all"}).
#'
#' @return A tile URL template. Carries \code{?key=} only when a key is configured.
#' @export
#'
#' @examples
#' \dontrun{
#' ja_carto_tile_url("CartoDB.PositronNoLabels")
#' }
ja_carto_tile_url <- function(variant = "light_all") {
  slug <- .carto_variant(variant)
  key <- ja_carto_key()
  base <- paste0("https://{s}.basemaps.cartocdn.com/", slug, "/{z}/{x}/{y}{r}.png")
  if (!nzchar(key)) {
    .warn_missing_key()
    return(base)
  }
  paste0(base, "?key=", key)
}

# Shared tile options. addProviderTiles() inherited maxZoom 20 and the abcd
# subdomains from the provider registry; addTiles() defaults to maxZoom 18, which
# would silently cost two zoom levels on every zoomable map.
.carto_tile_options <- function(...) {
  leaflet::tileOptions(maxZoom = 20, subdomains = "abcd", ...)
}

#' Add a keyed CARTO basemap to a leaflet map
#'
#' Drop-in replacement for \code{addProviderTiles("CartoDB.Positron")}.
#' When \code{CARTO_API_KEY_LOCAL} is set, the map also switches to that key
#' when viewed locally; see \code{\link{ja_carto_key_local}}. Tile layers added
#' later through \code{leaflet::leafletProxy()} are not switched.
#'
#' @param map A leaflet map
#' @param variant A leaflet-provider name or raw CARTO slug
#' @param attribution Attribution HTML. Defaults to the CARTO and OpenStreetMap
#'   credit, which CARTO's terms require.
#' @param ... Passed to \code{leaflet::addTiles()}
#'
#' @return The map, with the basemap layer added.
#' @export
#'
#' @examples
#' \dontrun{
#' leaflet::leaflet() %>% add_carto_basemap() %>% leaflet::addPolygons(data = shp)
#' }
add_carto_basemap <- function(map, variant = "light_all",
                              attribution = .CARTO_ATTRIBUTION, ...) {
  map <- leaflet::addTiles(
    map,
    urlTemplate = ja_carto_tile_url(variant),
    attribution = attribution,
    options = .carto_tile_options(),
    ...
  )
  .carto_local_swap(map)
}

#' Add a keyed CARTO label layer to a leaflet map
#'
#' The labels-only overlay that sits above polygons in the JA house style. Pair it
#' with a no-labels basemap and a map pane, as \code{ja_base_map()} does.
#'
#' @param map A leaflet map
#' @param variant A leaflet-provider name or raw CARTO slug
#' @param pane Name of the map pane to draw into. The pane must already exist,
#'   via \code{leaflet::addMapPane()}.
#' @param group Layer group name
#' @param ... Passed to \code{leaflet::addTiles()}
#'
#' @return The map, with the label layer added.
#' @export
#'
#' @examples
#' \dontrun{
#' leaflet::leaflet() %>%
#'   leaflet::addMapPane("maplabels", zIndex = 420) %>%
#'   add_carto_basemap("light_nolabels") %>%
#'   add_carto_labels()
#' }
add_carto_labels <- function(map, variant = "light_only_labels",
                             pane = "maplabels", group = "map labels", ...) {
  map <- leaflet::addTiles(
    map,
    urlTemplate = ja_carto_tile_url(variant),
    attribution = NULL,
    options = .carto_tile_options(pane = pane),
    group = group,
    ...
  )
  .carto_local_swap(map)
}
