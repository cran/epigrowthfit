##' Enumerators
##'
##' Returns the underlying integer value of an enumerator in the
##' package's \proglang{C++} template.
##'
##' @param enum
##'   a character vector listing names of enumerators of type
##'   \code{type}.
##' @param type
##'   a character string specifying an enumerated type.
##'
##' @details
##' The source file defining \code{egf_enum} is kept synchronized
##' with the package's \proglang{C++} template using the package
##' \file{Makevars}.
##'
##' @return
##' An integer vector.
##'
##' @examples
##' egf_enum("exponential", "curve")
##' egf_enum("pois", "family")
##' egf_enum("norm", "prior")

egf_enum <-
function(enum, type) {
	enum. <- switch(type, .__ARGS__.stop(gettextf("invalid '%s'", "type"), domain = NA))
	match(enum, enum., 0L) - 1L
}
