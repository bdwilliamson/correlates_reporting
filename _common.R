library(methods)
library(dplyr)
library(kyotil)
set.seed(98109)
config <- config::get(config = Sys.getenv("TRIAL"))
for(opt in names(config)){
  eval(parse(text = paste0(names(config[opt])," <- config[[opt]]")))
}
names(assays)=assays # add names so that lapply results will have names

# if this flag is true, then the N IgG binding antibody is reported 
# in the immuno report (but is not analyzed in the cor or cop reports).
include_bindN <- TRUE

# limits for each assay (IU for bAb, no need to convert again)
# the following are copied from SAP to avoid any mistake (get rid of commas)
tmp=list(
    bindSpike=c(
        LLOD = 0.3076,
        ULOD = 172226.2,
        LLOQ = 1.7968,
        ULOQ = 10155.95)
    ,
    bindRBD=c(
        LLOD = 1.593648,
        ULOD = 223074,
        LLOQ = 5.7727,
        ULOQ = 369.4486)
    ,
    bindN=c( 
        LLOD = 0.093744,
        ULOD = 52488,
        LLOQ = 4.4897,
        ULOQ = 574.6783)
    ,
    pseudoneutid50=c( 
        LLOD = 10,
        ULOD = NA,
        LLOQ = 18.5,
        ULOQ = 4404)
    ,
    pseudoneutid80=c( 
        LLOD = 10,
        ULOD = NA,
        LLOQ = 14.3,
        ULOQ = 1295)
    ,
    liveneutmn50=c( 
        LLOD = 62.16,
        ULOD = NA,
        LLOQ = 117.35,
        ULOQ = 18976.19)
)

llods=sapply(tmp, function(x) unname(x["LLOD"]))
lloqs=sapply(tmp, function(x) unname(x["LLOQ"]))
uloqs=sapply(tmp, function(x) unname(x["ULOQ"]))

#llods <-c(
#          bindSpike = 0.180, 
#          bindRBD = 0.544, 
#          bindN = 0.048, 
#          pseudoneutid50 = 10, 
#          pseudoneutid80 = 10, 
#          liveneutmn50 = 62.16)
#
#lloqs <-c(
#          bindSpike = 0.3060, 
#          bindRBD = 0.9248, 
#          bindN = 0.0816, 
#          pseudoneutid50 = 18.5, 
#          pseudoneutid80 = 14.3, 
#          liveneutmn50 = 117.35) 
#
#uloqs <-c(
#          bindSpike = 172226.2, 
#          bindRBD = 520506.0, 
#          bindN = 45927.0, 
#          pseudoneutid50 = 4404, 
#          pseudoneutid80 = 1295, 
#          liveneutmn50 = 18976.19) 


convf=c(bindSpike=0.0090, bindN=0.0024, bindRBD=0.0272)

must_have_assays <- c(
  "bindSpike", "bindRBD"
  # NOTE: the live neutralization marker will eventually be available
  #"liveneutmn50"
)


assays_to_be_censored_at_uloq_cor <- c(
  "bindSpike", "bindRBD", "pseudoneutid50", "pseudoneutid80"
  # NOTE: the live neutralization marker will eventually be available
  #"liveneutmn50"
)

###############################################################################
# figure labels and titles for markers
###############################################################################
has29 = "Day29" %in% times

markers <- c(outer(times[which(times %in% c("B", "Day29", "Day57"))], 
                   assays, "%.%"))

# race labeling
labels.race <- c(
  "White", "Black or African American",
  "Asian", "American Indian or Alaska Native",
  "Native Hawaiian or Other Pacific Islander", "Multiracial",
  "Other", "Not reported and unknown"
)

# ethnicity labeling
labels.ethnicity <- c(
  "Hispanic or Latino", "Not Hispanic or Latino",
  "Not reported and unknown"
)

labels.assays.short <- c("Anti N IgG (IU/ml)", 
                         "Anti Spike IgG (IU/ml)", 
                         "Anti RBD IgG (IU/ml)", 
                         "Pseudovirus-nAb ID50", 
                         "Pseudovirus-nAb ID80", 
                         "Live virus-nAb MN50")
