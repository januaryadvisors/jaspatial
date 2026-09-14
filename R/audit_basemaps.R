#' Find rendered pages whose basemaps will be watermarked
#'
#' Scans HTML for maps that request CARTO tiles without an API key, which CARTO
#' serves with "API KEY REQUIRED" stamped across them.
#'
#' Two things count as a real problem:
#' \itemize{
#'   \item a serialized \code{"method":"addProviderTiles"} call, which always
#'     resolves to an unkeyed URL because the CartoDB entry in the leaflet-providers
#'     registry has no key placeholder
#'   \item a concrete \code{basemaps.cartocdn.com} tile URL with no \code{key=}
#' }
#'
#' Two things deliberately do not:
#' \itemize{
#'   \item \code{LeafletWidget.methods.addProviderTiles = function(...)}, the
#'     method definition that ships with every leaflet page whether or not it is used
#'   \item the unkeyed \code{.../{variant}/...} URL template inside the bundled
#'     leaflet-providers JS, which is inert unless something calls it. This is
#'     counted as \code{latent} and reported only as a footnote.
#' }
#'
#' Worth running after any render and before publishing. A page regresses
#' silently: nothing errors, the tiles just come back stamped.
#'
#' @param path Directory or single HTML file to scan. Defaults to the working
#'   directory.
#' @param recursive Recurse into subdirectories. Defaults to TRUE.
#' @param quiet Suppress the console summary and return the data frame only.
#'
#' @return A data frame with one row per file: \code{file}, \code{keyed},
#'   \code{unkeyed}, \code{latent}, \code{status}. Returned invisibly unless
#'   \code{quiet = TRUE}, since the printed summary is the point interactively.
#' @export
#'
#' @examples
#' \dontrun{
#' ja_audit_basemaps("docs")
#' bad <- ja_audit_basemaps("docs", quiet = TRUE)
#' subset(bad, status == "unkeyed")$file
#' }
ja_audit_basemaps <- function(path = ".", recursive = TRUE, quiet = FALSE) {

  files <- if (dir.exists(path)) {
    list.files(path, pattern = "\\.html?$", recursive = recursive,
               full.names = TRUE, ignore.case = TRUE)
  } else if (file.exists(path)) {
    path
  } else {
    stop("No such file or directory: ", path, call. = FALSE)
  }

  if (length(files) == 0L) {
    if (!quiet) message("No HTML files found under ", path)
    return(invisible(.empty_audit()))
  }

  rows <- lapply(files, .audit_one)
  out <- do.call(rbind, rows)
  out <- out[order(out$status != "unkeyed", out$file), , drop = FALSE]
  rownames(out) <- NULL

  if (quiet) return(out)

  bad <- sum(out$status == "unkeyed")
  maps <- sum(out$status %in% c("keyed", "unkeyed"))
  latent <- sum(out$latent > 0L & out$status != "unkeyed")

  message(sprintf("Scanned %d file%s under %s; %d draw a basemap.",
                  nrow(out), if (nrow(out) == 1L) "" else "s", path, maps))
  if (bad == 0L) {
    message("All basemaps are keyed.")
  } else {
    message(sprintf("%d page%s will render watermarked:", bad,
                    if (bad == 1L) "" else "s"))
    for (f in out$file[out$status == "unkeyed"]) message("  ", f)
    message("\nRe-render with jaspatial (>= 0.2.0) loaded. For pages that must not ",
            "be\nre-rendered, key the tiles in place instead.")
  }
  if (latent > 0L) {
    message(sprintf("\n(%d page%s carry an unkeyed URL template in bundled ",
                    latent, if (latent == 1L) "" else "s"),
            "leaflet-providers JS.\nInert while nothing calls it, so not counted above.)")
  }
  invisible(out)
}

.audit_one <- function(f) {
  txt <- tryCatch(
    paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
    error = function(e) NA_character_
  )
  if (is.na(txt)) {
    return(.audit_row(f, NA_integer_, NA_integer_, NA_integer_, "unreadable"))
  }

  # Provider calls, as serialized into the widget payload, with the provider name
  # captured so we only count CARTO ones. Matching the JSON form rather than the
  # bare identifier matters: LeafletWidget.methods.addProviderTiles is defined in
  # the leaflet binding on every leaflet page whether or not it is ever called.
  providers <- .match_group(
    txt, '"method"\\s*:\\s*"addProviderTiles"\\s*,\\s*"args"\\s*:\\s*\\[\\s*"([^"]+)"'
  )
  calls <- sum(grepl("^CartoDB", providers))

  # Nothing to key if the page neither names a CARTO tile host nor calls a CARTO
  # provider. Both checks are needed: a page that loads leaflet-providers from a
  # CDN calls addProviderTiles("CartoDB.Positron") without the string
  # "cartocdn.com" appearing anywhere in the file.
  if (!grepl("cartocdn\\.com", txt) && calls == 0L) {
    return(.audit_row(f, 0L, 0L, 0L, "no basemap"))
  }

  urls <- regmatches(txt, gregexpr("https?://[^\"'\\\\ ]*cartocdn\\.com[^\"'\\\\ ]*",
                                   txt, perl = TRUE))[[1]]
  keyed <- sum(grepl("[?&]key=", urls))
  # {variant} means the provider-registry template, not a real tile request.
  is_template <- grepl("\\{variant\\}", urls, perl = TRUE)
  latent <- sum(is_template & !grepl("[?&]key=", urls))
  concrete_unkeyed <- sum(!is_template & !grepl("[?&]key=", urls))

  unkeyed <- calls + concrete_unkeyed
  status <- if (unkeyed > 0L) "unkeyed" else "keyed"
  .audit_row(f, keyed, unkeyed, latent, status)
}

.audit_row <- function(file, keyed, unkeyed, latent, status) {
  data.frame(file = file, keyed = keyed, unkeyed = unkeyed, latent = latent,
             status = status, stringsAsFactors = FALSE)
}

.empty_audit <- function() {
  data.frame(file = character(), keyed = integer(), unkeyed = integer(),
             latent = integer(), status = character(), stringsAsFactors = FALSE)
}

.match_group <- function(txt, pattern) {
  m <- regmatches(txt, gregexpr(pattern, txt, perl = TRUE))[[1]]
  if (length(m) == 0L) return(character())
  sub(pattern, "\\1", m, perl = TRUE)
}

.count_matches <- function(txt, pattern) {
  m <- gregexpr(pattern, txt, perl = TRUE)[[1]]
  if (length(m) == 1L && m[1] == -1L) 0L else length(m)
}
