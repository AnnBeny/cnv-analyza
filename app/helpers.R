# app/helpers.R

# Normalize coverage data for a group
normalize_coverage <- function(df) {
  df[] <- lapply(df, function(x) as.numeric(gsub(",", ".", as.character(x))))
  norm <- df / vapply(df, median, numeric(1))[col(df)]
  centered <- norm - rowMeans(norm, na.rm = TRUE)
  return(centered)
}

# Load OMIM reference file safely
load_omim_file <- function(path = "../reference/gen-phenotyp2-uniq_omim.txt") { #nolint
  if (!file.exists(path)) return(NULL)
  df <- tryCatch({
    read.table(path, header = TRUE, sep = "\t", stringsAsFactors = FALSE,
               fill = TRUE, colClasses = c("character", "character"))
  }, error = function(e) {
    showNotification("Chyba při načítání OMIM souboru.", type = "error")
    return(NULL)
  })
  df[] <- lapply(df, trimws)
  return(df)
}

# Apply OMIM annotation to result - stara verze, prirovnani podle nazvu genu
# annotate_with_omim <- function(result_df, omim_df) {
#   if (is.null(omim_df) || !"Name" %in% colnames(result_df)) {
#     result_df$OMIM <- "N/A"
#     return(result_df)
#   }
#   match_idx <- match(result_df$Name, omim_df$gene)
#   result_df$OMIM <- ifelse(!is.na(match_idx), omim_df$OMIM[match_idx], "N/A")
#   return(result_df)
# }

# Apply OMIM annotation to result - stara verze, prirovnani podle regionu (z naseho bedu)
annotate_with_omim <- function(result_df, omim_df) {
  if (is.null(omim_df) || !"Name" %in% colnames(result_df)) {
    result_df$OMIM <- "N/A"
    return(result_df)
  }

  if (!all(c("gene", "OMIM") %in% colnames(omim_df))) {
    result_df$OMIM <- "N/A"
    return(result_df)
  }

  # Clean whitespace, but do NOT split genes by comma.
  result_df$Name <- trimws(as.character(result_df$Name))
  omim_df$gene <- trimws(as.character(omim_df$gene))
  omim_df$OMIM <- trimws(as.character(omim_df$OMIM))

  match_idx <- match(result_df$Name, omim_df$gene)

  result_df$OMIM <- ifelse(
    !is.na(match_idx),
    omim_df$OMIM[match_idx],
    "N/A"
  )

  return(result_df)
}