names(labels.assays.short) <- c("bindN",
  "bindSpike",
  "bindRBD",
  "pseudoneutid50",
  "pseudoneutid80",
  "liveneutmn50")

# hacky fix for tabular, since unclear who else is using
# the truncated labels.assays.short later
labels.assays.short.tabular <- labels.assays.short

labels.time <- c("Day 1", "Day 29", "Day 57", 
                 "D29 fold-rise over D1", 
                 "D57 fold-rise over D1", 
                 "D57 fold-rise over D29")

names(labels.time) <- c("B", "Day29", "Day57", "Delta29overB", 
                        "Delta57overB", "Delta57over29")

# axis labeling
labels.axis <- outer(
  rep("", length(times)),
  labels.assays.short[assays],
  "%.%"
)
labels.axis <- as.data.frame(labels.axis)
rownames(labels.axis) <- times

labels.assays <- c("Binding Antibody to Spike", 
                   "Binding Antibody to RBD",
                   "PsV Neutralization 50% Titer",
                   "PsV Neutralization 80% Titer",
                   "WT LV Neutralization 50% Titer")

names(labels.assays) <- c("bindSpike", 
                          "bindRBD", 
                          "pseudoneutid50",
                          "pseudoneutid80",
                          "liveneutmn50")

# title labeling
labels.title <- outer(
  labels.assays[assays],
  ": " %.%
    c(
      "Day 1", "Day 29", "Day 57", "D29 fold-rise over D1",
      "D57 fold-rise over D1", "D57 fold-rise over D29"
    ),
  paste0
)
labels.title <- as.data.frame(labels.title)
colnames(labels.title) <- times
# NOTE: hacky solution to deal with changes in the number of markers
rownames(labels.title)[seq_along(assays)] <- assays
labels.title <- as.data.frame(t(labels.title))

# creating short and long labels
labels.assays.short <- labels.axis[1, ]
labels.assays.long <- labels.title

# baseline stratum labeling
Bstratum.labels <- c(
  "Age >= 65",
  "Age < 65, At risk",
  "Age < 65, Not at risk"
)

# baseline stratum labeling
demo.stratum.labels <- c(
  "Age >= 65, URM",
  "Age < 65, At risk, URM",
  "Age < 65, Not at risk, URM",
  "Age >= 65, White non-Hisp",
  "Age < 65, At risk, White non-Hisp",
  "Age < 65, Not at risk, White non-Hisp"
)

###############################################################################
# reproduciblity options
###############################################################################

# NOTE: used in appendix.Rmd to store digests of input raw/processed data files
# hash algorithm picked based on https://csrc.nist.gov/projects/hash-functions
hash_algorithm <- "sha256"


###############################################################################
# theme options
###############################################################################

# fixed knitr chunk options
knitr::opts_chunk$set(
  comment = "#>",
  collapse = TRUE,
  out.width = "80%",
  out.extra = "",
  fig.pos = "H",
  fig.show = "hold",
  fig.align = "center",
  fig.width = 6,
  fig.asp = 0.618,
  fig.retina = 0.8,
  dpi = 600,
  echo = FALSE,
  message = FALSE,
  warning = FALSE
)

# global options
options(
  digits = 6,
  #scipen = 999,
  dplyr.print_min = 6,
  dplyr.print_max = 6,
  crayon.enabled = FALSE,
  bookdown.clean_book = TRUE,
  knitr.kable.NA = "NA",
  repos = structure(c(CRAN = "https://cran.rstudio.com/"))
)

# no complaints from installation warnings
Sys.setenv(R_REMOTES_NO_ERRORS_FROM_WARNINGS="true")

# overwrite options by output type
if (knitr:::is_html_output()) {
  #options(width = 80)

  # automatically create a bib database for R packages
  knitr::write_bib(c(
    .packages(), "bookdown", "knitr", "rmarkdown"
  ), "packages.bib")
}
if (knitr:::is_latex_output()) {
  #knitr::opts_chunk$set(width = 67)
  #options(width = 67)
  options(cli.unicode = TRUE)

  # automatically create a bib database for R packages
  knitr::write_bib(c(
    .packages(), "bookdown", "knitr", "rmarkdown"
  ), "packages.bib")
}

