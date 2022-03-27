configuration tb_cpu_sim_pipe of tb_cpu is
	for sim
		for dut : cpu
			use entity work.cpu_pipelined(rtl);
			for rtl
				for register_file : registers
					use entity work.registers(sim);
				end for;
			end for;
		end for;
	end for;
end configuration;
