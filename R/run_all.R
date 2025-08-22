# run_everything.R — run all R files and auto-call likely entry functions

# --- repo root (works when run via: Rscript run_everything.R)
args_all  <- commandArgs(trailingOnly = FALSE)
file_arg  <- grep("^--file=", args_all, value = TRUE)
repo_root <- if (length(file_arg) == 1) dirname(normalizePath(sub("^--file=", "", file_arg))) else getwd()
setwd(repo_root)
message("Working directory: ", getwd())

# Options
SEED <- suppressWarnings(as.integer(Sys.getenv("SEED", "1234"))); if (!is.na(SEED)) set.seed(SEED)
STOP_ON_ERROR <- tolower(Sys.getenv("STOP_ON_ERROR", "true")) %in% c("1","true","yes")

# Collect all .R files (repo-wide), excluding this runner
all_r <- sort(list.files(repo_root, pattern = "\\.[Rr]$", recursive = TRUE, full.names = TRUE))
this_file <- if (length(file_arg) == 1) normalizePath(sub("^--file=", "", file_arg)) else ""
all_r <- all_r[all_r != this_file]

message("Scripts to source (", length(all_r), "):")
for (f in all_r) message("  - ", f)

# Helper: safely source into global env and capture newly-defined functions
new_fns_from_source <- function(path) {
  before <- ls(.GlobalEnv, all.names = TRUE)
  sys.source(path, envir = .GlobalEnv, keep.source = TRUE)
  after  <- ls(.GlobalEnv, all.names = TRUE)
  new_syms <- setdiff(after, before)
  new_syms[sapply(new_syms, function(x) exists(x, envir=.GlobalEnv) && is.function(get(x, envir=.GlobalEnv)))]
}

# Helper: find @entry tags in file (lines like: # @entry my_function)
entry_tags_in_file <- function(path) {
  txt <- tryCatch(readLines(path, warn = FALSE), error = function(e) character(0))
  tags <- sub("^#\\s*@entry\\s+([A-Za-z0-9_.]+).*", "\\1", grep("^#\\s*@entry\\s+\\w", txt, value = TRUE))
  unique(tags)
}

# We’ll remember candidates per file
candidates <- list()
errors <- list()

for (f in all_r) {
  message("\n>>> Sourcing: ", f)
  file_entries <- character(0)
  new_fns <- character(0)
  ok <- tryCatch({
    file_entries <<- entry_tags_in_file(f)
    new_fns      <<- new_fns_from_source(f)
    TRUE
  }, error = function(e) {
    msg <- paste0("Error sourcing ", f, ": ", e$message)
    message("❗ ", msg)
    errors[[length(errors)+1]] <<- msg
    FALSE
  })
  if (!ok && STOP_ON_ERROR) break
  
  # Record candidates:
  # 1) any @entry tags
  # 2) any zero-arg functions with names like run_*/simulate_*/make_*/plot_*
  zero_arg <- function(fn) {
    fobj <- get(fn, envir=.GlobalEnv)
    length(formals(fobj)) == 0
  }
  pattern_fns <- new_fns[grepl("^(run_|simulate_|make_|plot_)", new_fns, ignore.case = TRUE)]
  pattern_fns <- pattern_fns[sapply(pattern_fns, zero_arg)]
  cands <- unique(c(file_entries, pattern_fns))
  if (length(cands)) {
    message("  ↳ Entry candidates: ", paste(cands, collapse = ", "))
    candidates[[f]] <- cands
  } else {
    message("  ↳ No entry candidates (file defines helpers only or requires args).")
  }
}

# Execute discovered entry functions (dedup, keep stable order)
to_run <- unique(unlist(candidates, use.names = FALSE))
if (length(to_run) == 0) {
  message("\n⚠️  No entry functions discovered.")
  message("Tip: add a comment like `# @entry my_function` above the function you want to run,")
  message("or ensure your entry functions have zero arguments and names starting with run_/simulate_/make_/plot_.")
} else {
  message("\nWill run ", length(to_run), " entry function(s): ", paste(to_run, collapse = ", "))
  for (fn in to_run) {
    message("→ Calling: ", fn, "()")
    ok <- tryCatch({
      do.call(get(fn, envir=.GlobalEnv), list())
      TRUE
    }, error = function(e) {
      msg <- paste0("Error in ", fn, "(): ", e$message)
      message("❗ ", msg)
      errors[[length(errors)+1]] <<- msg
      FALSE
    })
    if (!ok && STOP_ON_ERROR) break
  }
}

if (length(errors)) {
  message("\nCompleted with ", length(errors), " error(s).")
  for (e in errors) message(" - ", e)
  quit(status = 1)
} else {
  message("\nAll scripts sourced and entry functions executed.")
}
