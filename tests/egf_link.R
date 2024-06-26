attach(asNamespace("epigrowthfit"))
library(tools)
options(warn = 2L, error = if (interactive()) recover)


## egf_link_get     ####################################################
## egf_link_add     ####################################################
## egf_link_remove  ####################################################
## egf_link_extract ####################################################

x0 <- egf_top(NULL, link = FALSE)
x1 <- egf_link_add(x0)
link <- egf_link_get(x0)

identical(link, ifelse(x0 == "p", "logit", "log"))
identical(egf_link_get("invalid name"), NA_character_)
identical(egf_link_get("log(r)"), NA_character_)

identical(x1, sprintf("%s(%s)", link, x0))
identical(egf_link_add("invalid name"), NA_character_)
identical(egf_link_add("log(r)"), NA_character_)

identical(egf_link_remove(x1), x0)
identical(egf_link_remove("invalid name"), NA_character_)
identical(egf_link_remove("r"), NA_character_)

identical(egf_link_extract(x1), link)
identical(egf_link_extract("invalid name"), NA_character_)
identical(egf_link_extract("r"), NA_character_)


## egf_link_match ######################################################

identical(egf_link_match("identity"), identity)
identical(egf_link_match("log"), log)
identical(egf_link_match("logit"), qlogis)
assertError(egf_link_match("invalid name"))

identical(egf_link_match("identity", inverse = TRUE), identity)
identical(egf_link_match("log", inverse = TRUE), exp)
identical(egf_link_match("logit", inverse = TRUE), plogis)
assertError(egf_link_match("invalid name", inverse = TRUE))


## egf_top #############################################################

x1 <- NULL
x2 <- egf_model()
x3 <- list(model = x2)
class(x3) <- "egf"

s1 <- egf_top(x1, link = FALSE)
s2 <- egf_top(x2, link = FALSE)
s3 <- egf_top(x3, link = FALSE)

stopifnot(exprs = {
	is.character(s1)
	length(s1) > 0L
	!anyNA(s1)
	is.null(names(s1))

	is.character(s2)
	length(s2) > 0L
	match(s2, s1, 0L) > 0L

	identical(s3, s2)
})
