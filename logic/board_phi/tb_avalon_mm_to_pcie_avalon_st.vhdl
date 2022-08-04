library ieee;

use ieee.std_logic_1164.ALL;

library std;

use std.env.finish;

entity tb_avalon_mm_to_pcie_avalon_st is
end entity;

architecture sim of tb_avalon_mm_to_pcie_avalon_st is
	signal reset : std_logic;
	signal clk : std_logic := '0';

	signal req_addr : std_logic_vector(63 downto 0);
	signal req_rdreq : std_logic;
	signal req_rddata : std_logic_vector(63 downto 0);
	signal req_waitrequest : std_logic;

	signal cmp_rx_ready : std_logic;
	signal cmp_rx_valid : std_logic;
	signal cmp_rx_data : std_logic_vector(63 downto 0);
	signal cmp_rx_sop : std_logic;
	signal cmp_rx_eop : std_logic;
	signal cmp_rx_err : std_logic;

	signal cmp_rx_bardec : std_logic_vector(7 downto 0);

	signal cmp_tx_ready : std_logic;
	signal cmp_tx_valid : std_logic;
	signal cmp_tx_data : std_logic_vector(63 downto 0);
	signal cmp_tx_sop : std_logic;
	signal cmp_tx_eop : std_logic;
	signal cmp_tx_err : std_logic;

	signal cmp_tx_req : std_logic;
	signal cmp_tx_start : std_logic;

	signal cmp_cpl_pending : std_logic;

	signal device_id : std_logic_vector(15 downto 0);
begin
	reset <= '1', '0' after 100 ns;

	clk <= not clk after 10 ns;

	-- timeout
	process
	begin
		wait for 1 us;
		report "sim timeout" severity error;
		finish;
	end process;

	-- stimuli
	process
	begin
		cmp_tx_ready <= '1';
		req_addr <= (others => 'U');
		req_rdreq <= '0';
		wait until ?? (not reset);
		wait until rising_edge(clk);
		req_addr <= x"0123456789abcdef";
		req_rdreq <= '1';
		wait until rising_edge(clk);
		wait;
	end process;

	cmp_tx_start <= cmp_tx_req;

	device_id <= x"1234";

	-- dut
	dut : entity work.avalon_mm_to_pcie_avalon_st
		port map(
			reset => reset,
			clk => clk,
			req_addr => req_addr,
			req_rdreq => req_rdreq,
			req_rddata => req_rddata,
			req_waitrequest => req_waitrequest,
			cmp_rx_ready => cmp_rx_ready,
			cmp_rx_valid => cmp_rx_valid,
			cmp_rx_data => cmp_rx_data,
			cmp_rx_sop => cmp_rx_sop,
			cmp_rx_eop => cmp_rx_eop,
			cmp_rx_err => cmp_rx_err,
			cmp_rx_bardec => cmp_rx_bardec,
			cmp_tx_ready => cmp_tx_ready,
			cmp_tx_valid => cmp_tx_valid,
			cmp_tx_data => cmp_tx_data,
			cmp_tx_sop => cmp_tx_sop,
			cmp_tx_eop => cmp_tx_eop,
			cmp_tx_err => cmp_tx_err,
			cmp_tx_req => cmp_tx_req,
			cmp_tx_start => cmp_tx_start,
			cmp_cpl_pending => cmp_cpl_pending,
			device_id => device_id
		);
end architecture;
