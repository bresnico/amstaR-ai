# amstaR-ai

library(httr2)
library(jsonlite)
library(future)
library(future.apply)

# Configuration
ANTHROPIC_KEY <- Sys.getenv("ANTHROPIC_API_KEY")
OPENAI_KEY <- Sys.getenv("OPENAI_API_KEY")
PDF_DIR <- "data/articles"
SAVE_DIR <- "results"
LOG_FILE <- paste0("dual_judge_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
CHECKPOINT_FILE <- file.path(SAVE_DIR, "checkpoint.rds")

# Logging function
log_msg <- function(level = "INFO", ...) {
  msg <- paste(..., collapse = " ")
  timestamp <- format(Sys.time(), "%H:%M:%S")
  
  # Level symbols
  symbols <- list(
    "INFO" = "ℹ️",
    "SUCCESS" = "✅",
    "WARNING" = "⚠️",
    "ERROR" = "❌",
    "PROGRESS" = "🔄",
    "UPLOAD" = "📤",
    "EVAL" = "🧠",
    "SAVE" = "💾"
  )
  
  symbol <- symbols[[level]] %||% "•"
  log_line <- paste0("[", timestamp, "] ", symbol, " ", msg)
  
  # Console colors (if supported)
  if (level == "ERROR") {
    cat("\033[31m", msg, "\033[0m\n", sep = "")  # Red
  } else if (level == "SUCCESS") {
    cat("\033[32m", msg, "\033[0m\n", sep = "")  # Green
  } else if (level == "WARNING") {
    cat("\033[33m", msg, "\033[0m\n", sep = "")  # Yellow
  } else {
    cat(msg, "\n")
  }
  
  cat(log_line, "\n", file = LOG_FILE, append = TRUE)
}

# Function to shorten filenames for display
shorten_filename <- function(filename) {
  name <- tools::file_path_sans_ext(filename)
  if (nchar(name) > 25) {
    paste0(substr(name, 1, 22), "...")
  } else {
    name
  }
}

if (ANTHROPIC_KEY == "" || OPENAI_KEY == "") {
  stop("Missing API keys. Set ANTHROPIC_API_KEY and OPENAI_API_KEY environment variables")
}

# Create results directory
if (!dir.exists(SAVE_DIR)) dir.create(SAVE_DIR, recursive = TRUE)

if (Sys.getenv("TESTING_MODE") != "true") {
  plan(multisession, workers = 2)
}

# Enhanced AMSTAR2 prompt (in English)
get_amstar2_prompt <- function(article_id) {
  paste0("You are an expert in research methodology specializing in systematic review assessment using AMSTAR2 criteria.

Evaluate the systematic review provided according to the 16 AMSTAR2 criteria. For each item, assign a score (Yes/Partial Yes/No/N/A) and provide a CONCISE justification (maximum 20 words).

AMSTAR2 CRITERIA TO EVALUATE:

CRITICAL DOMAINS (major impact on validity):
- Item 2: Protocol registered before commencement (PROSPERO, etc.)
- Item 4: Comprehensive literature search strategy (≥2 databases, appropriate terms)
- Item 7: List of excluded studies with justifications provided
- Item 9: Satisfactory technique for assessing risk of bias in individual studies
- Item 11: Appropriate methods for statistical combination of results (if meta-analysis performed)
- Item 13: Risk of bias in individual studies considered when interpreting/discussing results
- Item 15: Investigation of publication bias (small study bias) and discussion of likely impact

NON-CRITICAL DOMAINS:
- Item 1: Research questions and inclusion criteria include components of PICO
- Item 3: Selection of study designs for inclusion explained
- Item 5: Study selection performed in duplicate
- Item 6: Data extraction performed in duplicate
- Item 8: Included studies described in adequate detail
- Item 10: Sources of funding for studies included in review reported
- Item 12: Potential impact of risk of bias in individual studies on results assessed
- Item 14: Satisfactory explanation for and discussion of heterogeneity observed
- Item 16: Potential sources of conflict of interest reported

OVERALL CONFIDENCE RATING RULES:
- High: No or one non-critical weakness
- Moderate: More than one non-critical weakness, but no critical weaknesses  
- Low: One critical weakness with or without non-critical weaknesses
- Critically low: More than one critical weakness with or without non-critical weaknesses

*Multiple non-critical weaknesses may diminish confidence and warrant moving from moderate to low confidence.

Respond ONLY with the following JSON (use the ARTICLE_ID provided above):
{
  \"article_id\": \"", article_id, "\",
  \"amstar2_evaluation\": {
    \"item_1_pico_components\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_2_protocol_registration\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_3_study_design_explanation\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_4_comprehensive_search\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_5_duplicate_selection\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_6_duplicate_extraction\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_7_excluded_studies_list\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_8_study_characteristics\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_9_risk_of_bias_assessment\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_10_funding_sources\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_11_meta_analysis_methods\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_12_risk_of_bias_impact\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_13_risk_of_bias_discussion\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_14_heterogeneity_discussion\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_15_publication_bias\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"},
    \"item_16_conflicts_of_interest\": {\"score\": \"Yes|Partial Yes|No|N/A\", \"justification\": \"brief justification\"}
  },
  \"critical_weaknesses\": [\"Item 2\", \"Item 4\"],
  \"overall_confidence\": \"High|Moderate|Low|Critically low\",
  \"recommendation\": \"Include|Exclude\"
}")
}

