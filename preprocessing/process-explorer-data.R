#!/usr/bin/env Rscript
#' Process FReD Data for Static Explorer App
#'
#' This script converts the FReD dataset to JSON format for the static web app.
#' It pre-computes all replication outcomes for each success criterion.
#'
#' Usage: Rscript process-explorer-data.R [output_dir]

# Capture any caller-supplied FRED_OFFLINE setting before FReD::.onLoad() sets its default (TRUE)
caller_fred_offline <- Sys.getenv("FRED_OFFLINE", unset = NA_character_)

library(FReD)
library(dplyr)
library(jsonlite)

# Use live online FReD data unless the caller explicitly requested offline mode
use_offline <- identical(toupper(trimws(caller_fred_offline)), "TRUE")
if (!use_offline) {
  use_FReD_offline(FALSE)
}

# Configuration
OUTPUT_DIR <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(OUTPUT_DIR)) {
  OUTPUT_DIR <- "../data"
}

cat("Processing FReD data for static Explorer app...\n")
cat("Output directory:", OUTPUT_DIR, "\n")

# Ensure output directory exists
if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Load FReD data using the package function
cat("Loading FReD data...\n")
if (!use_offline) {
  # Download and verify the live OSF file explicitly before calling load_fred_data().
  # FReD::read_fred() catches download/read errors and silently falls back to the
  # bundled package snapshot; failing fast here ensures CI carries forward the last
  # verified Release bundle rather than publishing stale snapshot data.
  fred_url <- Sys.getenv("FRED_DATA_URL", unset = "")
  if (!nzchar(fred_url)) {
    fred_url <- "https://osf.io/2tbvd/download"
  }
  tmp_fred_xlsx <- tempfile(fileext = ".xlsx")
  df <- tryCatch({
    cat("Downloading live FReD dataset from:", fred_url, "\n")
    dl_status <- utils::download.file(fred_url, tmp_fred_xlsx, mode = "wb", quiet = FALSE)
    if (!identical(as.integer(dl_status), 0L) || !file.exists(tmp_fred_xlsx) || file.info(tmp_fred_xlsx)$size == 0) {
      stop("Failed to download live FReD dataset from ", fred_url)
    }
    # Verify workbook is readable before handing off to FReD::load_fred_data()
    probe_df <- openxlsx::read.xlsx(tmp_fred_xlsx, sheet = 1, rows = 1:5)
    if (!is.data.frame(probe_df) || nrow(probe_df) == 0) {
      stop("Downloaded FReD workbook appears empty or unreadable: ", tmp_fred_xlsx)
    }
    load_fred_data(data = tmp_fred_xlsx, verbose = TRUE)
  }, finally = {
    if (file.exists(tmp_fred_xlsx)) unlink(tmp_fred_xlsx)
  })
} else {
  cat("Using FReD offline mode (FRED_OFFLINE=TRUE)\n")
  df <- load_fred_data(verbose = TRUE)
}

cat("Loaded", nrow(df), "studies\n")

# Define success criteria to pre-compute
CRITERIA <- c(
  "significance_r",
  "significance_agg",
  "consistency_ci",
  "consistency_pi",
  "homogeneity",
  "homogeneity_significance",
  "small_telescopes"
)

# Pre-compute outcomes for all criteria
cat("Pre-computing replication outcomes...\n")

compute_all_outcomes <- function(row) {
  outcomes <- list()

  for (criterion in CRITERIA) {
    tryCatch({
      result <- assess_replication_outcome(
        es_o = row$es_o,
        n_o = row$n_o,
        es_r = row$es_r,
        n_r = row$n_r,
        criterion = criterion
      )

      outcome_val <- result$outcome
      outcome_detailed_val <- result$outcome_detailed
      outcome_report_val <- result$outcome_report

      # FReD's homogeneity_significance returns "not coded" when outcome is NA;
      # normalize to NA_character_ so all computed criteria consistently display "Not calculable".
      if (isTRUE(is.na(outcome_val)) && isTRUE(tolower(outcome_report_val) == "not coded")) {
        outcome_report_val <- NA_character_
      }

      outcomes[[criterion]] <- list(
        outcome = outcome_val,
        outcome_detailed = outcome_detailed_val,
        outcome_report = outcome_report_val
      )
    }, error = function(e) {
      outcomes[[criterion]] <<- list(
        outcome = NA_character_,
        outcome_detailed = NA_character_,
        outcome_report = NA_character_
      )
    })
  }

  outcomes
}

# Process each row
cat("Computing outcomes for each study...\n")
pb <- txtProgressBar(min = 0, max = nrow(df), style = 3)

