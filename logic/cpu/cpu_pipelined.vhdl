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

	subtype lane is integer range 1 to 2;

	-- flow control
	signal decode_ready : std_logic;
	signal op_ready : std_logic;

	-- fetch to decode interface
	signal fetch_insn : instruction;

	-- fetch to operand interface
	signal fetch_ip : word;

	-- value from lane 2 should be stored to address on lane 1
	type store_info is record
		active : std_logic;
	end record;

	-- decode to operands interface
	type source_sel is (
		none,				-- lane inactive
		from_register,		-- get register contents
		from_value,			-- take over immediate value
		from_ip				-- get IP from fetch block
	);

	type source is record
		sel : source_sel;
		reg : reg;
		value : word;
	end record;

	type source_per_lane is array(lane) of source;

	type destination is record
		active : std_logic;
		reg : reg;
	end record;
	type destination_per_lane is array(lane) of destination;
	type writeback_info is record
		lanes : destination_per_lane;
	end record;

	type decode_out is record
		src : source_per_lane;
		writeback : writeback_info;
		store : store_info;
	end record;

	signal decode_to_op : decode_out;

	-- operands to store and ALU
	type operand is record
		valid : std_logic;
		ready : std_logic;
		value : word;
	end record;

	type operand_per_lane is array(lane) of operand;

	type op_out is record
		lanes : operand_per_lane;
		writeback : writeback_info;
		store : store_info;
	end record;

	signal op_to_store_writeback : op_out;

	subtype reg_read_port is integer range 1 to 2;

	type reg_read_addr_per_port is array(reg_read_port) of reg;
	type reg_read_rddata_per_port is array(reg_read_port) of word;

	-- Avalon-MM-like port for register read accesses
	signal reg_read_addr : reg_read_addr_per_port;
	signal reg_read_rdreq : std_logic_vector(reg_read_port);
	signal reg_read_rddata : reg_read_rddata_per_port;
	signal reg_read_waitrequest : std_logic_vector(reg_read_port);

	subtype reg_write_port is integer range 1 to 2;

	type reg_write_addr_per_port is array(reg_write_port) of reg;
	type reg_write_wrdata_per_port is array(reg_write_port) of word;

	-- Avalon-MM-like port for register write accesses
	signal reg_write_addr : reg_write_addr_per_port;
	signal reg_write_wrreq : std_logic_vector(reg_write_port);
	signal reg_write_wrdata : reg_write_wrdata_per_port;
	signal reg_write_waitrequest : std_logic_vector(reg_write_port);

