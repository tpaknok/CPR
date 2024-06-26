INLA_simulate <- function(object,
                           nsim = 250,
                           Ntrails=NULL) {

  if(object$.args$family == "binomial") {
    Ntrials <- Ntrials
  } else {
    Ntrials <- 1
  }

  f <- get(paste0("inla.link.",object$misc$linkfunctions$names)) #link function!!
  fam <- object$.args$family

      samples <- inla.posterior.sample(nsim, object)

      mu_sim <- lapply(samples, function(x) f(x$latent[1:length(na.omit(object$waic$local.waic))],
                                             inverse=T))

      sim <- switch(object$.args$family,
                    binomial = lapply(mu_sim, function(x) rbinom(length(x), Ntrials, x)),
                    poisson = lapply(mu_sim, function(x) rpois(length(x), x)),
                    nbinomial = {
                      relevant <- grep(
                        "size for the nbinomial observations",
                        names(samples[[1]]$hyperpar)
                      )
                      size <- inla.hyperpar.sample(n = nsim, result = object)[, relevant]
                      lapply(1:nsim, function(x) rnbinom(n = length(mu_sim[[x]]),
                                                         mu = mu_sim[[x]],
                                                         size = size[[x]]))
                      },
                    gaussian = {
                      relevant <- grep(
                        "Precision for the Gaussian observations",
                        names(samples[[1]]$hyperpar)
                      )
                      size <- inla.hyperpar.sample(n = nsim, result = object)[, relevant]
                      lapply(mu_sim, function(x) rnorm(length(x),x,sqrt(1/size)))}, #need sd but back convert from precision (1/variance),
                    tweedie = {
                      require(mgcv)
                      message("residuals of tweedie distribution takes a long time to simulate...be prepared")
                      phi_pos <- grep(
                        "Dispersion parameter for Tweedie",
                        names(samples[[1]]$hyperpar)
                      )
                      p_pos <- grep(
                        "p parameter for Tweedie",
                        names(samples[[1]]$hyperpar)
                        )
                      hyperparameter <- inla.hyperpar.sample(n = nsim, result = object)[, c(p_pos,phi_pos)]
                      lapply(1:nsim, function(x) rTweedie(mu=mu_sim[[x]],
                                                          p=hyperparameter[x,1],
                                                          phi=hyperparameter[x,2]))
                    },
                    zeroinflatednbinomial1 = {
                      require(VGAM)
                      size_pos <- grep(
                        "size for nbinomial zero-inflated observations",
                        names(samples[[1]]$hyperpar)
                      )
                      pstr0_pos <- grep(
                        "zero-probability parameter for zero-inflated nbinomial_1",
                        names(samples[[1]]$hyperpar)
                      )
                      hyperparameter <- inla.hyperpar.sample(n = nsim, result = object)[, c(size_pos,pstr0_pos)]
                      lapply(1:nsim, function(x) rzinegbin(n = length(mu_sim[[x]]),
                                                           munb = mu_sim[[x]],
                                                           size = hyperparameter[x,1],
                                                           pstr0 = hyperparameter[x,2]))
                    }
                            )

      sim <- do.call(cbind, sim)

  return(sim)
}
