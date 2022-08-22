library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
use ieee.std_logic_misc.or_reduce;

use work.bss2k.ALL;

entity cpu_sequential is
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

architecture rtl of cpu_sequential is
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

	type state is (ifetch1, ifetch15, ifetch2, decode, decode2, execute, writeback, advance1, advance15, advance2, load, load2, store, store2, div, halt);

	signal s : state;

	signal r_address_a, r_address_b : reg := (others => '0');
	signal r_data_a, r_data_b : word;
	signal r_wren_a, r_wren_b : std_logic;
	signal r_q_a, r_q_b : word;

	type flags is record
		c : std_logic;
		z : std_logic;
	end record;
	signal f : flags;

	signal i_buffer : instruction;

	-- address for memory operation
	signal m_addr : address;
	-- register for memory load operation
	signal m_reg : reg;
	-- value for memory store operation
	signal m_value : word;

	-- whether writeback path is active
	signal wb_active1, wb_active2 : std_logic;
	-- register for writeback
	signal wb_reg1, wb_reg2 : reg;
	-- value for writeback
	signal wb_value1, wb_value2 : word;

	type reg_field is (
		none,	-- no operand used
		i_r1,	-- register number in insn, field 1
		i_r2,
		i_r3,
		i_r4,
		r_sp
	);
	type read_reg is record
		reg_a : reg_field;
		reg_b : reg_field;
	end record;

	type decoded_insn is record
		reg_read : read_reg;
	end record;

	signal decoder_input : instruction;
	signal decoder_output : decoded_insn;

	alias opcode : std_logic_vector(15 downto 0) is decoder_input(63 downto 48);
