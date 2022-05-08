library ieee;
use ieee.std_logic_1164.ALL;

entity top is
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
end entity;

architecture rtl of top is
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

	c : cpu
		generic map(
			address_width => 32
		)
		port map(
			reset => reset,
			clk => clk,
			i_addr => i_addr,
			i_rddata => i_rddata,
			i_rdreq => i_rdreq,
			i_waitrequest => i_waitrequest,
			d_addr => d_addr,
			d_rddata => d_rddata,
			d_rdreq => d_rdreq,
			d_wrdata => d_wrdata,
			d_wrreq => d_wrreq,
			d_waitrequest => d_waitrequest
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
