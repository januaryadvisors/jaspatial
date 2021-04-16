
#' Clean sf data objects
#'
#' This function uses janitor::clean_names() to standardize headers and sets crs to wgs84 by default.
#' Data must already by in sf format.
#'
#' @param .data spatial sf data object
#' @param .crs st_crs formatted projection; defaults to wgs84
#'
#' @return
#' @export
#'
#' @examples
#' tx_counties <- clean_shape(tx_counties)
clean_shape <- function(.data, .crs = wgs84) {
  crs <- .crs

  data <- .data %>%
    janitor::clean_names() %>%
    sf::st_transform(.crs)

  return(data)
}
