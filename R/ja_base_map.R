#' Create JA base map layer in leaflet
#'
#' Use the standard JA base map layer in leaflet.
#' It includes OSM address search, easyPrint, and map label tiles on top.
#' You can also set the initial coordinates and zoom level for your map. Defaults to Harris County, TX.
#' One catch is that you must specify any heatmap layers with mapPane argument; see example below.
#'
#' Basemap tiles come from CARTO and need an API key, or they render watermarked.
#' See \code{\link{ja_carto_key}} for where the key is read from; the short version
#' is to put \code{CARTO_API_KEY=...} in your \code{~/.Renviron}.
#'
#' @param .lon Longitude for setting center of map
#' @param .lat Latitude for setting center of map
#' @param .zoom_level Zoom level for setting map
#' @param .minZoom Set minimum Zoom level for map
#' @param .maxZoom Set max zoom level for map
#' @param .dragging turn dragging ability on/off, defaults False
#' @param .tap turn tap ability on/off, default False
#' @param .variant CARTO basemap style. Defaults to Positron. Pass any
#'   leaflet-provider name (\code{"CartoDB.DarkMatter"}) and the matching
#'   no-labels and labels-only layers are chosen for you.
#'
#' @examples
#' ja_base_map() %>%
#' leaflet::addPolygons(
#' data = clean_tx_counties,
#' options = leaflet::leafletOptions(pane = "polygons")
#' )

ja_base_map <- function(.lon = -95.3103, .lat = 29.7752, .zoom_level = 9,
                        .minZoom = 0, .maxZoom=18, .dragging = T, .tap=T,
                        .variant = "CartoDB.Positron") {

  # Resolve the style to its no-labels / labels-only pair, so a caller can switch
  # the whole map to DarkMatter or Voyager with one argument.
  base_slug <- .carto_variant(.variant)
  nolabels <- sub("_all$", "_nolabels", base_slug)
  onlylabels <- sub("_all$", "_only_labels", base_slug)
  if (identical(base_slug, "rastertiles/voyager")) {
    nolabels <- "rastertiles/voyager_nolabels"
    onlylabels <- "rastertiles/voyager_only_labels"
  }

  leaflet::leaflet(
    options = leaflet::leafletOptions(minZoom = .minZoom, maxZoom = .maxZoom,
                                      dragging = .dragging, tap = .tap)
  ) %>%
    leaflet::addMapPane(name = "polygons", zIndex = 410) %>%
    leaflet::addMapPane(name = "maplabels", zIndex = 420) %>%
    # The basemap carries the attribution. Previously a bare addTiles() fetched a
    # whole OSM layer underneath these tiles purely to hold the JA credit; it was
    # invisible and is gone. Its OpenStreetMap attribution is folded in here,
    # which CARTO's terms require anyway.
    add_carto_basemap(
      variant = nolabels,
      attribution = htmltools::HTML(
        paste0(.JA_ATTRIBUTION, " | ", .CARTO_ATTRIBUTION)
      )
    ) %>%
    add_carto_labels(variant = onlylabels, pane = "maplabels",
                     group = "map labels") %>%
    leaflet::setView(.lon, .lat, zoom = .zoom_level) %>%
    leaflet.extras2::addEasyprint(
      options = leaflet.extras2::easyprintOptions(
        title = 'Print map',
        position = 'topleft',
        exportOnly = TRUE
      )
    ) %>%
    leaflet.extras::addSearchOSM(
      options = leaflet.extras::searchFeaturesOptions(
        zoom = 10,
        openPopup = TRUE,
        position = "topright",
        hideMarkerOnCollapse = TRUE
      )
    )

}