outcomes_list <- vector("list", nrow(df))
for (i in seq_len(nrow(df))) {
  outcomes_list[[i]] <- compute_all_outcomes(df[i, ])
  setTxtProgressBar(pb, i)
}
close(pb)

# Build the JSON structure
cat("\nBuilding JSON structure...\n")

# Define directional effect types (can detect reversals)
DIRECTIONAL_ES_TYPES <- c(
  "r", "d", "g", "t", "z", "test statistic", "b", "beta",
  "odds ratio", "mean difference", "median difference", "percentage difference",
  "phi", "OR", "hedges' g", "Cohen's d", "dz", "Cohen's dz", "d_sample (dep)",
  "b (unstd)", "beta (std)", "partial r", "partial correlation",
  "semipartial correlation", "rho (spearman's rank cor)", "Wilcoxon r",
  "log_odds_ratio", "hazard ratio", "path_coefficient"
)

# Direction is assessable only when BOTH original and replication use directional
# effect size types and both common-metric effect sizes are available.
is_direction_assessable <- function(es_type_o, es_type_r, es_o, es_r) {
  directional_lower <- tolower(DIRECTIONAL_ES_TYPES)
  !is.na(es_type_o) &
    tolower(as.character(es_type_o)) %in% directional_lower &
    !is.na(es_type_r) &
    tolower(as.character(es_type_r)) %in% directional_lower &
    !is.na(es_o) & !is.na(es_r)
}

# Parse coded p-value comparison operator into one of: ">=", ">", "<=", "<", "="
parse_pval_operator <- function(pval_type) {
  if (is.null(pval_type) || length(pval_type) == 0 || is.na(pval_type)) {
    return("=")
  }
  pt <- tolower(trimws(as.character(pval_type)))
  if (pt == "") return("=")

  # Inspect symbolic operators first so strings like "ge (>=)", "ge (>)",
  # "le (<=)", '"<"', and '"="' map unambiguously before checking letter codes.
  if (grepl(">=", pt, fixed = TRUE)) return(">=")
  if (grepl("<=", pt, fixed = TRUE)) return("<=")
  if (grepl(">", pt, fixed = TRUE)) return(">")
  if (grepl("<", pt, fixed = TRUE)) return("<")

  # Fallback to letter codes when no symbolic operator is present
  if (grepl("\\bge\\b", pt)) return(">=")
  if (grepl("\\ble\\b", pt)) return("<=")
  if (grepl("\\bg\\b", pt)) return(">")
  if (grepl("\\bl\\b", pt)) return("<")
  if (grepl("=|\\be\\b", pt)) return("=")

  return("=")
}

# Helper function to determine if a p-value indicates significance (< alpha)
# Returns TRUE (significant), FALSE (not significant), or NA (missing/indeterminate)
is_pval_significant <- function(pval_value, pval_type, alpha = 0.05) {
  if (is.null(pval_value) || length(pval_value) == 0 || is.na(pval_value)) {
    return(NA)
  }
  pval_num <- suppressWarnings(as.numeric(pval_value))
  if (is.na(pval_num) || !is.finite(pval_num)) {
    return(NA)
  }

  op <- parse_pval_operator(pval_type)

  if (op == "<") {
    # p < X guarantees p < alpha only when X <= alpha; otherwise indeterminate (e.g., p < 0.10)
    if (pval_num <= alpha) return(TRUE)
    return(NA)
  }
  if (op == "<=") {
    # p <= 0.05 is treated as significant (standard NHST reporting convention where authors
    # report "p <= .05" for significant results), whereas exact "p = 0.05" below is treated
    # as not significant (strict p < 0.05, matching FReD::assess_replication_outcome).
    # Bounds above alpha (e.g. p <= 0.72) are indeterminate.
    if (pval_num <= alpha) return(TRUE)
    return(NA)
  }
  if (op %in% c(">", ">=")) {
    # p > X or p >= X guarantees non-significance only when X >= alpha; otherwise indeterminate (e.g., p > 0.01)
    if (pval_num >= alpha) return(FALSE)
    return(NA)
  }

  # Exact equality (p = X)
  return(pval_num < alpha)
}

# Resolve significance from reported p-value, falling back to ES-derived p-value when missing/indeterminate
resolve_significance <- function(pval_value, pval_type, computed_p, alpha = 0.05) {
  sig <- is_pval_significant(pval_value, pval_type, alpha = alpha)
  if (!is.na(sig)) return(sig)

  if (!is.null(computed_p) && length(computed_p) > 0 && !is.na(computed_p)) {
    p_num <- suppressWarnings(as.numeric(computed_p))
    if (!is.na(p_num) && is.finite(p_num)) {
      return(p_num < alpha)
    }
  }
  return(NA)
}

