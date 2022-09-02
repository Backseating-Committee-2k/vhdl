TEST_EXTENSIONS = .backseat

BACKSEAT_LOG_DRIVER = ../src/bss2krun

TESTS = \
	base/halt_insn.backseat \
	base/endless_loop.backseat \
	base/assert_pass.backseat \
	base/assert_fail.backseat \
	insn/copy_reg_imm.backseat

XFAIL_TESTS = \
	base/endless_loop.backseat \
	base/assert_fail.backseat

EXTRA_DIST = \
	base/halt_insn.bsm \
	base/endless_loop.bsm \
	base/assert_pass.bsm \
	base/assert_fail.bsm \
	insn/copy_reg_imm.bsm

CLEANFILES = \
	$(TESTS)

.bsm.backseat:
	$(UPHOLSTERER2K) $< >$@.tmp && mv $@.tmp $@ || { $(RM) $@ $@.tmp; exit 1; }

.SECONDARY: $(TESTS)
