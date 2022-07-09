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

	-- decode to fetch interface
	signal fetch_stop : std_logic;
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
				if(not (?? i_waitrequest) and not (?? fetch_stop)) then
					ip_reg <= address(unsigned(ip_reg) + 8);
				end if;
			end if;
		end process;

		fetch_insn_valid <= i_rdreq_int and not i_waitrequest;
		fetch_insn <= i_rddata;
	end block;

	decode : block is
		-- opcodes are 16 bit
		subtype opcode is std_logic_vector(15 downto 0);

		-- opcodes are in bits 63..48 of the instruction
		alias op : opcode is fetch_insn(63 downto 48);

		-- suboperation for flow logic
		type jmp_op is (nop, halt);

		type decoded is record
			jmp : jmp_op;
		end record;

		-- decoded instruction
		signal d_valid : std_logic;
		signal d : decoded;

		-- should_* signals are valid only if d_valid is set

		-- currently decoded instruction should set the "halted" signal
		signal should_halt : std_logic;

		-- currently decoded instruction should stop fetch block
		signal should_stop : std_logic;
	begin
		d_valid <= fetch_insn_valid;

		-- decode table
		with op select d.jmp <=
		-- jmp
		( halt ) when x"0006",
		( nop ) when others;

		-- generation of "halted" signal
		with d.jmp select should_halt <=
			'0' when nop,
			'1' when halt;
		halted <= '0' when ?? reset else
				  should_halt when ?? d_valid else
				  unaffected;

		-- stop the fetcher if the next instruction should not be
		-- executed
		with d.jmp select should_stop <=
			'0' when nop,
			'1' when halt;
		fetch_stop <= '0' when ?? reset else
					  should_stop when ?? d_valid else
					  unaffected;
	end block;

	d_addr <= (others => '0');
	d_rdreq <= '0';
	d_wrreq <= '0';

	r(1).address <= (others => '0');
	r(1).wren <= '0';
	r(1).data <= (others => '0');
	r(2).address <= (others => '0');
	r(2).wren <= '0';
	r(2).data <= (others => '0');

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
