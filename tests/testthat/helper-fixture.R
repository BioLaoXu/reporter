## Test fixture wrapper: the synthetic ChIP result-tree generator lives
## with the demo assets (inst/examples/) so examples and tests share one
## definition. See inst/examples/make_chip_fixture.R for details.
source(system.file("examples", "make_chip_fixture.R", package = "reporter"))
## (make_atac_fixture comes from the same inst/examples generator)