# Compute significance_r outcome using reported p-values with fallback to computed p-values
compute_significance_outcome <- function(row) {
  sig_o <- resolve_significance(row$pval_value_o, row$pval_type_o, row$p_value_o)

  # Original not significant: classify immediately even if replication p-value is missing
  # (matches FReD::assess_replication_outcome)
  if (isFALSE(sig_o)) {
    return(list(
      outcome = "OS not significant",
      outcome_detailed = "OS not significant",
      outcome_report = "OS not significant"
    ))
  }

  sig_r <- resolve_significance(row$pval_value_r, row$pval_type_r, row$p_value_r)

  if (is.na(sig_o) || is.na(sig_r)) {
    return(list(
      outcome = "not calculable",
      outcome_detailed = "not calculable",
      outcome_report = "Not calculable"
    ))
  }

  # Original significant, replication not significant
  if (!sig_r) {
    return(list(
      outcome = "failure",
      outcome_detailed = "failure",
      outcome_report = "Failure"
    ))
  }

  # Both significant - check for reversal if direction is assessable
  es_o <- suppressWarnings(as.numeric(row$es_o))
  es_r <- suppressWarnings(as.numeric(row$es_r))
  direction_assessable <- isTRUE(is_direction_assessable(row$es_type_o, row$es_type_r, es_o, es_r))

  if (direction_assessable) {
    # Check if signs differ (reversal)
    if (sign(es_o) != sign(es_r) && es_o != 0 && es_r != 0) {
      return(list(
        outcome = "failure",
        outcome_detailed = "failure (reversal)",
        outcome_report = "Failure (reversal)"
      ))
    }
  }

  # Both significant and same direction (or direction not assessable)
  return(list(
    outcome = "success",
    outcome_detailed = "success",
    outcome_report = "Success"
  ))
}

# Select and rename columns for the static app
# Note: FReD uses ref_o, doi_o, n_o etc. for original columns
studies <- df %>%
  mutate(
    id = row_number(),
    # Keep original year if available, extract from reference if not
    orig_year_calc = if_else(
      is.na(orig_year),
      as.numeric(stringr::str_extract(ref_o, "\\b(19|20)\\d{2}\\b")),
      as.numeric(orig_year)
    ),
    # Preserve journal from FReD (populated from journal_o); only fall back to regex if missing
    orig_journal_calc = if_else(
      !is.na(orig_journal) & trimws(as.character(orig_journal)) != "",
      gsub("&amp;", "&", trimws(as.character(orig_journal)), fixed = TRUE),
      stringr::str_extract(ref_o, "(?<=\\. )[^.]+(?=,? \\d{4})")
    ),
    pval_value_o_num = suppressWarnings(as.numeric(pval_value_o)),
    pval_value_r_num = suppressWarnings(as.numeric(pval_value_r)),
    # Determine if direction is assessable for this entry
    direction_assessable = is_direction_assessable(es_type_o, es_type_r, es_o, es_r)
  ) %>%
  transmute(
    id,
    description,
    ref_o,
    ref_r,
    doi_o,
    doi_r,
    url_r,
    study_o,
    study_r,
    es_o = es_o,
    es_r = es_r,
    es_type_o,
    n_o,
    n_r,
    ci_lower_o = ci.lower_o,
    ci_upper_o = ci.upper_o,
    ci_lower_r = ci.lower_r,
    ci_upper_r = ci.upper_r,
    p_o = p_value_o,
    p_r = p_value_r,
    pval_value_o = pval_value_o_num,
    pval_type_o,
    pval_value_r = pval_value_r_num,
    pval_type_r,
    power_r,
    source = NA_character_,  # No dedicated source project field in current data
    orig_year = orig_year_calc,
    orig_journal = orig_journal_calc,
    discipline,
    validated = !is.na(contributors),  # Validated if has contributors
    tags,
    contributors,
    result,
    result2,
    claim_text_o,
    direction_assessable
  )

# Compute significance_r outcomes using raw p-values
cat("Computing significance_r outcomes using raw p-values...\n")
significance_outcomes <- vector("list", nrow(df))
for (i in seq_len(nrow(df))) {
  significance_outcomes[[i]] <- compute_significance_outcome(df[i, ])
}

# Add outcomes to each study
for (i in seq_len(nrow(studies))) {
  # Start with pre-computed outcomes
  study_outcomes <- outcomes_list[[i]]
  # Override significance_r with raw p-value based calculation
  study_outcomes[["significance_r"]] <- significance_outcomes[[i]]
  studies$outcomes[i] <- list(study_outcomes)
  studies$reported_success[i] <- df$reported_success[i]  # Use actual reported_success field (0 NAs)
}

# Get unique sources
sources <- c("All studies", sort(unique(df$source[!is.na(df$source)])))

