# input clocks are already defined by pcie.sdc

# allow two cycles for multiplier path
set_multicycle_path \
	-from [get_registers {cpu_sequential:c|*:register_file|altsyncram:altsyncram_component|altsyncram_jer3:auto_generated|ram_block*~port*_we_reg}] \
	-through [get_nets {cpu_sequential:c|product[*]}] \
	-to [get_registers {cpu_sequential:c|wb_value*[*]}] \
	-setup \
	-end \
	2

derive_pll_clocks

derive_clock_uncertainty
