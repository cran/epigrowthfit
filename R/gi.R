dgi <-
function(x, latent, infectious) {
	stopifnot(is.numeric(x),
	          is.numeric(latent),
	          (m <- length(latent)) > 0L,
	          all(is.finite(range(latent))),
	          min(latent) >= 0,
	          max(latent) >  0,
	          is.numeric(infectious),
	          (n <- length(infectious)) > 0L,
	          all(is.finite(range(infectious))),
	          min(infectious) >= 0,
	          max(infectious) >  0)
	if (length(x) == 0L)
		return(x)
	latent <- latent / sum(latent)
	infectious <- infectious / sum(infectious)

	d <- x
	d[] <- NA_real_
	l <- x < 1 | x >= m + n
	d[l] <- 0
	l <- !is.na(x) & !l
	if (any(l)) {
		## Take advantage of the fact that the generation interval density
		## is constant on intervals [i,i+1)
		floor.x <- floor(x[l])
		unique.floor.x <- unique(floor.x)
		k <- match(floor.x, unique.floor.x)

		ij.dim <- c(m, length(unique.floor.x))
		i <- .row(ij.dim)
		j <- .col(ij.dim)

		d[l] <- colSums(latent * diwt(unique.floor.x[j] - i, infectious))[k]
	}
	d
}

pgi <-
function(q, latent, infectious) {
	stopifnot(is.numeric(q),
	          is.numeric(latent),
	          (m <- length(latent)) > 0L,
	          is.numeric(infectious),
	          (n <- length(infectious)) > 0L)
	if (length(q) == 0L)
		return(q)

	p <- q
	p[] <- NA_real_
	p[q <= 1] <- 0
	p[q >= m + n] <- 1
	l <- !is.na(q) & q > 1 & q < m + n
	if (any(l)) {
		x <- seq_len(m + n)
		y <- c(0, cumsum(dgi(seq_len(m + n - 1L), latent, infectious)))
		p[l] <- approx(x, y, xout = q[l])[["y"]]
	}
	p
}

qgi <-
function(p, latent, infectious) {
	stopifnot(is.numeric(p))
	if (length(p) == 0L)
		return(p)
	stopifnot(is.numeric(latent),
	          (m <- length(latent)) > 0L,
	          is.numeric(infectious),
	          (n <- length(infectious)) > 0L)

	q <- p
	q[] <- NA_real_
	q[p < 0 | p > 1] <- NaN
	q[p == 0] <- -Inf
	q[p == 1] <- m + n
	l <- !is.na(p) & p > 0 & p < 1
	if (any(l)) {
		x <- c(0, cumsum(dgi(seq_len(m + n - 1L), latent, infectious)))
		y <- seq_len(m + n)
		q[l] <- approx(x, y, xout = p[l])[["y"]]
	}
	q
}

rgi <-
function(n, latent, infectious) {
	if (length(n) > 1L)
		n <- length(n)
	stopifnot(is.numeric(n),
	          length(n) == 1L,
	          n >= 0,
	          is.numeric(latent),
	          length(latent) > 0L,
	          all(is.finite(range(latent))),
	          min(latent) >= 0,
	          max(latent) >  0,
	          is.numeric(infectious),
	          length(infectious) > 0L,
	          all(is.finite(range(infectious))),
	          min(infectious) >= 0,
	          max(infectious) >  0)
	n <- trunc(n)
	if (n == 0)
		return(double(0L))
	latent <- latent / sum(latent)
	infectious <- infectious / sum(infectious)

	## Latent period is integer-valued,
	## equal to 'i' with probability 'latent[i]'
	rlp <- sample(seq_along(latent), size = n, replace = TRUE,
	              prob = latent)

	## Infectious waiting time is real-valued,
	## with distribution supported on [0,length(infectious))
	## and density constant on intervals [i,i+1)
	tt <- seq_along(infectious) - 1L
	floor.riwt <- sample(tt, size = n, replace = TRUE,
	                     prob = diwt(tt, infectious))
	riwt <- runif(n, min = floor.riwt, max = floor.riwt + 1L)

	## Sum of latent period and infectious waiting time
	## yields generation interval
	rlp + riwt
}

### Infectious period distribution function
pip <-
function(q, infectious) {
	n <- length(infectious)
	p <- q
	p[] <- NA_real_
	p[q < 1] <- 0
	p[q >= n] <- 1
	l <- !is.na(q) & q >= 1 & q < n
	if (any(l))
		p[l] <- cumsum(infectious)[floor(q[l])]
	p
}

### Infectious waiting time density function
diwt <-
function(x, infectious) {
	d <- x
	d[] <- NA_real_
	d[x < 0] <- 0
	l <- !is.na(x) & x >= 0
	if (any(l)) {
		tt <- seq_along(infectious)
		d[l] <- (1 - pip(x[l], infectious)) / sum(tt * infectious)
	}
	d
}