# create and set global ggplot theme
# borrowed from https://github.com/tidymodels/TMwR/blob/master/_common.R
theme_transparent <- function(...) {
  # use black-white theme as base
  ret <- ggplot2::theme_bw(...)

  # modify with transparencies
  trans_rect <- ggplot2::element_rect(fill = "transparent", colour = NA)
  ret$panel.background  <- trans_rect
  ret$plot.background   <- trans_rect
  ret$legend.background <- trans_rect
  ret$legend.key        <- trans_rect

  # always have legend below
  ret$legend.position <- "bottom"
  return(ret)
}

library(ggplot2)
theme_set(theme_transparent())
theme_update(
  text = element_text(size = 25),
  axis.text.x = element_text(colour = "black", size = 30),
  axis.text.y = element_text(colour = "black", size = 30)
)

# custom ggsave function with updated defaults
ggsave_custom <- function(filename = default_name(plot),
                          height= 15, width = 21, ...) {
  ggsave(filename = filename, height = height, width = width, ...)
}



get.range.cor=function(dat, assay=c("bindSpike", "bindRBD", "pseudoneutid50", "pseudoneutid80"), time=c("57","29")) {
    assay<-match.arg(assay)
    a <- assay # Fixes bug
    time<-match.arg(time)        
    if(assay %in% c("bindSpike", "bindRBD")) {
        ret=range(dat[["Day"%.%time%.%"bindSpike"]], dat[["Day"%.%time%.%"bindRBD"]], log10(llods[c("bindSpike","bindRBD")]/2), na.rm=T)
        ret[2]=ceiling(ret[2]) # round up
    } else if(assay %in% c("pseudoneutid50", "pseudoneutid80")) {
        ret=range(dat[["Day"%.%time%.%a]], log10(llods[c("pseudoneutid50","pseudoneutid80")]/2), log10(uloqs[c("pseudoneutid50","pseudoneutid80")]), na.rm=T)
        ret[2]=ceiling(ret[2]) # round up
    }  
    delta=(ret[2]-ret[1])/20     
    c(ret[1]-delta, ret[2]+delta)
}

draw.x.axis.cor=function(xlim, llod){
#    if(xlim[2]<3) {
#        xx = (c(10,25,50,100,250,500,1000))
#        for (x in xx) axis(1, at=log10(x), labels=if (llod==x) "lod" else if (x==1000) bquote(10^3) else x  ) 
#    } else if(xlim[2]<4) {
#        xx = (c(10,50,250,1000,5000,10000))
#        for (x in xx) axis(1, at=log10(x), labels=if (llod==x) "lod" else if (x %in% c(1000,10000)) bquote(10^.(log10(x))) else if (x==5000) bquote(.(x/1000)%*%10^3) else  x ) 
#    } else {
        xx=seq(floor(xlim[1]), ceiling(xlim[2]))
        for (x in xx) if (x>log10(llod*2)) axis(1, at=x, labels=if (log10(llod)==x) "lod" else if (x>=3) bquote(10^.(x)) else 10^x )
#    }
    
    # plot llod if llod is not already plotted
    #if(!any(log10(llod)==xx)) 
    axis(1, at=log10(llod), labels="lod")
    
}

##### Copy of draw.x.axis.cor but returns the x-axis ticks and labels
# This is necessary if one works with ggplot as the "axis" function does not work.
get.labels.x.axis.cor=function(xlim, llod){
  xx=seq(floor(xlim[1]), ceiling(xlim[2]))
  xx=xx[xx>log10(llod*2)]
  x_ticks <- xx
  labels <- sapply(xx, function(x) {
    if (log10(llod)==x) "lod" else if (x>=3) bquote(10^.(x)) else 10^x
  })
  #if(!any(log10(llod)==x_ticks)){
    x_ticks <- c(log10(llod), x_ticks)
    labels <- c("lod", labels)
  #}
  return(list(ticks = x_ticks, labels = labels))
}