# ==================== CHECKPOINT SYSTEM ====================

# Load existing checkpoint
load_checkpoint <- function() {
  if (file.exists(CHECKPOINT_FILE)) {
    log_msg("Loading existing checkpoint...")
    readRDS(CHECKPOINT_FILE)
  } else {
    list(completed = character(0), results = list(), failed = character(0))
  }
}

# Save checkpoint
save_checkpoint <- function(checkpoint) {
  saveRDS(checkpoint, CHECKPOINT_FILE)
  completed_count <- length(checkpoint$completed)
  failed_count <- length(checkpoint$failed)
  
  log_msg("SAVE", sprintf("Checkpoint: %d completed, %d failed", 
                          completed_count, failed_count))
}

# Save individual result
save_individual_result <- function(article_id, result) {
  result_file <- file.path(SAVE_DIR, paste0(article_id, "_result.rds"))
  saveRDS(result, result_file)
  log_msg("Result saved:", article_id)
}

# Load individual result
load_individual_result <- function(article_id) {
  result_file <- file.path(SAVE_DIR, paste0(article_id, "_result.rds"))
  if (file.exists(result_file)) {
    readRDS(result_file)
  } else {
    NULL
  }
}

# ==================== API FUNCTIONS ====================

# Generic API call function with automatic retries
api_call <- function(url, headers, method = "POST", body = NULL, timeout = 120) {
  req <- request(url) |>
    req_headers(!!!headers) |>
    req_timeout(timeout) |>
    req_retry(max_tries = 5)
  
  if (!is.null(body)) {
    if (method == "POST") req <- req |> req_body_json(body)
  }
  
  tryCatch({
    resp <- req |> req_method(method) |> req_perform()
    resp_body_json(resp)
  }, error = function(e) {
    log_msg("ERROR", "Final API error after retries:", e$message)
    NULL
  })
}

# Upload file to Anthropic with duplicate checking
upload_anthropic <- function(file_path) {
  filename <- basename(file_path)
  short_name <- shorten_filename(filename)
  
  # Check for existing files
  files <- api_call(
    "https://api.anthropic.com/v1/files",
    headers = list(
      "x-api-key" = ANTHROPIC_KEY,
      "anthropic-version" = "2023-06-01",
      "anthropic-beta" = "files-api-2025-04-14"
    ),
    method = "GET"
  )
  
  if (!is.null(files$data)) {
    existing <- Filter(function(f) !is.null(f$filename) && f$filename == filename, files$data)
    if (length(existing) > 0) {
      log_msg("UPLOAD", sprintf("Anthropic: %s (reused)", short_name))
      return(existing[[1]]$id)
    }
  }
  
  # Upload new file using simplified httr2 pattern
  req <- request("https://api.anthropic.com/v1/files") |>
    req_method("POST") |>
    req_headers(
      "x-api-key" = ANTHROPIC_KEY,
      "anthropic-version" = "2023-06-01",
      "anthropic-beta" = "files-api-2025-04-14"
    ) |>
    req_body_multipart(file = curl::form_file(file_path)) |>
    req_timeout(120) |>
    req_retry(max_tries = 3, backoff = ~ 2^.x)
  
  tryCatch({
    resp <- req_perform(req)
    result <- resp_body_json(resp)
    log_msg("UPLOAD", sprintf("Anthropic: %s ✓", short_name))
    result$id
  }, error = function(e) {
    log_msg("ERROR", sprintf("Anthropic upload failed (%s): %s", short_name, e$message))
    NULL
  })
}

