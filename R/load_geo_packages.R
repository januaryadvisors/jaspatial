#' Load geospatial packages
#'
#' Automatically loads geospatial suite of packages for analysis, including
#' sf, tigris, tidycensus, leaflet, and more.
#' @return
#' @export
#'
#' @examples
#' load_geo_packages()
load_geo_packages <- function() {
  pacman::p_load(sf,
         tigris,
         tidycensus,
         mapview,
         leaflet,
         rmapshaper,
         leaflet.extras,
         leaflet.extras2
         )
}
