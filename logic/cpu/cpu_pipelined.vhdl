library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

use work.bss2k.ALL;

entity cpu_pipelined is
	port(
		-- async reset
		reset : in std_logic;

		-- clock
		clk : in std_logic;

		-- instruction bus (Avalon-MM)
		i_addr : out address;
		i_rddata : in instruction;
		i_rdreq : out std_logic;
		i_waitrequest : in std_logic;

		-- data bus (Avalon-MM)
		d_addr : out address;
		d_rddata : in word;
		d_rdreq : out std_logic;
		d_wrdata : out word;
		d_wrreq : out std_logic;
		d_waitrequest : in std_logic;

		-- status
		halted : out std_logic
	);
end entity;

architecture rtl of cpu_pipelined is
	component registers is
		port
		(
			address_a : in reg;
			address_b : in reg;
			clock : in std_logic;
			data_a : in word;
			data_b : in word;
			wren_a : in std_logic;
			wren_b : in std_logic;
			q_a : out word;
			q_b : out word
		);
	end component;

	constant ip : reg := x"fe";
	constant sp : reg := x"ff";

	subtype reg_port is integer range 1 to 2;

	type reg_port_interface is record
		address : reg;
		data : word;
		wren : std_logic;
		q : word;
	end record;

	type reg_ports is array(reg_port) of reg_port_interface;

	signal r : reg_ports;

	signal i_rdreq_int : std_logic;

	-- fetch to decode interface
	signal fetch_insn_valid : std_logic;
	signal fetch_insn : instruction;
begin
	i_rdreq <= i_rdreq_int;

	fetch : block is
		-- this is the actual IP register. Register 254 is an alias, and
		-- needs special handling in the writeback code
		signal ip_reg : address;
	begin
		process(reset, clk) is
		begin
			if(?? reset) then
				ip_reg <= entry_point;
				i_addr <= (others => 'U');
				i_rdreq_int <= '0';
			elsif(rising_edge(clk)) then
				i_addr <= ip_reg;
				i_rdreq_int <= '1';
				if(not (?? i_waitrequest)) then
					ip_reg <= address(unsigned(ip_reg) + 8);
				end if;
			end if;
		end process;

		fetch_insn_valid <= i_rdreq_int and not i_waitrequest;
		fetch_insn <= i_rddata;
	end block;

	register_file : registers
		port map(
			address_a => r(1).address,
			address_b => r(2).address,
			clock => clk,
			data_a => r(1).data,
			data_b => r(2).data,
			wren_a => r(1).wren,
			wren_b => r(2).wren,
			q_a => r(1).q,
			q_b => r(2).q
		);
end architecture;
