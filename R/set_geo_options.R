
#' Set options of spatial analysis
#'
#' Set the options for tigris and other spatial packages at start of analysis
#' @return
#' @export
#'
#' @examples
#' set_geo_options()
set_geo_options <- function() {

  options(tigris_class = "sf",
          tigris_use_cache = TRUE)

  sf_use_s2(F)

}