begin
	halted <= '1' when s = halt else '0';

	decoder_input <= i_rddata;

	with opcode select decoder_output.reg_read <=
		( none, none ) when x"0000",	-- MOVE immediate -> register
		( none, none ) when x"0001",	-- LOAD address -> register
		( i_r2, none ) when x"0002",	-- MOVE register -> register
		( i_r1, none ) when x"0003",	-- STORE register -> address
		( i_r2, none ) when x"0004",	-- LOAD [register] -> register
		( i_r1, i_r2 ) when x"0005",	-- STORE register -> [register]
		( none, none ) when x"0006",	-- HALT and catch fire
		( i_r2, i_r3 ) when x"0007",	-- ADD register, register -> register
		( i_r2, i_r3 ) when x"0008",	-- SUB register, register -> register
		( i_r2, i_r3 ) when x"0009",	-- SUB register, register, carry -> register
		( i_r3, i_r4 ) when x"000a",	-- MUL register, register -> (register, register)
		( i_r3, i_r4 ) when x"000b",	-- DIVMOD register, register -> register, register
		( i_r2, i_r3 ) when x"000c",	-- AND register, register -> register
		( i_r2, i_r3 ) when x"000d",	-- OR register, register -> register
		( i_r2, i_r3 ) when x"000e",	-- XOR register, register -> register
		( i_r2, none ) when x"000f",	-- NOT register -> register
		( i_r2, i_r3 ) when x"0010",	-- SHIFT LEFT register, register -> register
		( i_r2, i_r3 ) when x"0011",	-- SHIFT RIGHT register, register -> register
		( i_r2, none ) when x"0012",	-- ADD register, immediate -> register
		( i_r2, none ) when x"0013",	-- SUB register, immediate -> register
		( i_r2, i_r3 ) when x"0014",	-- CMP register, register -> register:ternary
		( r_sp, i_r1 ) when x"0015",	-- PUSH register => STORE register, [sp++]
		( r_sp, none ) when x"0016",	-- POP register => LOAD [--sp] -> register
		( r_sp, none ) when x"0017",	-- CALL address => PUSH ip + 8; JMP address
		( r_sp, none ) when x"0018",	-- RETURN => POP ip
		( none, none ) when x"0019",	-- JUMP address
		( i_r1, none ) when x"001a",	-- JUMP [register]
		( i_r1, none ) when x"001b",	-- JUMPif register:ternary == 0, address
		( i_r1, none ) when x"001c",	-- JUMPif register:ternary > 0, address
		( i_r1, none ) when x"001d",	-- JUMPif register:ternary >= 0, address
		( i_r1, none ) when x"001e",	-- JUMPif register:ternary < 0, address
		( i_r1, none ) when x"001f",	-- JUMPif register:ternary <= 0, address
		( none, none ) when x"0020",	-- JUMPeq address
		( none, none ) when x"0021",	-- JUMPne address
		( none, none ) when x"0022",	-- JUMPgt address
		( none, none ) when x"0023",	-- JUMPge address
		( none, none ) when x"0024",	-- JUMPlt address
		( none, none ) when x"0025",	-- JUMPle address
		( i_r2, i_r1 ) when x"0026",	-- JUMPif register:ternary == 0, [register]
		( i_r2, i_r1 ) when x"0027",	-- JUMPif register:ternary > 0, [register]
		( i_r2, i_r1 ) when x"0028",	-- JUMPif register:ternary >= 0, [register]
		( i_r2, i_r1 ) when x"0029",	-- JUMPif register:ternary < 0, [register]
		( i_r2, i_r1 ) when x"002a",	-- JUMPif register:ternary <= 0, [register]
		( i_r1, none ) when x"002b",	-- JUMPeq [register]
		( i_r1, none ) when x"002c",	-- JUMPne [register]
		( i_r1, none ) when x"002d",	-- JUMPgt [register]
		( i_r1, none ) when x"002e",	-- JUMPge [register]
		( i_r1, none ) when x"002f",	-- JUMPlt [register]
		( i_r1, none ) when x"0030",	-- JUMPle [register]
		( none, none ) when x"0031",	-- NOP
		( i_r2, none ) when x"0032",	-- GETKEYSTATE register -> register
		( none, none ) when x"0033",	-- POLLTIME -> (register, register)
		( i_r2, i_r3 ) when x"0034",	-- ADD register, register, carry -> register
		( none, none ) when x"0035",	-- SWAPFRAMEBUFFERS
		( i_r1, r_sp ) when x"0036",	-- CALL [register]
		( i_r1, r_sp ) when x"0037",	-- CALL [[register]]
		( none, none ) when x"0038",	-- INVISIBLEFRAMEBUFFERADDRESS -> register
		( none, none ) when x"0039",	-- POLLCYCLECOUNT -> (register, register)
		( i_r2, i_r3 ) when x"003a",	-- CMPeq register, register -> register:bool
		( i_r2, i_r3 ) when x"003b",	-- CMPne register, register -> register:bool
		( i_r2, i_r3 ) when x"003c",	-- CMPgt register, register -> register:bool
		( i_r2, i_r3 ) when x"003d",	-- CMPge register, register -> register:bool
		( i_r2, i_r3 ) when x"003e",	-- CMPlt register, register -> register:bool
		( i_r2, i_r3 ) when x"003f",	-- CMPle register, register -> register:bool
		( r_sp, none ) when x"0040",	-- POP <discard>,
		( none, none ) when x"fff8",	-- CHECKPOINT immediate
		( i_r1, none ) when x"fff9",	-- PRINTREGISTER
		( none, none ) when x"fffa",	-- DEBUGBREAK
		( i_r1, none ) when x"fffb",	-- ASSERT [register] == immediate
		( i_r1, none ) when x"fffc",	-- ASSERT register == immediate
		( i_r2, i_r1 ) when x"fffd",	-- ASSERT register == register
		( none, none ) when x"fffe",	-- DUMPMEMORY
		( none, none ) when x"ffff",	-- DUMPREGISTERS
		( none, none ) when others;

	process(reset, clk) is
		variable dividend : unsigned(31 downto 0);
		variable dividend_tmp : unsigned(63 downto 0);
		variable divisor : unsigned(63 downto 0);
		variable divider_counter : integer range 31 downto 0;
		variable quotient : unsigned(31 downto 0);
		variable remainder : unsigned(31 downto 0);
		variable quotient_reg : reg;
		variable remainder_reg : reg;

		procedure done is
		begin
			s <= advance1;
		end procedure;

		procedure writeback1(constant reg1 : in reg; constant value1 : in word) is
		begin
			wb_active1 <= '1';
			wb_reg1 <= reg1;
			wb_value1 <= value1;
		end procedure;

		procedure writeback2(constant reg2 : in reg; constant value2 : in word) is
		begin
			wb_active2 <= '1';
			wb_reg2 <= reg2;
			wb_value2 <= value2;
		end procedure;

		procedure divide_done is
		begin
			writeback1(quotient_reg, word(quotient));
			writeback2(remainder_reg, word(remainder));
			done;
		end procedure;

		procedure divide_step is
		begin
			divisor := divisor srl 1;
			if(dividend >= divisor) then
				quotient(divider_counter) := '1';
				dividend_tmp := dividend - divisor;
				dividend := dividend_tmp(dividend'range);
			else
				quotient(divider_counter) := '0';
			end if;
			if(divider_counter = 0) then
				remainder := dividend;
				divide_done;
			else
				divider_counter := divider_counter - 1;
			end if;
		end procedure;

		procedure divide_begin(constant n, d : in word; constant q_reg, r_reg : in reg) is
		begin
			dividend := unsigned(n);
			divisor := unsigned(d) & x"00000000";
			divider_counter := 31;
			quotient_reg := q_reg;
			remainder_reg := r_reg;
			s <= div;
			divide_step;
		end procedure;

		procedure decode_insn is
			-- instruction is on i_rddata in this cycle
			alias i : instruction is i_rddata;

			alias reg1 : reg is i(47 downto 40);
			alias reg2 : reg is i(39 downto 32);
			alias reg3 : reg is i(31 downto 24);
			alias reg4 : reg is i(23 downto 16);
			alias c : word is i(31 downto 0);
		begin
			case decoder_output.reg_read.reg_a is
				when none	=> null;
				when i_r1	=> r_address_a <= reg1;
				when i_r2	=> r_address_a <= reg2;
				when i_r3	=> r_address_a <= reg3;
				when i_r4	=> r_address_a <= reg4;
				when r_sp	=> r_address_a <= sp;
			end case;
			case decoder_output.reg_read.reg_b is
				when none	=> null;
				when i_r1	=> r_address_b <= reg1;
				when i_r2	=> r_address_b <= reg2;
				when i_r3	=> r_address_b <= reg3;
				when i_r4	=> r_address_b <= reg4;
				when r_sp	=> r_address_b <= sp;
			end case;
		end procedure;

		procedure execute_insn is
			-- instruction is on i_buffer in this cycle
			alias i : instruction is i_buffer;

			alias opcode : std_logic_vector(15 downto 0) is i(63 downto 48);
			alias reg1 : reg is i(47 downto 40);
			alias reg2 : reg is i(39 downto 32);
			alias reg3 : reg is i(31 downto 24);
			alias reg4 : reg is i(23 downto 16);
			alias c : word is i(31 downto 0);

			-- 32 bit wide temporary
			variable tmp32 : std_logic_vector(31 downto 0);

			-- 33 bit wide temporary
			variable tmp33 : std_logic_vector(32 downto 0);

			-- 64 bit wide temporary
			variable tmp64 : std_logic_vector(63 downto 0);
		begin
			-- defaults
			wb_active1 <= '0';
			wb_active2 <= '0';

			case opcode is
				when x"0000" =>
					-- LI
					writeback1(reg1, c);
					done;
				when x"0001" =>
					-- LD abs
					m_addr <= to_address(c);
					m_reg <= reg1;
					s <= load;
				when x"0002" =>
					-- MOV
					writeback1(reg1, r_q_a);
					done;
				when x"0003" =>
					-- ST abs
					m_addr <= to_address(c);
					m_value <= r_q_a;
					s <= store;
				when x"0004" =>
					-- LD [r]
					m_addr <= to_address(r_q_a);
					m_reg <= reg1;
					s <= load;
				when x"0005" =>
					-- ST [r]
					m_addr <= to_address(r_q_a);
					m_value <= r_q_b;
					s <= store;
				when x"0006" =>
					-- HCF
					s <= halt;
				when x"0007" =>
					-- ADD
					tmp33 := std_logic_vector(unsigned('0' & r_q_a) + unsigned('0' & r_q_b));
					writeback1(reg1, tmp33(31 downto 0));
					f.c <= tmp33(32);
					f.z <= not or_reduce(tmp33(31 downto 0));
					done;
				when x"0008" =>
					-- SUB
					tmp33 := std_logic_vector(unsigned('0' & r_q_a) - unsigned('0' & r_q_b));
					writeback1(reg1, tmp33(31 downto 0));
					f.c <= tmp33(32);
					f.z <= not or_reduce(tmp33(31 downto 0));
					done;
				when x"0009" =>
					-- SBC
					tmp33 := std_logic_vector(unsigned('0' & r_q_a) - unsigned('0' & r_q_b) - unsigned'("" & f.c));
					writeback1(reg1, tmp33(31 downto 0));
					f.c <= tmp33(32);
					f.z <= not or_reduce(tmp33(31 downto 0));
					done;
				when x"000a" =>
					-- MUL
					tmp64 := std_logic_vector(unsigned(r_q_a) * unsigned(r_q_b));
					writeback1(reg1, tmp64(63 downto 32));
					writeback2(reg2, tmp64(31 downto 0));
					f.c <= '0';
					f.z <= not or_reduce(tmp64);
					done;
				when x"000b" =>
					-- DIVMOD
					divide_begin(r_q_a, r_q_b, reg1, reg2);
				when x"000c" =>
					-- AND
					tmp32 := r_q_a and r_q_b;
					writeback1(reg1, tmp32);
					f.c <= '0';
					f.z <= not or_reduce(tmp32);
					done;
				when x"000d" =>
					-- OR
					tmp32 := r_q_a or r_q_b;
					writeback1(reg1, tmp32);
					f.c <= '0';
					f.z <= not or_reduce(tmp32);
					done;
				when x"000e" =>
					-- XOR
					tmp32 := r_q_a xor r_q_b;
					writeback1(reg1, tmp32);
					f.c <= '0';
					f.z <= not or_reduce(tmp32);
					done;
				when x"000f" =>
					-- NOT
					tmp32 := not r_q_a;
					writeback1(reg1, tmp32);
					f.c <= '0';
					f.z <= not or_reduce(tmp32);
					done;
				when x"0010" =>
					-- SHL
					tmp33 := std_logic_vector(unsigned('0' & r_q_a) sll to_integer(unsigned(r_q_b)));
					writeback1(reg1, tmp33(31 downto 0));
					f.c <= tmp33(32);
					f.z <= not or_reduce(tmp33(31 downto 0));
					done;
				when x"0011" =>
					-- SHR
					tmp33 := std_logic_vector(unsigned(r_q_a & '0') srl to_integer(unsigned(r_q_b)));
					writeback1(reg1, tmp33(32 downto 1));
					f.c <= tmp33(0);
					f.z <= not or_reduce(tmp33(32 downto 1));
					done;
				when x"0012" =>
					-- ADDI
					tmp33 := std_logic_vector(unsigned('0' & r_q_a) + unsigned('0' & c));
					writeback1(reg1, tmp33(31 downto 0));
					f.c <= tmp33(32);
					f.z <= not or_reduce(tmp33(31 downto 0));
					done;
				when x"0013" =>
					-- SUBI
					tmp33 := std_logic_vector(unsigned('0' & r_q_a) - unsigned('0' & c));
					writeback1(reg1, tmp33(31 downto 0));
					f.c <= tmp33(32);
					f.z <= not or_reduce(tmp33(31 downto 0));
					done;
				when x"0014" =>
					-- CMP
					if(r_q_a = r_q_b) then
						writeback1(reg1, x"00000000");
						f.c <= '0';
						f.z <= '1';
					elsif(unsigned(r_q_a) > unsigned(r_q_b)) then
						writeback1(reg1, x"00000001");
						f.c <= '0';
						f.z <= '0';
					else
						writeback1(reg1, x"ffffffff");
						f.c <= '1';
						f.z <= '0';
					end if;
					done;
				when x"0015" =>
					-- PUSH
					tmp32 := std_logic_vector(unsigned(r_q_a) - 4);
					writeback1(sp, tmp32);
					m_addr <= to_address(r_q_a);
					m_value <= r_q_b;
					s <= store;
				when x"0016" =>
					-- POP
					tmp32 := std_logic_vector(unsigned(r_q_a) + 4);
					writeback2(sp, tmp32);
					m_addr <= to_address(tmp32);
					m_reg <= reg1;
					s <= load;
				when x"0017" =>
					-- CALL
					tmp32 := std_logic_vector(unsigned(r_q_a) - 4);
					writeback1(sp, tmp32);
					tmp32 := std_logic_vector(unsigned(r_q_b) + 8);
					writeback2(ip, c);
					m_addr <= to_address(r_q_a);
					m_value <= tmp32;
					s <= store;
				when x"0018" =>
					-- RET
					tmp32 := std_logic_vector(unsigned(r_q_a) + 4);
					writeback2(sp, tmp32);
					m_addr <= to_address(tmp32);
					m_reg <= ip;
					s <= load;
				when others =>
					report "invalid opcode encountered" severity error;
					s <= halt;
			end case;
		end procedure;
	begin
		if(reset = '1') then
			s <= writeback;
			wb_active1 <= '1';
			wb_reg1 <= ip;
			wb_value1 <= to_word(entry_point);
			wb_active2 <= '1';
			wb_reg2 <= sp;
			wb_value2 <= to_word(stack_start);
			i_rdreq <= '0';
			d_rdreq <= '0';
			d_wrreq <= '0';
			r_address_a <= (others => '0');
			r_address_b <= (others => '0');
			r_wren_a <= '0';
			r_wren_b <= '0';
		elsif(rising_edge(clk)) then
			i_rdreq <= '0';
			d_rdreq <= '0';
			d_wrreq <= '0';
			r_wren_a <= '0';
			r_wren_b <= '0';
			case s is
				when ifetch1 =>
					r_address_a <= ip;
					s <= ifetch15;
				when ifetch15 =>
					s <= ifetch2;
				when ifetch2 =>
					i_addr <= to_address(r_q_a);
					i_rdreq <= '1';
					s <= decode;
				when decode =>
					if(i_waitrequest = '0') then
						i_buffer <= i_rddata;
						-- defined above because long
						decode_insn;
						s <= decode2;
					else
						i_addr <= to_address(r_q_a);
						i_rdreq <= '1';
					end if;
				when decode2 =>
					s <= execute;
				when execute =>
					-- defined above because long
					execute_insn;
				when advance1 =>
					r_address_a <= ip;
					s <= advance15;
				when advance15 =>
					s <= advance2;
				when advance2 =>
					r_address_a <= ip;
					r_wren_a <= '1';
					-- increment by eight, because instructions are 64 bit
					r_data_a <= word(unsigned(r_q_a) + 8);
					s <= writeback;
				when writeback =>
					if(wb_active1 = '1') then
						r_address_a <= wb_reg1;
						r_wren_a <= '1';
						r_data_a <= wb_value1;
					end if;
					if(wb_active2 = '1') then
						r_address_b <= wb_reg2;
						r_wren_b <= '1';
						r_data_b <= wb_value2;
					end if;
					s <= ifetch1;
					wb_active1 <= '0';
					wb_active2 <= '0';
				when load =>
					d_addr <= m_addr;
					d_rdreq <= '1';
					if(d_waitrequest = '0') then
						s <= load2;
					end if;
				when load2 =>
					if(d_waitrequest = '0') then
						writeback1(m_reg, d_rddata);
						done;
					end if;
				when store =>
					d_addr <= m_addr;
					d_wrdata <= m_value;
					d_wrreq <= '1';
					if(d_waitrequest = '0') then
						s <= store2;
					end if;
				when store2 =>
					if(d_waitrequest = '0') then
						done;
					end if;
				when div =>
					divide_step;
				when halt =>
					null;
			end case;
		end if;
	end process;

	register_file : registers
		port map(
			address_a => r_address_a,
			address_b => r_address_b,
			clock => clk,
			data_a => r_data_a,
			data_b => r_data_b,
			wren_a => r_wren_a,
			wren_b => r_wren_b,
			q_a => r_q_a,
			q_b => r_q_b
		);
end architecture;
