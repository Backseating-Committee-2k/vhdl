library ieee;

use ieee.std_logic_1164.ALL;

library std;

use std.env.finish;

entity tb_interrupt_encoder is
end entity;

architecture sim of tb_interrupt_encoder is
	signal reset : std_logic;
	signal clk : std_logic := '0';

	signal int_sts : std_logic_vector(31 downto 0);

	signal msi_int_req : std_logic;
	signal msi_int_num : std_logic_vector(4 downto 0);
	signal msi_int_tc : std_logic_vector(2 downto 0);
	signal msi_int_ack : std_logic;
begin
	-- reset gen
	reset <= '1', '0' after 20 ns;

	-- clock gen
	clk <= not clk after 4 ns;

	-- sim timeout
	process is
	begin
		wait for 1 us;
		report "sim timeout" severity error;
		finish;
	end process;

	-- stimuli
	process is
		procedure tick is
		begin
			wait until rising_edge(clk);
		end procedure;
	begin
		int_sts <= (others => '0');
		msi_int_ack <= '0';

		wait until not (?? reset);

		tick;
		assert not (?? msi_int_req) report "status set with no request" severity error;

		tick;
		assert not (?? msi_int_req) report "status set with no request" severity error;
		int_sts(0) <= '1';

		wait until ?? msi_int_req;
		assert msi_int_num = "00000" report "wrong interrupt number reported" severity error;

		tick;
		tick;
		int_sts(0) <= '0';
		wait until not (?? msi_int_req);

		int_sts(3) <= '1';
		int_sts(17) <= '1';

		wait until ?? msi_int_req;
		assert msi_int_num = "10001" report "wrong interrupt number reported" severity error;

		tick;
		tick;
		msi_int_ack <= '1';

		wait until not (?? msi_int_req);

		tick;
		tick;
		tick;
		msi_int_ack <= '0';

		wait until ?? msi_int_req;
		assert msi_int_num = "00011" report "wrong interrupt number reported" severity error;

		tick;
		tick;
		msi_int_ack <= '1';

		wait until not (?? msi_int_req);

		msi_int_ack <= '0';
		tick;

		int_sts(17) <= '0';
		tick;
		int_sts(17) <= '1';
		tick;

		wait until ?? msi_int_req;
		assert msi_int_num = "10001" report "wrong interrupt number reported" severity error;

		tick;
		tick;
		msi_int_ack <= '1';

		wait until not (?? msi_int_req);

		wait for 10 ns;
		finish;
	end process;

	dut : entity work.interrupt_encoder
		port map(
			reset => reset,
			clk => clk,

			int_sts => int_sts,

			legacy_int_sts => open,
			legacy_int_ack => '0',

			msi_int_req => msi_int_req,
			msi_int_num => msi_int_num,
			msi_int_tc => msi_int_tc,
			msi_int_ack => msi_int_ack
		);
end architecture;
