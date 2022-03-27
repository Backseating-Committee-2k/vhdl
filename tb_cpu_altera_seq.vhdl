configuration tb_cpu_altera_seq of tb_cpu is
	for sim
		for dut : cpu
			use entity work.cpu_sequential;
			for rtl
				for r : registers
					use entity work.altera_registers(SYN);
				end for;
			end for;
		end for;
	end for;
end configuration;
