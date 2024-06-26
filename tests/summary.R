library(epigrowthfit)
options(warn = 2L, error = if (interactive()) recover)
example("egf", package = "epigrowthfit"); o.1 <- m1; o.2 <- m2


## object ##############################################################

o.1s <- summary(o.1)
o.1f <- fitted(o.1, class = TRUE, se = TRUE)
stopifnot(exprs = {
	is.list(o.1s)
	identical(oldClass(o.1s), "summary.egf")
	length(o.1s) == 5L
	identical(names(o.1s), c("fitted", "convergence", "value", "gradient", "hessian"))
	identical(o.1s[["convergence"]], o.1[["optimizer_out"]][["convergence"]])
	identical(o.1s[["value"]], o.1[["value"]])
	identical(o.1s[["gradient"]], o.1[["gradient"]])
	identical(o.1s[["hessian"]], o.1[["hessian"]])
	all.equal(o.1s[["fitted"]], simplify2array(c(tapply(o.1f[["value"]], o.1f[["top"]], summary))))
})


## print ###############################################################

vv <- withVisible(print(o.1s))
stopifnot(exprs = {
	identical(vv[["value"]], o.1s)
	identical(vv[["visible"]], FALSE)
})
