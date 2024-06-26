library(epigrowthfit)
options(warn = 2L, error = if (interactive()) recover)
example("egf", package = "epigrowthfit"); o.1 <- m1; o.2 <- m2


## object ##############################################################

o.1f <- fitted(o.1, class = TRUE, se = TRUE)
o.1f.e <- data.frame(top = gl(2L, 20L, labels = c("log(r)", "log(c0)")),
                     ts = gl(10L, 2L, 40L, labels = LETTERS[1:10]),
                     window = gl(20L, 1L, 40L, labels = sprintf("window_%02d", 1:20)),
                     value = as.double(o.1[["tmb_out"]][["env"]][[".__egf__."]][["adreport"]][["value"]]),
                     se = as.double(o.1[["tmb_out"]][["env"]][[".__egf__."]][["adreport"]][["sd"]]))
attr(o.1f.e, "se") <- TRUE
attr(o.1f.e, "ns") <- 20L
attr(o.1f.e, "nt") <- 2L
class(o.1f.e) <- c("fitted.egf", "data.frame")
stopifnot(identical(o.1f, o.1f.e))


## confint #############################################################

o.1fc <- confint(o.1f, level = 0.95, class = TRUE)
o.1fc.e <- o.1f[, c("top", "ts", "window", "value")]
o.1fc.e[["ci"]] <-
	`dimnames<-`(epigrowthfit:::wald(o.1f[["value"]], o.1f[["se"]],
	                                 level = 0.95),
	             list(NULL, c("2.5 %", "97.5 %")))
attr(o.1fc.e, "level") <- 0.95
class(o.1fc.e) <- c("confint.egf", "data.frame")
stopifnot(identical(o.1fc, o.1fc.e))
