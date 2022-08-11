library ieee;

use ieee.std_logic_1164.ALL;

library std;

use std.env.finish;

entity tb_textmode_output is
end entity;

architecture sim of tb_textmode_output is
	signal reset : std_logic;
	signal clk : std_logic := '0';

	signal start : std_logic;

	signal tx_ready : std_logic;
	signal tx_valid : std_logic;
	signal tx_data : std_logic_vector(63 downto 0);
	signal tx_sop : std_logic;
	signal tx_eop : std_logic;
	signal tx_err : std_logic;
	signal cpl_pending : std_logic;
	signal tx_req : std_logic;
	signal tx_start : std_logic;

	signal d_addr : std_logic_vector(23 downto 0);
	signal d_wrreq : std_logic;
	signal d_wrdata : std_logic_vector(31 downto 0);
	signal d_waitrequest : std_logic;
begin
	reset <= '1', '0' after 100 ns;

	clk <= not clk after 4 ns;

	tx_start <= tx_req after 40 ns;

	process is
	begin
		wait for 1 ms;
		report "sim timeout" severity error;
		finish;
	end process;

	process is
	begin
		wait until ?? reset;
		tx_ready <= '0';
		start <= '0';
		d_wrreq <= '0';
		wait until not (?? reset);
		wait until rising_edge(clk);
		tx_ready <= '1';
		d_addr <= x"000000";
		d_wrreq <= '1';
		d_wrdata <= x"00000048";
		wait until rising_edge(clk) and not (?? d_waitrequest);
		d_wrreq <= '0';
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		start <= '1';
		wait until rising_edge(clk);
		start <= '0';
		wait;
	end process;

	dut : entity work.textmode_output
		port map(
			reset => reset,
			clk => clk,

			target_address => x"1234567800000000",
			start => start,

			tx_ready => tx_ready,
			tx_valid => tx_valid,
			tx_data => tx_data,
			tx_sop => tx_sop,
			tx_eop => tx_eop,
			tx_err => tx_err,

			cpl_pending => cpl_pending,

			tx_req => tx_req,
			tx_start => tx_start,

			device_id => x"4230",

			d_addr => d_addr,
			d_wrreq => d_wrreq,
			d_wrdata => d_wrdata,
			d_waitrequest => d_waitrequest
	);
end architecture;
