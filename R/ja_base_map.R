#' Create JA base map layer in leaflet
#'
#' Use the standard JA base map layer in leaflet.
#' It includes OSM address search, easyPrint, and map label tiles on top.
#' You can also set the initial coordinates and zoom level for your map. Defaults to Harris County, TX.
#' One catch is that you must specify any heatmap layers with mapPane argument; see example below.
#'
#' @param .lon Longitude for setting center of map
#' @param .lat Latitude for setting center of map
#' @param .zoom_level Zoom level for setting map
#'
#' @return
#' @export
#'
#' @examples
#' ja_base_map()
ja_base_map <- function(.lon = -95.3103, .lat = 29.7752, .zoom_level = 9) {

  leaflet::leaflet() %>%
    leaflet::addTiles(attribution = htmltools::HTML("Built by <a href='https://www.januaryadvisors.com/' target='_blank'>January Advisors</a>")) %>%
    leaflet::addMapPane(name = "polygons", zIndex = 410) %>%
    leaflet::addMapPane(name = "maplabels", zIndex = 420) %>%
    leaflet::addProviderTiles("CartoDB.PositronNoLabels") %>%
    leaflet::addProviderTiles("CartoDB.PositronOnlyLabels",
                     options = leaflet::leafletOptions(pane = "maplabels"),
                     group = "map labels") %>%
    leaflet::setView(.lon, .lat, zoom = .zoom_level) %>%
    leaflet.extras2::addEasyprint(options = leaflet.extras2::easyprintOptions(
      title = 'Print map',
      position = 'topleft',
      exportOnly = TRUE)) %>%
    leaflet.extras::addSearchOSM(
      options = leaflet.extras::searchFeaturesOptions(zoom = 10, openPopup = TRUE,
                                      position = "topright",
                                      hideMarkerOnCollapse = TRUE)
    )

}
