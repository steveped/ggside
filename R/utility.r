#' @import ggplot2
#' @import grid
#' @importFrom grid grobName


"%||%" <- function(a, b) {
  if (!is.null(a)) a else b
}


ggname <- function(prefix, grob) {
  grob$name <- grobName(grob, prefix)
  grob
}


empty <- function(df) {
  is.null(df) || nrow(df) == 0 || ncol(df) == 0 || is.waive(df)
}

manual_scale <- function(aesthetic, values = NULL, breaks = waiver(), ...) {
  # check for missing `values` parameter, in lieu of providing
  # a default to all the different scale_*_manual() functions
  if (is_missing(values)) {
    values <- NULL
  } else {
    force(values)
  }

  # order values according to breaks
  if (is.vector(values) && is.null(names(values)) && !is.waive(breaks) &&
      !is.null(breaks) && !is.function(breaks)) {
    if (length(breaks) <= length(values)) {
      names(values) <- breaks
    } else {
      names(values) <- breaks[1:length(values)]
    }
  }

  pal <- function(n) {
    if (n > length(values)) {
      abort(glue("Insufficient values in manual scale. {n} needed but only {length(values)} provided."))
    }
    values
  }
  discrete_scale(aesthetic, "manual", pal, breaks = breaks, ...)
}


is.waive <- function(x) inherits(x, "waiver")

uniquecols <- function(df) {
  df <- df[1, sapply(df, function(x) length(unique(x)) == 1), drop = FALSE]
  rownames(df) <- 1:nrow(df)
  df
}



rbind_dfs <- function(dfs) {
  out <- list()
  columns <- unique(unlist(lapply(dfs, names)))
  nrows <- vapply(dfs, .row_names_info, integer(1), type = 2L)
  total <- sum(nrows)
  if (length(columns) == 0) return(new_data_frame(list(), total))
  allocated <- rep(FALSE, length(columns))
  names(allocated) <- columns
  col_levels <- list()
  ord_levels <- list()
  for (df in dfs) {
    new_columns <- intersect(names(df), columns[!allocated])
    for (col in new_columns) {
      if (is.factor(df[[col]])) {
        all_ordered <- all(vapply(dfs, function(df) {
          val <- .subset2(df, col)
          is.null(val) || is.ordered(val)
        }, logical(1)))
        all_factors <- all(vapply(dfs, function(df) {
          val <- .subset2(df, col)
          is.null(val) || is.factor(val)
        }, logical(1)))
        if (all_ordered) {
          ord_levels[[col]] <- unique(unlist(lapply(dfs, function(df) levels(.subset2(df, col)))))
        } else if (all_factors) {
          col_levels[[col]] <- unique(unlist(lapply(dfs, function(df) levels(.subset2(df, col)))))
        }
        out[[col]] <- rep(NA_character_, total)
      } else {
        out[[col]] <- rep(.subset2(df, col)[1][NA], total)
      }
    }
    allocated[new_columns] <- TRUE
    if (all(allocated)) break
  }
  is_date <- lapply(out, inherits, 'Date')
  is_time <- lapply(out, inherits, 'POSIXct')
  pos <- c(cumsum(nrows) - nrows + 1)
  for (i in seq_along(dfs)) {
    df <- dfs[[i]]
    rng <- seq(pos[i], length.out = nrows[i])
    for (col in names(df)) {
      date_col <- inherits(df[[col]], 'Date')
      time_col <- inherits(df[[col]], 'POSIXct')
      if (is_date[[col]] && !date_col) {
        out[[col]][rng] <- as.Date(
          unclass(df[[col]]),
          origin = ggplot_global$date_origin
        )
      } else if (is_time[[col]] && !time_col) {
        out[[col]][rng] <- as.POSIXct(
          unclass(df[[col]]),
          origin = ggplot_global$time_origin
        )
      } else if (date_col || time_col || inherits(df[[col]], 'factor')) {
        out[[col]][rng] <- as.character(df[[col]])
      } else {
        out[[col]][rng] <- df[[col]]
      }
    }
  }
  for (col in names(ord_levels)) {
    out[[col]] <- ordered(out[[col]], levels = ord_levels[[col]])
  }
  for (col in names(col_levels)) {
    out[[col]] <- factor(out[[col]], levels = col_levels[[col]])
  }
  attributes(out) <- list(
    class = "data.frame",
    names = names(out),
    row.names = .set_row_names(total)
  )
  out
}

