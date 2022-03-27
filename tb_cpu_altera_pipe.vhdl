configuration tb_cpu_altera_pipe of tb_cpu is
	for sim
		for dut : cpu
			use entity work.cpu_pipelined;
			for rtl
				for register_file : registers
					use entity work.altera_registers(SYN);
				end for;
			end for;
		end for;
	end for;
end configuration;
