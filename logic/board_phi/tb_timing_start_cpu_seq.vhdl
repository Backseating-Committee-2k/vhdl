configuration tb_timing_start_cpu_seq of tb_timing_start_cpu is
	for sim
		for board_inst : top
			use entity work.top;
			for rtl
				for c : cpu
					use entity work.cpu_sequential;
				end for;
			end for;
		end for;
	end for;
end configuration;
