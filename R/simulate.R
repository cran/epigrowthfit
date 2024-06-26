simulate.egf <-
function(object, nsim = 1, seed = NULL,
         bootstrap = FALSE,
         control = list(),
         parallel = egf_parallel(),
         trace = FALSE,
         ...) {
	## Set and preserve RNG state (modified from stats:::simulate.lm)
	if (!exists(".Random.seed", envir = globalenv(), inherits = FALSE))
		set.seed(NULL, "default", "default", "default")
	.R.s <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
	RNGstate <-
		if (is.null(seed))
			.R.s
		else {
			on.exit(assign(".Random.seed", .R.s, envir = globalenv()))
			set.seed(seed)
			`attr<-`(seed, "kind", as.list(RNGkind()))
		}

	## Configure OpenMP
	nomp <- object[["control"]][["omp_num_threads"]]
	if ((onomp <- TMB::openmp(n = NULL)) > 0L) {
		TMB::openmp(n = nomp)
		on.exit(add = TRUE, TMB::openmp(n = onomp))
	}

	stopifnot(isInteger(nsim), nsim >= 1, isTrueFalse(bootstrap))
	nsim <- as.integer(nsim)

	## Simulations are fast and can be done in the master process.
	## Simulating in the worker processes would require serializing
	## or reconstructing the TMB object, adding nontrivial overhead.
	frame <- model.frame(object)[c("ts", "window", "time")]
	frame[["X"]] <- X <-
		replicate(nsim,
		          object[["tmb_out"]][["simulate"]](object[["best"]])[["x"]])
	ans <- list(simulation = frame, bootstrap = NULL)

	if (bootstrap) {

	stopifnot(is.list(control),
	          inherits(parallel, "egf_parallel"),
	          isTrueFalse(trace))

	## Reconstruct list of arguments to 'MakeADFun' from object internals
	## for retaping
	args <- egf_tmb_remake_args(object[["tmb_out"]], par = object[["best"]])

	doBootstrap <-
	function(i, x) {
		if (trace)
			cat(gettextf("commencing bootstrap optimization %d of %d ...",
			             i, nsim),
			    "\n", sep = "")
		## Update
		args[["data"]][["x"]] <- x
		## Retape
		retape <- do.call(TMB::MakeADFun, args)
		## Optimize
		tryCatch(
			expr =
				{
					nlminb(retape[["par"]], retape[["fn"]], retape[["gr"]],
					       control = control)
					retape[["env"]][["last.par.best"]]
				},
			error =
				function(e) {
					cat(gettextf("error in bootstrap optimization %d of %d : %s",
					             i, nsim, conditionMessage(e)),
					    "\n", sep = "")
					par <- retape[["env"]][["last.par.best"]]
					par[] <- NaN
					par
				})
	}

	if (parallel[["method"]] == "snow") {
		## We use 'clusterExport' to export necessary objects to the
		## global environments of all worker processes.  As a result,
		## function environments are unused and need not be serialized.
		## By replacing them with the global environment,
		## which is never serialized, we avoid unnecessary overhead.
		environment(doBootstrap) <- globalenv()

		## Retrieve path to shared object for loading
		dll <- .dll

		cl <- parallel[["cl"]]
		if (is.null(cl)) {
			cl <- do.call(makePSOCKcluster, parallel[["args"]])
			on.exit(add = TRUE, stopCluster(cl))
		}
		vars <- c("dll", "nomp", "trace", "nsim", "args", "control")
		clusterExport(cl, varlist = vars, envir = environment())
		clusterEvalQ(cl, {
			dyn.load(dll)
			if (TMB::openmp(n = NULL) > 0L)
				TMB::openmp(n = nomp)
		})
		clusterSetRNGStream(cl)
		ans[["bootstrap"]] <-
			clusterMap(cl, doBootstrap, i = seq_len(nsim), x = asplit(X, 2L), simplify = TRUE)
	}
	else {
		if (nzchar(parallel[["outfile"]])) {
			outfile <- file(parallel[["outfile"]], open = "wt")
			sink(outfile, type = "output")
			sink(outfile, type = "message")
			on.exit(add = TRUE, {
				sink(type = "message")
				sink(type = "output")
			})
		}
		ans[["bootstrap"]] <-
			switch(parallel[["method"]],
			       multicore = do.call(mcmapply, c(list(FUN = doBootstrap, i = seq_len(nsim), x = asplit(X, 2L)), parallel[["args"]])),
			       serial = mapply(doBootstrap, seq_len(nsim), asplit(X, 2L)))
	}

	} # if (bootstrap)

	attr(ans, "RNGstate") <- RNGstate
	class(ans) <- "simulate.egf"
	ans
}

