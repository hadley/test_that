#' Generate default testing environment.
#'
#' We use a new environment which inherits from \code{\link{globalenv}}.
#' In an ideal world, we'd avoid putting the global environment on the
#' search path for tests, but it's not currently possible without losing
#' the ability to load packages in tests.
#'
#' @keywords internal
#' @export
test_env <- function() {
  new.env(parent = globalenv())
}

#' Run all of the tests in a directory.
#'
#' Test files start with \code{test} and are executed in alphabetical order
#' (but they shouldn't have dependencies). Helper files start with
#' \code{helper} and loaded before any tests are run.
#'
#' @param path path to tests
#' @param reporter reporter to use
#' @param filter If not \code{NULL}, only tests with file names matching this
#'   regular expression will be executed.  Matching will take on the file
#'   name after it has been stripped of \code{"test-"} and \code{".r"}.
#' @param env environment in which to execute test suite.
#' @return the results as a "testthat_results" (list)
#' @export
test_dir <- function(path, filter = NULL, reporter = "summary",
                                          env = test_env()) {
                     
  current_reporter <- find_reporter(reporter)
  source_test_helpers(path, env)
  paths <- find_test_scripts(path, filter)
  if (length(paths) == 0) stop('No matching test file in dir')
  
  current_reporter$start_reporter()
  results <- lapply(paths, .test_file, parent_env = env, 
    reporter = current_reporter, start_end_reporter = FALSE)
  current_reporter$end_reporter()
  
  results <- unlist(results, recursive = FALSE)
  
  invisible(structure(results, class = 'testthat_results'))
}


source_test_helpers <- function(path, env = globalenv()) {
  source_dir(path, "^helper.*\\.[rR]$", env = env)  
}


#' take care or finding the test files and sourcing the helpers
#' @param path path to tests
#' @param filter cf \code{\link{test_dir}}
#' @return the test file paths 
find_test_scripts <- function(path, filter = NULL) {
  files <- dir(path, "^test.*\\.[rR]$")
  if (!is.null(filter)) {
    test_names <- basename(files)
    test_names <- gsub("^test-?", "", test_names)
    test_names <- gsub("\\.[rR]", "", test_names)
    files <- files[grepl(filter, test_names)]
  }
  
  file.path(path, files)  
}


#' take care or finding the test files and sourcing the helpers
#' @inheritParams test_dir
#' @param env environment in which to source the helpers
#' @return the test file paths 
setup_test_dir <- function(path, filter, env) {
  source_dir(path, "^helper.*\\.[rR]$", env = env)
  
  files <- dir(path, "^test.*\\.[rR]$")
  if (!is.null(filter)) {
    test_names <- basename(files)
    test_names <- gsub("^test-?", "", test_names)
    test_names <- gsub("\\.[rR]", "", test_names)
    
    files <- files[grepl(filter, test_names)]
  }
  
  file.path(path, files)
}


#' Load all source files in a directory.
#'
#' The expectation is that the files can be sourced in alphabetical order.
#'
#' @param path path to tests
#' @param pattern regular expression used to filter files
#' @param env environment in which to store results
#' @param chdir change working directory to path?
#' @keywords internal
#' @export
source_dir <- function(path, pattern = "\\.[rR]$", env = test_env(),
                       chdir = TRUE) {
  files <- normalizePath(sort(dir(path, pattern, full.names = TRUE)))
  if (chdir) {
    old <- setwd(path)
    on.exit(setwd(old))
  }

  lapply(files, sys.source2, envir = env)
}

#' Run all tests in specified file.
#'
#' @param path path to file
#' @param reporter reporter to use
#' @param env environment in which to execute the tests
#' @return the results as a "testthat_results" (list)
#' @export
test_file <- function(path, reporter = "summary", env = test_env()) {
  reporter <- if (is.null(reporter)) NULL else find_reporter(reporter)
  invisible(.test_file(path, env, reporter, TRUE))
}

.test_file <- function(path, parent_env, reporter, start_end_reporter) {
  if (is.null(parent_env)) parent_env <- globalenv()
  lister <- ListReporter$new()
  reporter <- if (!is.null(reporter))
    MultiReporter$new(reporters = list(reporter, lister))
  else
    lister
  
  old_reporter <- set_reporter(reporter)
  old_dir <- setwd(dirname(path))
  on.exit({ 
      setwd(old_dir)
      set_reporter(old_reporter) 
    })
  
  if (start_end_reporter) reporter$start_reporter()
  
  fname <- basename(path)
  lister$start_file(fname)
  
  sys.source2(fname, new.env(parent = parent_env))
  end_context()
 
  if (start_end_reporter) reporter$end_reporter()

  invisible(structure(lister$results, class = 'testthat_results'))
}


sys.source2 <- function(file, envir = parent.frame()) {
  stopifnot(file.exists(file))
  stopifnot(is.environment(envir))

  lines <- readLines(file, warn = FALSE)
  srcfile <- srcfilecopy(file, lines, file.info(file)[1, "mtime"],
    isFile = TRUE)
  exprs <- parse(text = lines, n = -1, srcfile = srcfile)

  n <- length(exprs)
  if (n == 0L) return(invisible())


  invisible(eval(exprs, envir))
}