# Upload file to OpenAI with duplicate checking
upload_openai <- function(file_path) {
  filename <- basename(file_path)
  short_name <- shorten_filename(filename)
  
  # Check for existing files
  files <- api_call(
    "https://api.openai.com/v1/files",
    headers = list("Authorization" = paste("Bearer", OPENAI_KEY)),
    method = "GET"
  )
  
  if (!is.null(files$data)) {
    existing <- Filter(function(f) !is.null(f$filename) && f$filename == filename && f$purpose == "user_data", files$data)
    if (length(existing) > 0) {
      log_msg("UPLOAD", sprintf("OpenAI: %s (reused)", short_name))
      return(existing[[1]]$id)
    }
  }
  
  # Upload new file using simplified httr2 pattern
  req <- request("https://api.openai.com/v1/files") |>
    req_method("POST") |>
    req_headers("Authorization" = paste("Bearer", OPENAI_KEY)) |>
    req_body_multipart(
      file = curl::form_file(file_path),
      purpose = "user_data"
    ) |>
    req_timeout(120) |>
    req_retry(max_tries = 3, backoff = ~ 2^.x)
  
  tryCatch({
    resp <- req_perform(req)
    result <- resp_body_json(resp)
    log_msg("UPLOAD", sprintf("OpenAI: %s ✓", short_name))
    result$id
  }, error = function(e) {
    log_msg("ERROR", sprintf("OpenAI upload failed (%s): %s", short_name, e$message))
    NULL
  })
}

# Evaluate document using Anthropic Claude
evaluate_anthropic <- function(file_id, filename) {
  article_id <- tools::file_path_sans_ext(filename)
  short_name <- shorten_filename(filename)
  
  log_msg("EVAL", sprintf("Anthropic: %s", short_name))
  
  response <- api_call(
    "https://api.anthropic.com/v1/messages",
    headers = list(
      "x-api-key" = ANTHROPIC_KEY,
      "anthropic-version" = "2023-06-01",
      "anthropic-beta" = "files-api-2025-04-14",
      "Content-Type" = "application/json"
    ),
    body = list(
      model = "claude-sonnet-4-20250514",
      max_tokens = 4000,
      temperature = 0.1,
      messages = list(list(
        role = "user",
        content = list(
          list(type = "document", source = list(type = "file", file_id = file_id)),
          list(type = "text", text = get_amstar2_prompt(article_id))
        )
      ))
    )
  )
  
  if (is.null(response) || is.null(response$content)) {
    log_msg("ERROR", sprintf("Anthropic: %s - No response", short_name))
    return(NULL)
  }
  
  # Clean JSON response
  content <- response$content[[1]]$text
  content <- gsub("```json\\s*|\\s*```", "", content)
  content <- gsub("^[^{]*|[^}]*$", "", content)
  
  tryCatch({
    result <- fromJSON(content, simplifyVector = FALSE)
    confidence <- result$overall_confidence %||% "Unknown"
    log_msg("SUCCESS", sprintf("Anthropic: %s → %s", short_name, confidence))
    result
  }, error = function(e) {
    log_msg("ERROR", sprintf("Invalid Anthropic JSON (%s): %s", short_name, e$message))
    list(error = e$message, raw_content = content)
  })
}

# Evaluate document using OpenAI GPT
evaluate_openai <- function(file_id, filename) {
  article_id <- tools::file_path_sans_ext(filename)
  short_name <- shorten_filename(filename)
  
  log_msg("EVAL", sprintf("OpenAI: %s", short_name))
  
  tryCatch({
    response <- api_call(
      "https://api.openai.com/v1/chat/completions",
      headers = list(
        "Authorization" = paste("Bearer", OPENAI_KEY),
        "Content-Type" = "application/json"
      ),
      body = list(
        model = "gpt-4o-mini",
        messages = list(list(
          role = "user",
          content = list(
            list(
              type = "file",
              file = list(file_id = file_id)
            ),
            list(
              type = "text", 
              text = get_amstar2_prompt(article_id)
            )
          )
        )),
        max_tokens = 4000,
        temperature = 0.1,
        response_format = list(type = "json_object")
      )
    )
    
    if (is.null(response) || is.null(response$choices)) {
      log_msg("ERROR", sprintf("OpenAI: %s - No response", short_name))
      return(NULL)
    }
    
    content <- response$choices[[1]]$message$content
    result <- fromJSON(content, simplifyVector = FALSE)
    confidence <- result$overall_confidence %||% "Unknown"
    log_msg("SUCCESS", sprintf("OpenAI: %s → %s", short_name, confidence))
    result
    
  }, error = function(e) {
    log_msg("ERROR", sprintf("OpenAI failed (%s): %s", short_name, e$message))
    list(error = e$message)
  })
}

