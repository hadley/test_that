#' Expect that a condition holds.
#'
#' An expectation checks whether a single condition holds true.
#' \pkg{testthat} currently provides the following expectations.  See their
#' documentation for more details
#'
#' \itemize{
#'  \item \code{\link{is_true}}: truth
#'  \item \code{\link{is_false}}: falsehood
#'  \item \code{\link{is_a}}: inheritance
#'  \item \code{\link{equals}}: equality with numerical tolerance
#'  \item \code{\link{is_equivalent_to}}: equality ignoring attributes
#'  \item \code{\link{is_identical_to}}: exact identity
#'  \item \code{\link{matches}}: string matching
#'  \item \code{\link{prints_text}}: output matching
#'  \item \code{\link{throws_error}}: error matching
#'  \item \code{\link{gives_warning}}: warning matching
#'  \item \code{\link{shows_message}}: message matching
#'  \item \code{\link{takes_less_than}}: performance
#' }
#'
#' Expectations are arranged into tests with \code{\link{test_that}} and
#' tests are arranged into contexts with \code{\link{context}}.
#'
#' @param object object to test
#' @param condition, a function that returns whether or not the condition
#'   is met, and if not, an error message to display.
#' @param label object label. When \code{NULL}, computed from deparsed object.
#' @param info extra information to be included in the message (useful when
#'   writing tests in loops).
#' @export
#' @seealso \code{\link{fail}} for an expectation that always fails.
#' @examples
#' expect_that(5 * 2, equals(10))
#' expect_that(sqrt(2) ^ 2, equals(2))
#' \dontrun{
#' expect_that(sqrt(2) ^ 2, is_identical_to(2))
#' }
expect_that <- function(object, condition, info = NULL, label = NULL) {
  if (is.null(label)) {
    label <- find_expr("object")
  }
  results <- condition(object)

  results$failure_msg <- paste0(label, " ", results$failure_msg)
  results$success_msg <- paste0(label, " ", results$success_msg)
  if (!is.null(info)) {
    results$failure_msg <- paste0(results$failure_msg, "\n", info)
    results$success_msg <- paste0(results$success_msg, "\n", info)
  }
  call <- sys.call()
  call$info <- info
  if (!is.null(call$label)) {
      call$label <- label
  }
  results$call <- paste(deparse(call, width.cutoff = 500), collapse = "")
  
  get_reporter()$add_result(results)
  invisible()
}

#' A default expectation that always fails.
#'
#' The fail function forces a test to fail.  This is useful if you want to
#' test a pre-condition '
#'
#' @param message a string to display.
#' @export
#' @examples
#' \dontrun{
#' test_that("this test fails", fail())
#' }
fail <- function(message = "Failure has been forced.") {
  results <- expectation(FALSE, message, "This always succeeds.")
  get_reporter()$add_result(results)
  invisible()
}


#' Negate an expectation
#'
#' This negates an expectation, making it possible to express that you
#' want the opposite of a standard expectation.
#'
#' @param f an existing expectation function
#' @export
#' @examples
#' x <- 1
#' expect_that(x, equals(1))
#' expect_that(x, not(equals(2)))
#' \dontrun{
#' expect_that(x, equals(2))
#' expect_that(x, not(equals(1)))
#' }
not <- function(f) {
  stopifnot(is.function(f))

  function(...) {
    res <- f(...)
    negate(res)
  }
}
