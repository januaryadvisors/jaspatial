# Package-local mutable state. Currently only tracks whether the missing-key
# warning has fired, so it shows once per session rather than once per tile layer.
.jaspatial_state <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  .jaspatial_state$warned_carto <- FALSE
}
