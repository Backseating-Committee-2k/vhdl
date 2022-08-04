library ieee;
use ieee.std_logic_1164.ALL;

library std;
use std.env.finish;

entity tb_timing_start_cpu is
end entity;

architecture sim of tb_timing_start_cpu is
	component top is
		port(
			pcie_nperst : in std_logic;
			refclk : in std_logic;
			pcie_rx : in std_logic_vector(3 downto 0);
			pcie_tx : out std_logic_vector(3 downto 0);
			fixedclk_serdes : in std_logic;
			debug_clk : out std_logic;
			debug_data : out std_logic_vector(7 downto 0)
		);
	end component;

	signal pcie_nperst : std_logic;
	signal refclk : std_logic := '0';
	signal fixedclk_serdes : std_logic := '0';
begin
	-- sim timeout
	process is
	begin
		wait for 10 us;
		finish;
	end process;

	-- 100 MHz
	refclk <= not refclk after 5 ns;

	-- 125 MHz
	fixedclk_serdes <= not fixedclk_serdes after 4 ns;

	-- power-on reset
	pcie_nperst <= '0', '1' after 10 ns;

	board_inst : top
		port map(
			pcie_nperst => pcie_nperst,
			refclk => refclk,
			pcie_rx => (others => '0'),
			pcie_tx => open,
			fixedclk_serdes => fixedclk_serdes,
			debug_clk => open,
			debug_data => open
		);

-- 	stimuli : block is
-- 		alias pcie_rx_ready is << signal .tb_timing_start_cpu.board_inst.pcie_rx_ready : std_logic >>;
-- 	begin
-- 		process(pcie_rx_ready) is
-- 		begin
-- 			report std_logic'image(pcie_rx_ready);
-- 		end process;
-- 	end block;
end architecture;
