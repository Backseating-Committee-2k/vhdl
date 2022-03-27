configuration tb_cpu_sim_seq of tb_cpu is
	for sim
		for dut : cpu
			use entity work.cpu_sequential(rtl);
			for rtl
				for register_file : registers
					use entity work.registers(sim);
				end for;
			end for;
		end for;
	end for;
end configuration;
