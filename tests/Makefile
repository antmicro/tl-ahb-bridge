export PYTHONWARNINGS = error,ignore::DeprecationWarning:distutils,ignore::DeprecationWarning:site

regression_tests :=  $(shell ls test_TileLinkUL/)

.PHONY: $(regression_tests)

SIM?=verilator

all: $(regression_tests)

$(regression_tests):
	cd test_TileLinkUL/$@/code && $(MAKE) SIM=$(SIM)



clean:
	$(foreach TEST, $(regression_tests), $(MAKE) -C test_TileLinkUL/$(TEST)/code clean;)

regression:
	$(foreach TEST, $(regression_tests), $(MAKE) -C test_TileLinkUL/$(TEST)/code regression;)