begin
	fetch : block is
		-- this is the actual IP register. Register 254 is an alias, and
		-- needs special handling in the writeback code
		signal ip_reg : address;

		signal i_rdreq_int : std_logic;

		signal ready : std_logic;

		signal valid : std_logic;
	begin
		i_rdreq <= i_rdreq_int;

		ready <= decode_ready and op_ready;

		process(reset, clk) is
		begin
			if(?? reset) then
				ip_reg <= entry_point;
				i_addr <= (others => 'U');
				i_rdreq_int <= '0';
			elsif(rising_edge(clk)) then
				i_addr <= ip_reg;
				i_rdreq_int <= ready;
				if(not (?? i_waitrequest) and (?? ready)) then
					ip_reg <= address(unsigned(ip_reg) + 8);
				end if;
			end if;
		end process;

		valid <= i_rdreq_int and not i_waitrequest;
		fetch_insn <=
			i_rddata when ?? valid else
			(x"0031000000000000");				-- NOP

		-- stuff unused bits with zeros
		fetch_ip(word'high downto address'high + 1) <= (others => '0');
		fetch_ip(address'range) <= ip_reg;
	end block;

	decode : block is
		-- opcodes are 16 bit
		subtype opcode is std_logic_vector(15 downto 0);

		-- opcodes are in bits 63..48 of the instruction
		alias op : opcode is fetch_insn(63 downto 48);

		-- register fields in the instruction
		alias reg1 : reg is fetch_insn(47 downto 40);
		alias reg2 : reg is fetch_insn(39 downto 32);
		alias reg3 : reg is fetch_insn(31 downto 24);
		alias reg4 : reg is fetch_insn(23 downto 16);

		-- immediate field in the instruction
		alias immed : word is fetch_insn(31 downto 0);

		-- suboperation for flow logic
		type jmp_op is (
			nop,	-- no jump
			halt,	-- halt CPU
			call,	-- store return and jump
			jump,	-- unconditional jump
			jeq,	-- jump if equal
			jne,	-- jump if not equal
			jgt,	-- jump if greater than
			jlt,	-- jump if less than
			jge,	-- jump if greater or equal
			jle,	-- jump if less or equal
			jz,		-- jump if zero flag set
			jnz,	-- jump if zero flag clear
			jcs,	-- jump if carry flag set
			jcc,	-- jump if carry flag clear
			jd0,	-- jump if division by zero flag set
			jnd0	-- jump if division by zero flag clear
		);

		-- operand source field
		type source is (none, r1, r2, r3, r4, sp, ip, imm);

		-- operand destination field
		subtype destination is source range none to ip;

		-- each lane has a source
		type source_per_lane is array(lane) of source;
		-- each lane can be sent to a destination
		type destination_per_lane is array(lane) of destination;

		-- suboperation for store logic
		-- stores branch off before ALU
		type store_op is (
			-- don't store anything
			nop,
			-- store value from lane 2 to address on lane 1
			l2,
			-- store instruction pointer to address on lane 1
			ip
		);

		-- suboperation for load logic
		type load_op is (nop, load);

		-- suboperation for ALU
		type alu_op is (
			nop,	-- passthrough
			add,	-- L1 = L1 + L2
			adc,	-- L1 = L1 + L2 + C
			sub,	-- L1 = L1 - L2
			sbc,	-- L1 = L1 - L2 - C
			mul,	-- L1 = Hi( L1 * L2 ); L2 = Lo( L1 * L2 )
			divmod,	-- L1 = L1 / L2; L2 = L1 mod L2
			bitand,	-- L1 = L1 and L2
			bitor,	-- L1 = L1 or L2
			bitxor,	-- L1 = L1 xor L2
			bitnot,	-- L1 = not L1
			shl,	-- L1 = L1 << L2
			shr,	-- L1 = L1 >> L2
			cmp		-- L1 = (L1 == L2) ? 0 : (L1 < L2) ? 0xffffffff : 1
			);

		type decoded is record
			jmp : jmp_op;
			src : source_per_lane;
			dst : destination_per_lane;
			store : store_op;
			alu : alu_op;
			load : load_op;
		end record;

		-- decoded instruction
		signal d : decoded;

		-- should_* signals are valid only if d_valid is set

		-- currently decoded instruction should set the "halted" signal
		signal should_halt : std_logic;

		-- ready signal going back to the beginning of the pipeline
		signal ready, ready_r : std_logic;
	begin
		-- lane usage is a bit tricky to support push/pop/call/ret, which
		-- behave like compound instructions
		--
		-- PUSH r					in: sp, r, 4		out: sp
		--  - ST (sp), r
		--  - ADDI sp, sp, 4
		--
		-- POP r					in: sp, 4			out: sp, r
		--  - SUBI sp, sp, 4
		--  - LD (sp), r
		--
		-- CALL a					in: sp, ip, a, 4	out: sp, ip
		--  - ST (sp), ip
		--  - ADDI sp, sp, 4
		--  - LI ip, a
		--
		-- CALL r					in: sp, ip, r, 4	out: sp, ip
		--  - ST (sp), ip
		--  - ADDI sp, sp, 4
		--  - MOV ip, r
		--
		-- CALL (r)					in: sp, ip, r, 4	out: sp, ip
		--  - ST (sp), ip
		--  - ADDI sp, sp, 4
		--  - LD (r), ip
		--
		-- RET						in: sp, 4			out: sp, ip
		--  - SUBI sp, sp, 4
		--  - LD (sp), ip
		--
		-- observations:
		--
		--  - stores go first (so the store unit can be attached before the
		--    ALU)
		--  - instructions with more than two inputs all have a constant 4 as
		--    an input
		--  - instructions with four inputs have the IP as an input, and the
		--    IP is stored to memory
		--  - loads use either an input operand or the ALU subtraction result
		--    as address
		--
		--			in				out
		--			1		2		1		2
		-- store	value	address	-		-		(end of branch)
		-- alu:
		--   add	A		B		(A+B)	A
		--   sub	A		B		(A-B)	(A-B)

		-- decode table
		with op select d <=
		-- jmp   src1  src2    dst1  dst2   store  alu     load
		( nop,  (imm,  none), (r1,   none), nop,   nop,    nop  ) when x"0000",	-- MoveRegisterImmediate
		( nop,  (imm,  none), (none, r1  ), nop,   nop,    load ) when x"0001",	-- MoveRegisterAddress
		( nop,  (r2,   none), (r1,   none), nop,   nop,    nop  ) when x"0002",	-- MoveTargetSource
		( nop,  (imm,  r1  ), (none, none), l2,    nop,    nop  ) when x"0003",	-- MoveAddressRegister
		( nop,  (r2,   none), (none, r1  ), nop,   nop,    load ) when x"0004",	-- MoveTargetPointer
		( nop,  (r1,   r2  ), (none, none), l2,    nop,    nop  ) when x"0005",	-- MovePointerSource
		( halt, (none, none), (none, none), nop,   nop,    nop  ) when x"0006",	-- HaltAndCatchFire
		( nop,  (r2,   r3  ), (r1,   none), nop,   add,    nop  ) when x"0007",	-- AddTargetLhsRhs
		( nop,  (r2,   r3  ), (r1,   none), nop,   sub,    nop  ) when x"0008",	-- SubtractTargetLhsRhs
		( nop,  (r2,   r3  ), (r1,   none), nop,   sbc,    nop  ) when x"0009",	-- SubtractWithCarryTargetLhsRhs
		( nop,  (r3,   r4  ), (r1,   r2  ), nop,   mul,    nop  ) when x"000a",	-- MultiplyHighLowLhsRhs
		( nop,  (r3,   r4  ), (r1,   r2  ), nop,   divmod, nop  ) when x"000b",	-- DivmodTargetModLhsRhs
		( nop,  (r2,   r3  ), (r1,   none), nop,   bitand, nop  ) when x"000c",	-- AndTargetLhsRhs
		( nop,  (r2,   r3  ), (r1,   none), nop,   bitor,  nop  ) when x"000d",	-- OrTargetLhsRhs
		( nop,  (r2,   r3  ), (r1,   none), nop,   bitxor, nop  ) when x"000e",	-- XorTargetLhsRhs
		( nop,  (r2,   none), (r1,   none), nop,   bitnot, nop  ) when x"000f",	-- NotTargetSource
		( nop,  (r2,   r3  ), (r1,   none), nop,   shl,    nop  ) when x"0010",	-- LeftShiftTargetLhsRhs
		( nop,  (r2,   r3  ), (r1,   none), nop,   shr,    nop  ) when x"0011",	-- RightShiftTargetLhsRhs
		( nop,  (r2,   imm ), (r1,   none), nop,   add,    nop  ) when x"0012",	-- AddTargetSourceImmediate
		( nop,  (r2,   imm ), (r1,   none), nop,   sub,    nop  ) when x"0013",	-- SubtractTargetSourceImmediate
		( nop,  (r2,   r3  ), (r1,   none), nop,   cmp,    nop  ) when x"0014",	-- CompareTargetLhsRhs

		( nop,  (sp,   r1  ), (sp,   none), l2,    add,    nop  ) when x"0015",	-- PushRegister
		( nop,  (none, sp  ), (sp,   r1  ), nop,   sub,    load ) when x"0016",	-- PopRegister
		( call, (imm,  sp  ), (sp,   none), ip,    add,    nop  ) when x"0017",	-- CallAddress
		( call, (none, sp  ), (sp,   ip  ), nop,   sub,    load ) when x"0018",	-- Return

		( jump, (imm,  none), (none, none), nop,   nop,    nop  ) when x"0019", -- JumpImmediate
		( jump, (r1,   none), (none, none), nop,   nop,    nop  ) when x"001a",	-- JumpRegister

		( jeq,  (imm,  r1  ), (none, none), nop,   nop,    nop  ) when x"001b",	-- JumpImmediateIfEqual
		( jgt,  (imm,  r1  ), (none, none), nop,   nop,    nop  ) when x"001c",	-- JumpImmediateIfGreaterThan
		( jlt,  (imm,  r1  ), (none, none), nop,   nop,    nop  ) when x"001d",	-- JumpImmediateIfLessThan
		( jge,  (imm,  r1  ), (none, none), nop,   nop,    nop  ) when x"001e",	-- JumpImmediateIfGreaterThanOrEqual
		( jle,  (imm,  r1  ), (none, none), nop,   nop,    nop  ) when x"001f",	-- JumpImmediateIfLessThanOrEqual
		( jz,   (imm,  r1  ), (none, none), nop,   nop,    nop  ) when x"0020",	-- JumpImmediateIfZero
		( jnz,  (imm,  r1  ), (none, none), nop,   nop,    nop  ) when x"0021",	-- JumpImmediateIfNotZero
		( jcs,  (imm,  r1  ), (none, none), nop,   nop,    nop  ) when x"0022",	-- JumpImmediateIfCarry
		( jcc,  (imm,  r1  ), (none, none), nop,   nop,    nop  ) when x"0023",	-- JumpImmediateIfNotCarry
		( jd0,  (imm,  r1  ), (none, none), nop,   nop,    nop  ) when x"0024",	-- JumpImmediateIfDivideByZero
		( jnd0, (imm,  r1  ), (none, none), nop,   nop,    nop  ) when x"0025",	-- JumpImmediateIfNotDivideByZero

		( jeq,  (r1,   r2  ), (none, none), nop,   nop,    nop  ) when x"0026",	-- JumpRegisterIfEqual
		( jgt,  (r1,   r2  ), (none, none), nop,   nop,    nop  ) when x"0027",	-- JumpRegisterIfGreaterThan
		( jlt,  (r1,   r2  ), (none, none), nop,   nop,    nop  ) when x"0028",	-- JumpRegisterIfLessThan
		( jge,  (r1,   r2  ), (none, none), nop,   nop,    nop  ) when x"0029",	-- JumpRegisterIfGreaterThanOrEqual
		( jle,  (r1,   r2  ), (none, none), nop,   nop,    nop  ) when x"002a",	-- JumpRegisterIfLessThanOrEqual
		( jz,   (r1,   r2  ), (none, none), nop,   nop,    nop  ) when x"002b",	-- JumpRegisterIfZero
		( jnz,  (r1,   r2  ), (none, none), nop,   nop,    nop  ) when x"002c",	-- JumpRegisterIfNotZero
		( jcs,  (r1,   r2  ), (none, none), nop,   nop,    nop  ) when x"002d",	-- JumpRegisterIfCarry
		( jcc,  (r1,   r2  ), (none, none), nop,   nop,    nop  ) when x"002e",	-- JumpRegisterIfNotCarry
		( jd0,  (r1,   r2  ), (none, none), nop,   nop,    nop  ) when x"002f",	-- JumpRegisterIfDivideByZero
		( jnd0, (r1,   r2  ), (none, none), nop,   nop,    nop  ) when x"0030",	-- JumpRegisterIfNotDivideByZero

		( nop,  (none, none), (none, none), nop,   nop,    nop  ) when x"0031",	-- NoOp

		( nop,  (none, none), (none, none), nop,   nop,    nop  ) when x"0032",	-- GetKeyState					!
		( nop,  (none, none), (none, none), nop,   nop,    nop  ) when x"0033",	-- PollTime						!
		( nop,  (r2,   r3  ), (r1,   none), nop,   adc,    nop  ) when x"0034",	-- AddWithCarryTargetLhsRhs

		( nop,  (none, none), (none, none), nop,   nop,    nop  ) when x"0035",	-- SwapFramebuffers				!
		( call, (r1,   sp  ), (sp,   none), ip,    add,    nop  ) when x"0036",	-- CallRegister
		( call, (r1,   sp  ), (sp,   ip  ), ip,    add,    load ) when x"0037",	-- CallPointer				!
		( nop,  (none, none), (none, none), nop,   nop,    nop  ) when x"0038",	-- InvisibleFramebufferAddress	!

		( nop,  (none, none), (none, none), nop,   nop,    nop  ) when x"0039",	-- PollCycleCountHighLow		!

		( halt, (none, none), (none, none), nop,   nop,    nop  ) when others;

		-- generation of "halted" signal
		with d.jmp select should_halt <=
			'1' when halt,
			'0' when others;
		halted <= '0' when ?? reset else
				  should_halt or halted when rising_edge(clk);

		-- intermediate implementation

		-- stop the fetcher if the next instruction should not be
		-- executed
		with d.jmp select ready <=
			'1' when nop,
			'0' when others;

		ready_r <= '1' when ?? reset else
				   '0' when ?? halted else
				   ready when rising_edge(clk);

		decode_ready <= ready and ready_r;

		lanes : for l in lane generate
		begin
			with d.src(l) select decode_to_op.src(l).sel <=
				none when none,
				from_register when r1|r2|r3|r4|sp,
				from_value when imm,
				from_ip when ip;
			with d.src(l) select decode_to_op.src(l).reg <=
				(others => 'U') when none|imm|ip,
				reg1 when r1,
				reg2 when r2,
				reg3 when r3,
				reg4 when r4,
				x"ff" when sp;			-- TODO
			with d.src(l) select decode_to_op.src(l).value <=
				(others => 'U') when none|ip|r1|r2|r3|r4|sp,
				immed when imm;

			with d.dst(l) select decode_to_op.writeback.lanes(l) <=
				( '0', (others => 'U') ) when none|ip,
				( '1', reg1 ) when r1,
				( '1', reg2 ) when r2,
				( '1', reg3 ) when r3,
				( '1', reg4 ) when r4,
				( '1', x"ff" ) when sp;

		end generate;

		with d.store select decode_to_op.store.active <=
			'0' when nop,
			'1' when l2,
			'U' when ip;
	end block;

	operands : block is
		signal o : op_out;
	begin
		lanes : for l in lane generate
			-- whether the register source field is currently valid
			signal is_register_source : std_logic;
		begin
			with decode_to_op.src(l).sel select is_register_source <=
				'1' when from_register,
				'0' when others;

			reg_read_addr(l) <= decode_to_op.src(l).reg;
			reg_read_rdreq(l) <= is_register_source;

			with decode_to_op.src(l).sel select o.lanes(l).valid <=
				'0' when none,
				'1' when from_value,
				not reg_read_waitrequest(l) when from_register,
				'1' when from_ip;

			with decode_to_op.src(l).sel select o.lanes(l).ready <=
				'1' when none,
				o.lanes(l).valid when others;
			with decode_to_op.src(l).sel select o.lanes(l).value <=
				(others => 'U') when none,
				decode_to_op.src(l).value when from_value,
				reg_read_rddata(l) when from_register,
				fetch_ip when from_ip;
		end generate;

		o.writeback <= decode_to_op.writeback;
		o.store <= decode_to_op.store;

		op_to_store_writeback <= o when rising_edge(clk);

		op_ready <= '1' when ?? reset else
			op_to_store_writeback.lanes(1).ready and op_to_store_writeback.lanes(2).ready;
	end block;

	mem_access : block is
		signal active : std_logic;

		signal addr : address;
		signal wrreq : std_logic;
		signal wrdata : word;
	begin
		active <= op_to_store_writeback.store.active;

		addr <= op_to_store_writeback.lanes(1).value(address'range) when rising_edge(clk);
		wrreq <= active when rising_edge(clk);
		wrdata <= op_to_store_writeback.lanes(2).value when rising_edge(clk);

		d_addr <= addr when ?? wrreq;
		d_wrreq <= wrreq;
		d_wrdata <= wrdata;
	end block;

	writeback : block is
	begin
		lanes : for l in lane generate
		begin
			reg_write_addr(l) <= op_to_store_writeback.writeback.lanes(l).reg;
			reg_write_wrreq(l) <= op_to_store_writeback.writeback.lanes(l).active;
			reg_write_wrdata(l) <= op_to_store_writeback.lanes(l).value;
		end generate;
	end block;

	d_rdreq <= '0';

	-- multiplexes register reads and writes
	--
	-- mainly, this means separate address lines
	register_access : block is
		subtype reg_port is integer range 1 to 2;
	begin
		ports : for p in reg_port generate
			-- which register we want to read
			signal selected_register : reg;

			-- which register is currently visible
			signal active_register : reg;

			-- whether the q value is expected to remain stable
			signal register_settled : std_logic;
		begin
			-- avoid switching selected register if no read request is pending
			selected_register <=
				x"00" when ?? reset else
				reg_read_addr(p) when ?? reg_read_rdreq(p) else
				reg_write_addr(p) when ?? reg_write_wrreq(p) else
				active_register;

			-- address is registered in IP block, replicate this here
			active_register <= selected_register when rising_edge(clk);

			-- register lookup is stable when no switch is immanent
			register_settled <=
				'1' when (selected_register = active_register) else
				'0';

			-- TODO separate our ports and memory ports
			r(p).address <= selected_register;
			r(p).wren <= not reg_read_rdreq(p) and reg_write_wrreq(p);
			r(p).data <= reg_write_wrdata(p);
			reg_read_rddata(p) <= r(p).q;

			reg_read_waitrequest(p) <= not register_settled;
			reg_write_waitrequest(p) <= reg_read_rdreq(p);
		end generate;
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