# Build success criteria metadata
success_criteria_meta <- list(
  significance_r = list(
    label = "Significance of Replication",
    shortLabel = "Significance (Rep)",
    hasOSNotSignificant = TRUE,
    note = "Replication success was assessed based on the statistical significance of the replication effect (using reported p-values, falling back to effect-size-derived p-values when unavailable or indeterminate) and whether its direction is consistent with the original effect. Replications that were significant and in the same direction as the original were considered as successes, while replications that were not significant or in the opposite direction were considered as failures.",
    hasDynamicReversalNote = TRUE
  ),
  significance_agg = list(
    label = "Aggregated Significance",
    shortLabel = "Aggregated Sig",
    hasOSNotSignificant = FALSE,
    note = "Replication success was assessed based on the aggregation of effect sizes from the original and replication studies using a meta-analytic approach. Replications where the combined effect was significantly different from zero were considered as successes, while those where the combined effect was not significant were considered as failures."
  ),
  consistency_ci = list(
    label = "Consistency with CI",
    shortLabel = "Consistency (CI)",
    hasOSNotSignificant = FALSE,
    note = "Replication success was assessed based on whether the original effect size fell within the confidence interval of the replication effect size. Replications where the original effect size was within the confidence interval were considered as successes, while those where it was outside were considered as failures."
  ),
  consistency_pi = list(
    label = "Consistency with PI",
    shortLabel = "Consistency (PI)",
    hasOSNotSignificant = FALSE,
    note = "Replication success was assessed based on whether the replication effect size fell within the prediction interval derived from the original study and replication sample size. Replications within the prediction interval were considered as successes, while those outside the prediction interval were considered as failures."
  ),
  homogeneity = list(
    label = "Homogeneity",
    shortLabel = "Homogeneity",
    hasOSNotSignificant = FALSE,
    note = "Replication success was assessed based on the homogeneity of the effects from the original and replication studies using a heterogeneity test (Q-test). Replications where the effects were homogeneous were considered as successes, while those that showed heterogeneity were considered as failures."
  ),
  homogeneity_significance = list(
    label = "Homogeneity & Significance",
    shortLabel = "Homog. & Sig",
    hasOSNotSignificant = TRUE,
    note = "Replication success was assessed based on the combination of homogeneity and the significance of the effect sizes. Replications where the effects were homogeneous and jointly significantly different from zero were considered as successes, while those that were either not homogeneous or not significantly different from zero were considered as failures."
  ),
  small_telescopes = list(
    label = "Small Telescopes",
    shortLabel = "Small Telescopes",
    hasOSNotSignificant = FALSE,
    note = "Replication success was assessed based on whether the replication effect size was larger than the effect size that would have given the original study a power of 33%. Replications that met this criterion were considered as successes, while those that did not were considered as failures."
  ),
  reported_success = list(
    label = "Reported Success",
    shortLabel = "Reported",
    hasOSNotSignificant = FALSE,
    note = "Replication success was assessed based on how the replication authors described their results, as coded in the FReD database. Where this coding is missing, the calculated outcome stored in the database is used instead."
  )
)

# Outcome colors
outcome_colors <- list(
  success = "#8FBC8F",
  Success = "#8FBC8F",
  failure = "#FF7F7F",
  Failure = "#FF7F7F",
  `failure (reversal)` = "darkred",
  `Failure (reversal)` = "darkred",
  `OS not significant` = "#535353",
  `Not calculable` = "#C8C8C8",
  `not calculable` = "#C8C8C8",
  `success (homogeneous and jointly significantly above 0)` = "#8FBC8F",
  `failure (not homogeneous but jointly significantly above 0)` = "#efa986",
  `failure (not homogeneous and not significant)` = "darkred",
  `failure (homogeneous but not significant)` = "#FF7F7F"
)

# Build final output
output <- list(
  metadata = list(
    generated = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
    version = packageVersion("FReD") %>% as.character(),
    studyCount = nrow(studies),
    sourceCount = length(sources) - 1  # Exclude "All studies"
  ),
  studies = studies,
  sources = I(sources),
  successCriteria = success_criteria_meta,
  outcomeColors = outcome_colors
)

# Write JSON
output_file <- file.path(OUTPUT_DIR, "explorer-data.json")
cat("Writing JSON to:", output_file, "\n")

# Convert to JSON with proper formatting (I(6) = 6 significant digits so small p-values retain precision)
json_output <- toJSON(
  output,
  auto_unbox = TRUE,
  na = "null",
  null = "null",
  pretty = FALSE,  # Compact for smaller file size
  digits = I(6)
)

writeLines(json_output, output_file)

# Report file size
file_size <- file.info(output_file)$size
cat("Output file size:", format(file_size, big.mark = ","), "bytes\n")
cat("Done!\n")
