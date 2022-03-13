configuration tb_cpu_sim of tb_cpu is
	for sim
		for dut : cpu
			use entity work.cpu(sequential);
			for sequential
				for r : registers
					use entity work.registers(sim);
				end for;
			end for;
		end for;
	end for;
end configuration;
