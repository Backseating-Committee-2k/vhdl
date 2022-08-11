library ieee;

use ieee.std_logic_1164.ALL;

library std;

use std.env.finish;

entity tb_pcie_arbiter is
end entity;

architecture sim of tb_pcie_arbiter is
	signal reset : std_logic;
	signal clk : std_logic := '0';

	signal upstream_tx_ready : std_logic;
	signal upstream_tx_valid : std_logic;
	signal upstream_tx_data : std_logic_vector(63 downto 0);
	signal upstream_tx_sop : std_logic;
	signal upstream_tx_eop : std_logic;
	signal upstream_tx_err : std_logic;
	signal upstream_cpl_pending : std_logic;

	signal upstream_req_shortcut : std_logic;

	signal downstream1_tx_ready : std_logic;
	signal downstream1_tx_valid : std_logic;
	signal downstream1_tx_data : std_logic_vector(63 downto 0);
	signal downstream1_tx_sop : std_logic;
	signal downstream1_tx_eop : std_logic;
	signal downstream1_tx_err : std_logic;
	signal downstream1_cpl_pending : std_logic;
	signal downstream1_tx_req : std_logic;
	signal downstream1_tx_start : std_logic;

	signal downstream2_tx_ready : std_logic;
	signal downstream2_tx_valid : std_logic;
	signal downstream2_tx_data : std_logic_vector(63 downto 0);
	signal downstream2_tx_sop : std_logic;
	signal downstream2_tx_eop : std_logic;
	signal downstream2_tx_err : std_logic;
	signal downstream2_cpl_pending : std_logic;
	signal downstream2_tx_req : std_logic;
	signal downstream2_tx_start : std_logic;

	signal downstream3_tx_ready : std_logic;
	signal downstream3_tx_valid : std_logic;
	signal downstream3_tx_data : std_logic_vector(63 downto 0);
	signal downstream3_tx_sop : std_logic;
	signal downstream3_tx_eop : std_logic;
	signal downstream3_tx_err : std_logic;
	signal downstream3_cpl_pending : std_logic;
	signal downstream3_tx_req : std_logic;
	signal downstream3_tx_start : std_logic;
begin
	-- reset gen
	reset <= '1', '0' after 100 ns;

	-- clock gen
	clk <= not clk after 4 ns;

	-- sim timeout
	process is
	begin
		wait for 20 us;
		report "sim timeout" severity error;
		finish;
	end process;

	-- stimuli
	process is
	begin
		wait until ?? reset;
		downstream1_tx_valid <= '0';
		downstream1_cpl_pending <= '0';
		downstream1_tx_req <= '0';
		wait until not (?? reset);
		wait until rising_edge(clk);
		downstream1_tx_req <= '1';
		wait until rising_edge(clk) and (?? downstream1_tx_start);
		downstream1_tx_req <= '0';
		downstream1_tx_valid <= '1';
		downstream1_tx_data <= x"0123456789abcdef";
		downstream1_tx_sop <= '1';
		downstream1_tx_eop <= '0';
		downstream1_tx_err <= '0';
		wait until rising_edge(clk);
		downstream1_tx_data <= x"123456789abcdef0";
		downstream1_tx_sop <= '0';
		downstream1_tx_eop <= '1';
		wait until rising_edge(clk);
		downstream1_tx_valid <= '0';
		downstream1_tx_data <= (others => 'U');
		downstream1_tx_sop <= 'U';
		downstream1_tx_eop <= 'U';
		downstream1_tx_err <= 'U';
		wait;
	end process;

	downstream2_tx_req <= '0';
	downstream2_cpl_pending <= '0';

	process is
	begin
		wait until ?? reset;
		downstream3_tx_valid <= '0';
		downstream3_cpl_pending <= '0';
		downstream3_tx_req <= '0';
		wait until not (?? reset);
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		downstream3_tx_req <= '1';
		wait until rising_edge(clk) and (?? downstream3_tx_start);
		downstream3_tx_req <= '0';
		downstream3_tx_valid <= '1';
		downstream3_tx_data <= x"0123456789abcdef";
		downstream3_tx_sop <= '1';
		downstream3_tx_eop <= '0';
		downstream3_tx_err <= '0';
		wait until rising_edge(clk);
		downstream3_tx_data <= x"123456789abcdef0";
		downstream3_tx_sop <= '0';
		downstream3_tx_eop <= '1';
		wait until rising_edge(clk);
		downstream3_tx_valid <= '0';
		downstream3_tx_data <= (others => 'U');
		downstream3_tx_sop <= 'U';
		downstream3_tx_eop <= 'U';
		downstream3_tx_err <= 'U';
		wait;
	end process;

	upstream_tx_ready <= not reset;

	dut : entity work.pcie_arbiter
		generic map(
			num_agents => 3
		)

		port map(
			reset_n => not reset,
			clk => clk,

			merged_tx_req => upstream_req_shortcut,
			merged_tx_start => upstream_req_shortcut,

			merged_tx_ready => upstream_tx_ready,
			merged_tx_valid => upstream_tx_valid,
			merged_tx_data => upstream_tx_data,
			merged_tx_sop => upstream_tx_sop,
			merged_tx_eop => upstream_tx_eop,
			merged_tx_err => upstream_tx_err,
			merged_cpl_pending => upstream_cpl_pending,

			arb_tx_req(1) => downstream1_tx_req,
			arb_tx_req(2) => downstream2_tx_req,
			arb_tx_req(3) => downstream3_tx_req,
			arb_tx_start(1) => downstream1_tx_start,
			arb_tx_start(2) => downstream2_tx_start,
			arb_tx_start(3) => downstream3_tx_start,
			arb_tx_ready(1) => downstream1_tx_ready,
			arb_tx_ready(2) => downstream2_tx_ready,
			arb_tx_ready(3) => downstream3_tx_ready,
			arb_tx_valid(1) => downstream1_tx_valid,
			arb_tx_valid(2) => downstream2_tx_valid,
			arb_tx_valid(3) => downstream3_tx_valid,
			arb_tx_data(1) => downstream1_tx_data,
			arb_tx_data(2) => downstream2_tx_data,
			arb_tx_data(3) => downstream3_tx_data,
			arb_tx_sop(1) => downstream1_tx_sop,
			arb_tx_sop(2) => downstream2_tx_sop,
			arb_tx_sop(3) => downstream3_tx_sop,
			arb_tx_eop(1) => downstream1_tx_eop,
			arb_tx_eop(2) => downstream2_tx_eop,
			arb_tx_eop(3) => downstream3_tx_eop,
			arb_tx_err(1) => downstream1_tx_err,
			arb_tx_err(2) => downstream2_tx_err,
			arb_tx_err(3) => downstream3_tx_err,
			arb_cpl_pending(1) => downstream1_cpl_pending,
			arb_cpl_pending(2) => downstream2_cpl_pending,
			arb_cpl_pending(3) => downstream3_cpl_pending
		);
end architecture;
