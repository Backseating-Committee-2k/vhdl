configuration tb_cpu_altera of tb_cpu is
	for sim
		for dut : cpu
			use entity work.cpu(sequential);
			for rtl
				for r : registers
					use entity work.altera_registers(SYN);
				end for;
			end for;
		end for;
	end for;
end configuration;