simulate.egf_model <-
function(object, nsim = 1, seed = NULL,
         mu, Sigma = NULL, tol = 1e-06,
         cstart = 0, tend = 100, ...) {
	## Set and preserve RNG state (modified from stats:::simulate.lm)
	if (!exists(".Random.seed", envir = globalenv(), inherits = FALSE))
		set.seed(NULL, "default", "default", "default")
	.R.s <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
	RNGstate <-
		if (is.null(seed))
			.R.s
		else {
			on.exit(assign(".Random.seed", .R.s, envir = globalenv()))
			`attr<-`(seed, "kind", as.list(RNGkind()))
		}
	RNGreset <-
	function() {
		if (is.null(seed))
			NULL ## assign(".Random.seed", .R.s, globalenv())
		else set.seed(seed)
	}

	stopifnot(isInteger(nsim), nsim >= 1)
	nsim <- as.integer(nsim)

	top <- egf_top(object)
	p <- length(top)
	stopifnot(is.numeric(mu), length(mu) == p, is.finite(mu))
	names(mu) <- top
	if (!is.null(Sigma)) {
		stopifnot(isNumber(tol), tol >= 0,
		          is.numeric(Sigma),
		          dim(Sigma) == length(mu),
		          is.finite(Sigma),
		          isSymmetric(Sigma),
		          (e <- eigen(Sigma, symmetric = TRUE, only.values = TRUE)[["values"]]) > -tol * abs(e[1L]))
		dimnames(Sigma)[1:2] <- list(top)
	}

	has.infl <- any(object[["curve"]] == c("gompertz", "logistic", "richards"))
	tend <-
	if (has.infl) {
		## Time: daily from 0 days to <inflection time>+1 days
		if (is.null(Sigma))
			## Fixed intercept model: inflection time is known up front.
			ceiling(exp(mu[["log(tinfl)"]])) + 1
		else
			## Random intercept model: inflection time is not known up front.
			## Two passes are necessary.  The first pass asks for time series
			## of minimal length (hence tend <- 1) and serves only to retrieve
			## randomly generated inflection times.  The second pass asks for
			## time series of appropriate length.
			1
	}
	else {
		## Time: daily from 0 days to 'tend' days
		stopifnot(isNumber(tend), tend > 0)
		max(1, trunc(tend))
	}
	stopifnot(isNumber(cstart))

	## Construct arguments to 'egf' corresponding to 'nsim', 'mu', 'Sigma'
	formula_ts <- cbind(time, x) ~ ts
	formula_windows <- cbind(start, end) ~ ts
	data_ts <- data.frame(ts = gl(nsim, 1L + as.integer(tend)),
	                      time = seq.int(0, tend, 1),
	                      x = 0L) # arbitrary non-negative integer
	data_windows <- data.frame(ts = gl(nsim, 1L),
	                           start = 0,
	                           end = tend)
	if (is.null(Sigma)) {
		if (nsim == 1L) {
			formula_parameters <- ~1
			init <- list(beta = mu, theta = double(0L), b = double(0L))
		}
		else {
			formula_parameters <- ~ts
			beta <- double(p * nsim)
			beta[seq.int(from = 1L, by = nsim, length.out = p)] <- mu
			init <- list(beta = beta, theta = double(0L), b = double(0L))
		}
	}
	else {
		formula_parameters <- ~(1 | ts)
		init <- list(beta = mu, theta = cov2theta(Sigma), b = double(nsim * p))
	}
	environment(formula_ts) <- environment(formula_windows) <-
		environment(formula_parameters) <- globalenv()

	## Create TMB object without optimizing
	mm <- egf(object,
	          formula_ts = formula_ts,
	          formula_windows = formula_windows,
	          formula_parameters = formula_parameters,
	          data_ts = data_ts,
	          data_windows = data_windows,
	          init = init,
	          fit = FALSE)

	par <- unlist1(init)

	if (has.infl && !is.null(Sigma)) {
		## Second pass with 'data' of appropriate length,
		## determined by simulated inflection times
		RNGreset()
		ss <- mm[["tmb_out"]][["simulate"]](par)
		dimnames(ss[["Y"]]) <- list(NULL, top)
		tend <- ceiling(exp(ss[["Y"]][, "log(tinfl)"])) + 1
		time <- lapply(tend, function(to) seq.int(0, to, 1))
		data_ts <- data.frame(ts = rep.int(gl(nsim, 1L), lengths(time)),
		                      time = unlist1(time),
		                      x = 0L) # arbitrary non-negative integer
		data_windows <- data.frame(ts = gl(nsim, 1L),
		                           start = 0,
		                           end = tend)
		mm <- update(mm, data_ts = data_ts, data_windows = data_windows)
	}

	## Simulate
	RNGreset()
	ss <- mm[["tmb_out"]][["simulate"]](par)
	dimnames(ss[["Y"]]) <- list(NULL, top)

	## Replace dummy observations in 'data' with simulated ones
	data_ts[["x"]][] <- NA
	data_ts[["x"]][duplicated(data_ts[["ts"]])] <- ss[["x"]]

	## Choose fitting window start times according to 'cstart' rule
	start <-
	function(d) {
		l <- c(0L, cumsum(d[["x"]][-1L])) > cstart
		if (any(l)) d[["time"]][which.max(l)] else NA_real_
	}
	data_windows[["start"]] <- c(by(data_ts, data_ts[["ts"]], start))
	if (anyNA(data_windows[["start"]])) {
		argna <- is.na(data_windows[["start"]])
		data_windows[["start"]][argna] <- 0
		warning(gettextf("threshold '%s' not exceeded in time series %s; corresponding fitting windows contain all observations",
		                 "cstart", deparse(which(argna))),
		        domain = NA)
	}

	ans <- list(model = object,
	            formula_ts = formula_ts,
	            formula_windows = formula_windows,
	            formula_parameters = formula_parameters,
	            data_ts = data_ts,
	            data_windows = data_windows,
	            init = init[names(init) != "b"],
	            Y = ss[["Y"]],
	            call = match.call())
	attr(ans, "RNGstate") <- RNGstate
	class(ans) <- "simulate.egf_model"
	ans
}

coef.simulate.egf_model <-
function(object, ...) {
	init <- object[["init"]]
	ans <- unlist1(init)
	len <- lengths(init)
	map <- vector("list", length(len))
	names(map) <- names(len)
	attr(ans, "len") <- len
	attr(ans, "map") <- map
	class(ans) <- "coef.egf"
	ans
}

egf.simulate.egf_model <-
function(model, ...) {
	nel <- c("model", "formula_ts", "formula_windows", "formula_parameters",
	         "data_ts", "data_windows")
	args <- model[nel]
	if (...length() > 0L && !is.null(ndots <- names(dots <- list(...))))
		args <- c(args, dots[match(ndots, nel, 0L) == 0L])
	do.call(egf, args)
}

getCall.simulate.egf_model <-
function(x, ...) {
	call <- NextMethod("getCall")
	call[[1L]] <- quote(simulate)
	call
}
