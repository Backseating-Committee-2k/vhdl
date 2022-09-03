TEST_EXTENSIONS = .backseat

BACKSEAT_LOG_DRIVER = ../src/bss2krun

TESTS = \
	halt.backseat \
	timeout.backseat \
	assert_pass.backseat \
	assert_xfail.backseat

XFAIL_TESTS = \
	timeout.backseat \
	assert_xfail.backseat

EXTRA_DIST = \
	halt.bsm \
	timeout.bsm \
	assert_pass.bsm \
	assert_xfail.bsm

CLEANFILES = \
	$(TESTS)

.bsm.backseat:
	$(UPHOLSTERER2K) $< >$@.tmp && mv $@.tmp $@ || { $(RM) $@ $@.tmp; exit 1; }

.SECONDARY: $(TESTS)
