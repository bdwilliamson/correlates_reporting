## all           : clean saved results and get results to populate report
all: clean cor_coxph 

## clean         : delete saved bootstrap results
clean:
	rm -f output/D29/*
	rm -f output/D57/*

## cor_coxph     : create tables and figures
cor_coxph:
	Rscript code/cor_coxph.R 57 && Rscript code/cor_coxph.R 29

## report        : create a standalone report
report:
	Rscript -e "rmarkdown::render('cor_coxph_report.Rmd')"

# turn down number of bootstraps and permutations in CoR for faster builds
before_script:
	echo "B <- 100" >> code/params.R
	echo "numPerm <- 50" >> code/params.R

test: before_script clean cor_coxph report


# type 'make help' to show all make commands
help: Makefile
	@sed -n 's/^##//p' $<

# define PHONYS
.PHONY: help clean cor_coxph
