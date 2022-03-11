library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
use ieee.std_logic_misc.or_reduce;

entity cpu is
	generic(
		address_width : integer range 1 to 32 := 32
	);
	port(
		-- async reset
		reset : in std_logic;

		-- clock
		clk : in std_logic;

		-- instruction bus (Avalon-MM)
		i_addr : out std_logic_vector(address_width - 1 downto 0);
		i_rddata : in std_logic_vector(63 downto 0);
		i_rdreq : out std_logic;
		i_waitrequest : in std_logic;

		-- data bus (Avalon-MM)
		d_addr : out std_logic_vector(address_width - 1 downto 0);
		d_rddata : in std_logic_vector(31 downto 0);
		d_rdreq : out std_logic;
		d_wrdata : out std_logic_vector(31 downto 0);
		d_wrreq : out std_logic;
		d_waitrequest : in std_logic;

		-- status
		halted : out std_logic
	);
end entity;

architecture sequential of cpu is
	subtype address is std_logic_vector(address_width - 1 downto 0);

	subtype word is std_logic_vector(31 downto 0);

	type state is (ifetch1, ifetch2, decode, execute, writeback, advance1, advance2, load, load2, store, store2, halt);

	signal s : state;

	subtype reg is std_logic_vector(7 downto 0);
	constant sp : reg := x"fe";
	constant ip : reg := x"ff";

	function to_index(rn : in std_logic_vector(7 downto 0)) return reg is
	begin
		return rn;
	end function;

	type reg_file is array(0 to 255) of word;

	signal r : reg_file;

	signal r_address_a, r_address_b : reg;
	signal r_data_a, r_data_b : word;
	signal r_wren_a, r_wren_b : std_logic;
	signal r_q_a, r_q_b : word;

	type flags is record
		c : std_logic;
		z : std_logic;
	end record;
	signal f : flags;

	constant reset_ip : address := x"00000000";

	subtype insn is std_logic_vector(63 downto 0);

	signal i_buffer : insn;

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
begin
	halted <= '1' when s = halt else '0';

	process(reset, clk) is
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

		procedure decode_insn is
			-- instruction is on i_rddata in this cycle
			alias i : insn is i_rddata;

			alias opcode : std_logic_vector(15 downto 0) is i(63 downto 48);
			alias reg1 : std_logic_vector(7 downto 0) is i(47 downto 40);
			alias reg2 : std_logic_vector(7 downto 0) is i(39 downto 32);
			alias reg3 : std_logic_vector(7 downto 0) is i(31 downto 24);
			alias reg4 : std_logic_vector(7 downto 0) is i(23 downto 16);
			alias c : std_logic_vector(31 downto 0) is i(31 downto 0);

			variable r1, r2, r3, r4 : reg;
		begin
			r1 := to_index(reg1);
			r2 := to_index(reg2);
			r3 := to_index(reg3);
			r4 := to_index(reg4);

			-- map register slots in opcode to register file accesses
			case opcode is
				when x"0000" =>
					-- LI
					null;
				when x"0001" =>
					-- LD abs
					null;
				when x"0002" =>
					-- MOV
					r_address_a <= r2;
				when x"0003" =>
					-- ST abs
					r_address_a <= r1;
				when x"0004" =>
					-- LD [r]
					r_address_a <= r2;
				when x"0005" =>
					-- ST [r]
					r_address_a <= r1;
					r_address_b <= r2;
				when x"0006" =>
					-- HCF
					null;
				when x"0007" =>
					-- ADD
					r_address_a <= r2;
					r_address_b <= r3;
				when x"0008" =>
					-- SUB
					r_address_a <= r2;
					r_address_b <= r3;
				when x"0009" =>
					-- SBC
					r_address_a <= r2;
					r_address_b <= r3;
				when x"000a" =>
					-- MUL
					r_address_a <= r3;
					r_address_b <= r4;
				when x"000b" =>
					-- DIVMOD
					r_address_a <= r3;
					r_address_b <= r4;
				when x"000c" =>
					-- AND
					r_address_a <= r2;
					r_address_b <= r3;
				when x"000d" =>
					-- OR
					r_address_a <= r2;
					r_address_b <= r3;
				when x"000e" =>
					-- XOR
					r_address_a <= r2;
					r_address_b <= r3;
				when x"000f" =>
					-- NOT
					r_address_a <= r2;
				when x"0010" =>
					-- SHL
					r_address_a <= r2;
					r_address_b <= r3;
				when x"0011" =>
					-- SHR
					r_address_a <= r2;
					r_address_b <= r3;
				when x"0012" =>
					-- ADDI
					r_address_a <= r2;
				when x"0013" =>
					-- SUBI
					r_address_a <= r2;
				when x"0014" =>
					-- CMP
					r_address_a <= r2;
					r_address_b <= r3;
				when others =>
					report "invalid opcode encountered" severity error;
			end case;
		end procedure;

		procedure execute_insn is
			-- instruction is on i_buffer in this cycle
			alias i : insn is i_buffer;

			alias opcode : std_logic_vector(15 downto 0) is i(63 downto 48);
			alias reg1 : std_logic_vector(7 downto 0) is i(47 downto 40);
			alias reg2 : std_logic_vector(7 downto 0) is i(39 downto 32);
			alias reg3 : std_logic_vector(7 downto 0) is i(31 downto 24);
			alias reg4 : std_logic_vector(7 downto 0) is i(23 downto 16);
			alias c : std_logic_vector(31 downto 0) is i(31 downto 0);

			variable r1, r2, r3, r4 : reg;

			-- 32 bit wide temporary
			variable tmp32 : std_logic_vector(31 downto 0);

			-- 33 bit wide temporary
			variable tmp33 : std_logic_vector(32 downto 0);

			-- 64 bit wide temporary
			variable tmp64 : std_logic_vector(63 downto 0);
		begin
			r1 := to_index(reg1);
			r2 := to_index(reg2);
			r3 := to_index(reg3);
			r4 := to_index(reg4);

			-- defaults
			wb_active1 <= '0';
			wb_active2 <= '0';

			case opcode is
				when x"0000" =>
					-- LI
					writeback1(r1, c);
					done;
				when x"0001" =>
					-- LD abs
					m_addr <= c;
					m_reg <= r1;
					s <= load;
				when x"0002" =>
					-- MOV
					writeback1(r1, r_q_a);
					done;
				when x"0003" =>
					-- ST abs
					m_addr <= c;
					m_value <= r_q_a;
					s <= store;
				when x"0004" =>
					-- LD [r]
					m_addr <= r_q_a;
					m_reg <= r1;
					s <= load;
				when x"0005" =>
					-- ST [r]
					m_addr <= r_q_a;
					m_value <= r_q_b;
					s <= store;
				when x"0006" =>
					-- HCF
					s <= halt;
				when x"0007" =>
					-- ADD
					tmp33 := std_logic_vector(unsigned('0' & r_q_a) + unsigned('0' & r_q_b));
					writeback1(r1, tmp33(31 downto 0));
					f.c <= tmp33(32);
					f.z <= not or_reduce(tmp33(31 downto 0));
					done;
				when x"0008" =>
					-- SUB
					tmp33 := std_logic_vector(unsigned('0' & r_q_a) - unsigned('0' & r_q_b));
					writeback1(r1, tmp33(31 downto 0));
					f.c <= tmp33(32);
					f.z <= not or_reduce(tmp33(31 downto 0));
					done;
				when x"0009" =>
					-- SBC
					tmp33 := std_logic_vector(unsigned('0' & r_q_a) - unsigned('0' & r_q_b) - unsigned'("" & f.c));
					writeback1(r1, tmp33(31 downto 0));
					f.c <= tmp33(32);
					f.z <= not or_reduce(tmp33(31 downto 0));
					done;
				when x"000a" =>
					-- MUL
					tmp64 := std_logic_vector(unsigned(r_q_a) * unsigned(r_q_b));
					writeback1(r1, tmp64(63 downto 32));
					writeback2(r2, tmp64(31 downto 0));
					f.c <= '0';
					f.z <= not or_reduce(tmp64);
					done;
				when x"000b" =>
					-- DIVMOD
					tmp32 := std_logic_vector(unsigned(r_q_a) / unsigned(r_q_b));
					writeback1(r1, tmp32);
					f.c <= not or_reduce(r_q_b);
					f.z <= not or_reduce(tmp32);
					tmp32 := std_logic_vector(unsigned(r_q_a) mod unsigned(r_q_b));
					writeback2(r2, tmp32);
					done;
				when x"000c" =>
					-- AND
					tmp32 := r_q_a and r_q_b;
					writeback1(r1, tmp32);
					f.c <= '0';
					f.z <= not or_reduce(tmp32);
					done;
				when x"000d" =>
					-- OR
					tmp32 := r_q_a or r_q_b;
					writeback1(r1, tmp32);
					f.c <= '0';
					f.z <= not or_reduce(tmp32);
					done;
				when x"000e" =>
					-- XOR
					tmp32 := r_q_a xor r_q_b;
					writeback1(r1, tmp32);
					f.c <= '0';
					f.z <= not or_reduce(tmp32);
					done;
				when x"000f" =>
					-- NOT
					tmp32 := not r_q_a;
					writeback1(r1, tmp32);
					f.c <= '0';
					f.z <= not or_reduce(tmp32);
					done;
				when x"0010" =>
					-- SHL
					tmp33 := std_logic_vector(unsigned('0' & r_q_a) sll to_integer(unsigned(r_q_b)));
					writeback1(r1, tmp33(31 downto 0));
					f.c <= tmp33(32);
					f.z <= not or_reduce(tmp33(31 downto 0));
					done;
				when x"0011" =>
					-- SHR
					tmp33 := std_logic_vector(unsigned(r_q_a & '0') srl to_integer(unsigned(r_q_b)));
					writeback1(r1, tmp33(32 downto 1));
					f.c <= tmp33(0);
					f.z <= not or_reduce(tmp33(32 downto 1));
					done;
				when x"0012" =>
					-- ADDI
					tmp33 := std_logic_vector(unsigned('0' & r_q_a) + unsigned('0' & c));
					writeback1(r1, tmp33(31 downto 0));
					f.c <= tmp33(32);
					f.z <= not or_reduce(tmp33(31 downto 0));
					done;
				when x"0013" =>
					-- SUBI
					tmp33 := std_logic_vector(unsigned('0' & r_q_a) - unsigned('0' & c));
					writeback1(r1, tmp33(31 downto 0));
					f.c <= tmp33(32);
					f.z <= not or_reduce(tmp33(31 downto 0));
					done;
				when x"0014" =>
					-- CMP
					if(r_q_a = r_q_b) then
						writeback1(r1, x"00000000");
						f.c <= '0';
						f.z <= '1';
					elsif(unsigned(r_q_a) > unsigned(r_q_b)) then
						writeback1(r1, x"00000001");
						f.c <= '0';
						f.z <= '0';
					else
						writeback1(r1, x"ffffffff");
						f.c <= '1';
						f.z <= '0';
					end if;
					done;
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
			wb_value1 <= reset_ip;
			wb_active2 <= '0';
			i_rdreq <= '0';
			d_rdreq <= '0';
			d_wrreq <= '0';
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
					s <= ifetch2;
				when ifetch2 =>
					i_addr <= r_q_a;
					i_rdreq <= '1';
					if(i_waitrequest = '0') then
						s <= decode;
					end if;
				when decode =>
					if(i_waitrequest = '0') then
						i_buffer <= i_rddata;
						-- defined above because long
						decode_insn;
					end if;
					s <= execute;
				when execute =>
					-- defined above because long
					execute_insn;
				when advance1 =>
					r_address_a <= ip;
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
						wb_reg1 <= wb_reg2;
						wb_value1 <= wb_value2;
					else
						wb_active1 <= '0';
						s <= ifetch1;
					end if;
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
				when halt =>
					null;
			end case;
		end if;
	end process;

	r_q_a <= r(to_integer(unsigned(r_address_a)));
	r_q_b <= r(to_integer(unsigned(r_address_b)));

	process(clk) is
	begin
		if(rising_edge(clk)) then
			if(r_wren_a = '1') then
				r(to_integer(unsigned(r_address_a))) <= r_data_a;
			end if;
			if(r_wren_b = '1') then
				r(to_integer(unsigned(r_address_b))) <= r_data_b;
			end if;
		end if;
	end process;
end architecture;