# ==================== RESILIENT PROCESSING ====================

# Process single file with checkpointing
process_single_file <- function(pdf_path, checkpoint, current_index, total_files) {
  filename <- basename(pdf_path)
  article_id <- tools::file_path_sans_ext(filename)
  short_name <- shorten_filename(filename)
  
  # Check if already processed
  if (article_id %in% checkpoint$completed) {
    log_msg("INFO", sprintf("[%d/%d] %s - Already processed", current_index, total_files, short_name))
    return(load_individual_result(article_id))
  }
  
  log_msg("PROGRESS", sprintf("\n[%d/%d] Processing: %s", current_index, total_files, short_name))
  
  tryCatch({
    # Parallel upload to both APIs
    upload_futures <- list(
      anthropic = future(upload_anthropic(pdf_path)),
      openai = future(upload_openai(pdf_path))
    )
    
    upload_ids <- list(
      anthropic = value(upload_futures$anthropic),
      openai = value(upload_futures$openai)
    )
    
    # Granular error handling
    if (is.null(upload_ids$anthropic) && is.null(upload_ids$openai)) {
      stop("Complete upload failure for ", short_name)
    } else if (is.null(upload_ids$anthropic)) {
      log_msg("WARNING", sprintf("Anthropic upload failed for %s, OpenAI only", short_name))
    } else if (is.null(upload_ids$openai)) {
      log_msg("WARNING", sprintf("OpenAI upload failed for %s, Anthropic only", short_name))
    }
    
    # Conditional evaluations
    result <- list()
    
    if (!is.null(upload_ids$anthropic)) {
      result$anthropic <- evaluate_anthropic(upload_ids$anthropic, filename)
    }
    
    if (!is.null(upload_ids$openai)) {
      result$openai <- evaluate_openai(upload_ids$openai, filename)
    }
    
    # Results summary
    anthropic_status <- if(!is.null(result$anthropic) && is.null(result$anthropic$error)) "✓" else "✗"
    openai_status <- if(!is.null(result$openai) && is.null(result$openai$error)) "✓" else "✗"
    
    # Save result immediately
    save_individual_result(article_id, result)
    
    # Update checkpoint
    checkpoint$completed <- c(checkpoint$completed, article_id)
    checkpoint$results[[article_id]] <- result
    save_checkpoint(checkpoint)
    
    log_msg("SUCCESS", sprintf("Completed: %s [Anthropic:%s OpenAI:%s]", 
                               short_name, anthropic_status, openai_status))
    return(result)
    
  }, error = function(e) {
    log_msg("ERROR", sprintf("Complete failure on %s: %s", short_name, e$message))
    
    # Add to failures
    checkpoint$failed <- c(checkpoint$failed, article_id)
    save_checkpoint(checkpoint)
    
    # Return error but continue
    return(list(error = e$message, file = filename))
  })
}

