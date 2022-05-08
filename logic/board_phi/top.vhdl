library ieee;
use ieee.std_logic_1164.ALL;

entity top is
	port(
		dummy : in std_logic
	);
end entity;

architecture rtl of top is
	-- async reset
	signal cpu_reset : std_logic;

	-- clock
	signal cpu_clk : std_logic;

	-- instruction bus (Avalon-MM)
	signal cpu_i_addr : std_logic_vector(31 downto 0);
	signal cpu_i_rddata : std_logic_vector(63 downto 0);
	signal cpu_i_rdreq : std_logic;
	signal cpu_i_waitrequest : std_logic;

	-- data bus (Avalon-MM)
	signal cpu_d_addr : std_logic_vector(31 downto 0);
	signal cpu_d_rddata : std_logic_vector(31 downto 0);
	signal cpu_d_rdreq : std_logic;
	signal cpu_d_wrdata : std_logic_vector(31 downto 0);
	signal cpu_d_wrreq : std_logic;
	signal cpu_d_waitrequest : std_logic;

	component cpu is
		generic(
			address_width : integer
		);
		port(
			-- async reset
			reset : in std_logic;

			-- clock
			clk : in std_logic;

			-- instruction bus (Avalon-MM)
			i_addr : out std_logic_vector(31 downto 0);
			i_rddata : in std_logic_vector(63 downto 0);
			i_rdreq : out std_logic;
			i_waitrequest : in std_logic;

			-- data bus (Avalon-MM)
			d_addr : out std_logic_vector(31 downto 0);
			d_rddata : in std_logic_vector(31 downto 0);
			d_rdreq : out std_logic;
			d_wrdata : out std_logic_vector(31 downto 0);
			d_wrreq : out std_logic;
			d_waitrequest : in std_logic
		);
	end component;
begin
	cpu_reset <= '1';
	cpu_clk <= '0';

	cpu_i_rddata <= (others => '0');
	cpu_i_waitrequest <= '1';

	cpu_d_rddata <= (others => '0');
	cpu_d_waitrequest <= '1';

	c : cpu
		generic map(
			address_width => 32
		)
		port map(
			reset => cpu_reset,
			clk => cpu_clk,
			i_addr => cpu_i_addr,
			i_rddata => cpu_i_rddata,
			i_rdreq => cpu_i_rdreq,
			i_waitrequest => cpu_i_waitrequest,
			d_addr => cpu_d_addr,
			d_rddata => cpu_d_rddata,
			d_rdreq => cpu_d_rdreq,
			d_wrdata => cpu_d_wrdata,
			d_wrreq => cpu_d_wrreq,
			d_waitrequest => cpu_d_waitrequest
		);
end architecture;

library work;
use work.ALL;

configuration rtl of top is
	for rtl
		for c : cpu
			use entity work.cpu_sequential;
			for rtl
				for register_file : registers
					use entity work.altera_registers;
				end for;
			end for;
		end for;
	end for;
end configuration;
