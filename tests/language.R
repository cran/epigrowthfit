attach(asNamespace("epigrowthfit"))
library(tools)
options(warn = 2L, error = if (interactive()) recover)


## negate ##############################################################

x <- quote(x)
minus.x <- call("-", x)
log.x <- call("log", x)
minus.log.x <- call("-", log.x)

stopifnot(exprs = {
	identical(negate(x), minus.x)
	identical(negate(minus.x), x)

	identical(negate(log.x), minus.log.x)
	identical(negate(minus.log.x), log.x)

	identical(negate(1), call("-", 1))
	identical(negate(call("-", 1)), 1)
	identical(negate(-1), call("-", -1))
	identical(negate(call("-", -1)), -1)
})


## split_terms   #######################################################
## unsplit_terms #######################################################

stopifnot(exprs = {
	identical(split_terms(quote(+1)), expression( 1))
	identical(split_terms(quote(-1)), expression(-1))
	is.null(unsplit_terms(expression()))
})

x <- quote(1 + a * b - b)
l <- expression(1, a * b, -b)
stopifnot(exprs = {
	identical(split_terms(x), l)
	identical(unsplit_terms(l), x)
})

x <- quote(w + (x | f/g) + (y + z | h))
l <- expression(w, (x | f/g), (y + z | h))
x.no.paren <- x
x.no.paren[[2L]][[3L]] <- x.no.paren[[2L]][[3L]][[2L]]
x.no.paren      [[3L]] <- x.no.paren      [[3L]][[2L]]
l.no.paren <- as.expression(list(l[[1L]], l[[2L]][[2L]], l[[3L]][[2L]]))
stopifnot(exprs = {
	identical(split_terms(x), l.no.paren)
	identical(split_terms(x.no.paren), l.no.paren)
	identical(unsplit_terms(l), x.no.paren)
	identical(unsplit_terms(l.no.paren), x.no.paren)
})


## split_effects #######################################################

x <- y ~ x + (1 | f) + (a + b | g)
l <- expression(y ~ x, 1 | f, a + b | g)
l[[1L]] <- as.formula(l[[1L]])
stopifnot(identical(split_effects(x), l))


## split_interaction ###################################################

x <- quote(a:b:I(f:g):log(h))
l <- expression(a, b, I(f:g), log(h))
stopifnot(identical(split_interaction(x), l))
assertError(split_interaction(expression()))


## sub_bar_plus ########################################################

x1 <- ~x + (1 | f) + (a + b | g)
x2 <- call("+", call("+", quote(x), quote(1 + f)), quote(a + b + g))
x2 <- as.formula(call("~", x2))
stopifnot(identical(sub_bar_plus(x1), x2))


## simplify_terms ######################################################

x1 <- ~0 + x * y - y
y1 <- formula(terms(x1, simplify = TRUE))
stopifnot(identical(simplify_terms(x1), y1))

x2 <- ~0 + x * y - y + (1 | f/g) + (a | f) + (0 + b | f:g)
y2 <- y1
y2[[2L]] <- call("+",
                 call("+", y2[[2L]], quote(a | f)),
                 quote(b - 1 | f:g))
stopifnot(identical(simplify_terms(x2), y2))