# Export results to CSV files
export_results <- function(results) {
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # Filter out errors
  valid_results <- Filter(function(r) is.null(r$error), results)
  
  if (length(valid_results) == 0) {
    log_msg("No valid results to export")
    return()
  }
  
  # Export 1: Global summary
  summary_rows <- lapply(names(valid_results), function(article) {
    data.frame(
      article_id = article,
      anthropic_evaluation = valid_results[[article]]$anthropic$overall_confidence %||% "Error",
      anthropic_recommendation = valid_results[[article]]$anthropic$recommendation %||% "Error",
      openai_evaluation = valid_results[[article]]$openai$overall_confidence %||% "Error", 
      openai_recommendation = valid_results[[article]]$openai$recommendation %||% "Error",
      stringsAsFactors = FALSE
    )
  })
  summary_df <- do.call(rbind, summary_rows)
  
  summary_file <- paste0("amstar2_summary_", timestamp, ".csv")
  write.csv(summary_df, summary_file, row.names = FALSE)
  log_msg("Summary exported:", summary_file)
  
  # Export 2 & 3: Detailed results
  export_details <- function(judge_name, file_suffix) {
    detail_rows <- lapply(names(valid_results), function(article) {
      eval_data <- valid_results[[article]][[tolower(judge_name)]]
      
      if (is.null(eval_data) || is.null(eval_data$amstar2_evaluation)) {
        return(NULL)
      }
      
      lapply(names(eval_data$amstar2_evaluation), function(item_name) {
        data.frame(
          article_id = article,
          judge = judge_name,
          item = item_name,
          score = eval_data$amstar2_evaluation[[item_name]]$score %||% "N/A",
          justification = eval_data$amstar2_evaluation[[item_name]]$justification %||% "N/A",
          stringsAsFactors = FALSE
        )
      })
    })
    
    detail_rows <- Filter(Negate(is.null), detail_rows)
    
    if (length(detail_rows) > 0) {
      detail_df <- do.call(rbind, unlist(detail_rows, recursive = FALSE))
      if (nrow(detail_df) > 0) {
        detail_file <- paste0("amstar2_", file_suffix, "_", timestamp, ".csv")
        write.csv(detail_df, detail_file, row.names = FALSE)
        log_msg("Details", judge_name, "exported:", detail_file)
      }
    } else {
      log_msg("No", judge_name, "data to export")
    }
  }
  
  export_details("Anthropic", "anthropic")
  export_details("OpenAI", "openai")
}

# MAIN RESILIENT SCRIPT
main <- function() {
  log_msg("INFO", "=== AMSTAR2 DUAL JUDGE V3 - OPTIMIZED PRODUCTION VERSION ===")
  log_msg("INFO", sprintf("Log: %s", LOG_FILE))
  
  if (!dir.exists(PDF_DIR)) {
    stop("Directory not found: ", PDF_DIR)
  }
  
  pdf_files <- list.files(PDF_DIR, pattern = "\\.pdf$", full.names = TRUE)
  if (length(pdf_files) == 0) {
    stop("No PDF files found in: ", PDF_DIR)
  }
  
  total_files <- length(pdf_files)
  log_msg("INFO", sprintf("PDFs detected: %d files", total_files))
  
  # Load existing checkpoint
  checkpoint <- load_checkpoint()
  completed_count <- length(checkpoint$completed)
  failed_count <- length(checkpoint$failed)
  remaining_count <- total_files - completed_count
  
  if (completed_count > 0) {
    log_msg("INFO", sprintf("Resume: %d completed, %d failed, %d remaining", 
                            completed_count, failed_count, remaining_count))
  }
  
  # Sequential processing with progress indicator
  for (i in seq_along(pdf_files)) {
    pdf_path <- pdf_files[i]
    filename <- basename(pdf_path)
    article_id <- tools::file_path_sans_ext(filename)
    
    result <- process_single_file(pdf_path, checkpoint, i, total_files)
    
    # Update global results
    if (!is.null(result)) {
      checkpoint$results[[article_id]] <- result
    }
    
    # Show periodic progress
    if (i %% 5 == 0 || i == total_files) {
      progress_pct <- round(i / total_files * 100, 1)
      log_msg("PROGRESS", sprintf("Progress: %d/%d (%s%%)", i, total_files, progress_pct))
    }
  }
  
  # Final export
  log_msg("INFO", "\n=== FINAL EXPORT ===")
  export_results(checkpoint$results)
  
  # Enhanced final statistics
  final_completed <- length(checkpoint$completed)
  final_failed <- length(checkpoint$failed)
  success_rate <- round(final_completed / total_files * 100, 1)
  
  log_msg("INFO", "\n=== FINAL REPORT ===")
  log_msg("SUCCESS", sprintf("Files processed: %d/%d (%s%%)", final_completed, total_files, success_rate))
  
  if (final_failed > 0) {
    log_msg("WARNING", sprintf("Failures: %d files", final_failed))
    failed_files <- checkpoint$failed
    for (f in failed_files) {
      log_msg("WARNING", sprintf("  • %s", f))
    }
    log_msg("INFO", "💡 Re-run script to retry failures")
  } else {
    log_msg("SUCCESS", "🎉 All files processed successfully!")
  }
  
  return(checkpoint$results)
}

# Utility function
`%||%` <- function(a, b) if (is.null(a)) b else a

# Execute if script called directly AND not in test mode
if (!interactive() && Sys.getenv("TESTING_MODE") != "true") {
  main()
}