library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity cpu_pipelined is
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

architecture rtl of cpu_pipelined is
	component registers is
		port
		(
			address_a : in std_logic_vector (7 downto 0);
			address_b : in std_logic_vector (7 downto 0);
			clock : in std_logic;
			data_a : in std_logic_vector (31 downto 0);
			data_b : in std_logic_vector (31 downto 0);
			wren_a : in std_logic;
			wren_b : in std_logic;
			q_a : out std_logic_vector (31 downto 0);
			q_b : out std_logic_vector (31 downto 0)
		);
	end component;

	subtype address is std_logic_vector(address_width - 1 downto 0);
	subtype insn is std_logic_vector(63 downto 0);
	subtype word is std_logic_vector(31 downto 0);
	subtype reg is std_logic_vector(7 downto 0);

	constant ip : reg := x"fe";
	constant reset_ip : address := x"00100000";

	constant sp : reg := x"ff";
	constant reset_sp : address := x"000000fc";

	subtype reg_port is integer range 1 to 2;

	type reg_port_interface is record
		address : reg;
		data : word;
		wren : std_logic;
		q : word;
	end record;

	type reg_ports is array(reg_port) of reg_port_interface;

	signal r : reg_ports;

	-- handover between fetch and decode
	signal decode_insn : insn;		-- current instruction
	signal decode_strobe : std_logic;	-- current instruction is new
	signal decode_restart : std_logic;	-- restart after broken pipeline
	signal decode_waitrequest : std_logic;	-- decoder is busy

	subtype lane is integer range 1 to 2;

	type data_lane_source is (unused, c_field, r_field);

	type data_lane_f is record
		source : data_lane_source;

		c_value : word;

		r_num : reg;
		r_valid : std_logic;
		r_value : word;

		valid : std_logic;
		value : word;

		writeback_active : std_logic;
		writeback_target : reg;
	end record;

	type data_lane_r is record
		reg_lookup_busy : std_logic;
		reg_writeback_busy : std_logic;

		busy : std_logic;
	end record;

	type data_lanes_f is array(lane) of data_lane_f;
	type data_lanes_r is array(lane) of data_lane_r;

	type condition is (
		always,			-- obvious
		eq, gt, ge, lt, le,	-- check lane 1
		z, nz,			-- check zero flag
		c, nc,			-- check carry flag
		div0, ndiv0);		-- check divide-by-zero flag
	type jmp_op is (nop, halt);
	type alu_op is (nop);
	type store_op is (nop, store);

	type decoded_insn_f is record
		strobe : std_logic;	-- strobe when a new instruction is fed
		skip : std_logic;	-- skip instruction (conditional or branch delay)
		cond : condition;	-- skip instruction if condition not met
		jmp : jmp_op;		-- opcode for fetch engine
		op : data_lanes_f;	-- operands
		store : store_op;	-- store value from lane 2 to address from lane 1
		alu : alu_op;		-- opcode for ALU
	end record;

	type decoded_insn_r is record
		op : data_lanes_r;	-- operands
		store_busy : std_logic;
	end record;

	signal i_f : decoded_insn_f;
	signal i_r : decoded_insn_r;

	-- decoder -> fetch: should halt
	signal should_halt : std_logic;

	-- feedback for register read after register write
	type register_register_feedback is record
		active : std_logic;
		number : reg;
		value : word;
	end record;

	type register_register_feedbacks is array(lane) of register_register_feedback;

	signal rrfb : register_register_feedbacks;
begin
	-- Fetch one instruction from an Avalon-MM compatible interface
	--
	-- This interface can provide data on the next cycle or ask for more time.
	-- If i_waitrequest is low at the next rising edge, i_rddata is valid.
	--
	-- In any case, the current transaction has been started, so the next fetch
	-- address can be presented right away
	fetch : block is
		signal current_ip : address;
		signal next_ip : address;
		signal incrementing : std_logic;

		signal stash : insn;

		type state is (resetting, start, normal, overflow, halt);

		signal s : state;
	begin
		halted <= '1' when s = halt else
			  '0';

		with s select incrementing <=
			'0' when resetting,
			'1' when start|normal,
			'0' when overflow|halt;

		current_ip <= reset_ip when reset = '1' else		-- async reset
			      unaffected when incrementing = '0' else	-- enable
			      next_ip when rising_edge(clk);		-- clock

		next_ip <= address(unsigned(current_ip) + 8);

		with s select i_addr <=
			(others => 'U') when resetting,
			current_ip when start|normal,
			(others => 'U') when overflow|halt;
		with s select i_rdreq <=
			'0' when resetting,
			'1' when start|normal,
			'0' when overflow|halt;

		with s select decode_restart <=
			'0' when resetting,
			'1' when start,
			'0' when normal|overflow|halt;

		with s select decode_strobe <=
			'0' when resetting,
			not i_waitrequest when start|normal,
			'1' when overflow,
			'0' when halt;

		with s select decode_insn <=
			(others => 'U') when resetting,
			i_rddata when start|normal,
			stash when overflow,
			(others => 'U') when halt;

		process(reset, clk) is
		begin
			if(reset = '1') then
				s <= resetting;
			elsif(rising_edge(clk)) then
				case s is
					when resetting =>
						s <= start;
					when start =>
						-- no read in progress, pipeline has space
						s <= normal;
					when normal =>
						-- read in progress, pipeline might have space
						if(i_waitrequest = '0') then
							if(decode_waitrequest = '1') then
								-- stash
								stash <= i_rddata;
								s <= overflow;
							end if;
						end if;
					when overflow =>
						-- no read in progress, pipeline was busy
						if(decode_waitrequest = '0') then
							s <= normal;
						end if;
					when halt =>
						null;
				end case;
				if(should_halt = '1') then
					s <= halt;
				end if;
			end if;
		end process;
	end block;

	decode : block is
		alias instruction : insn is decode_insn;
		alias o : std_logic_vector(15 downto 0) is instruction(63 downto 48);
		alias r1 : reg is instruction(47 downto 40);
		alias r2 : reg is instruction(39 downto 32);
		alias r3 : reg is instruction(31 downto 24);
		alias r4 : reg is instruction(23 downto 16);
		alias c : word is instruction(31 downto 0);

		type slot is (unused, reg1, reg2, reg3, reg4, const);
		subtype writeback_slot is slot range unused to reg4;
		type mem_op is (nop, load, store);

		type slot_per_lane is array(lane) of slot;
		type writeback_slot_per_lane is array(lane) of writeback_slot;

		type mapping is record
			jmp : jmp_op;
			cond : condition;
			src : slot_per_lane;
			dst : writeback_slot_per_lane;
			alu : alu_op;
			mem : mem_op;
		end record;

		signal m : mapping;

		-- pipeline broken, skip until restart
		signal skip : std_logic;
	begin
		-- FIXME: latches
		skip <= '1' when reset = '1' else
			'0' when decode_restart = '1' else
			'1' when m.jmp /= nop and rising_edge(clk);

		decode_waitrequest <= i_r.op(1).busy or i_r.op(2).busy or i_r.store_busy;

		with o select m <=
		-- jmp   cond      (1) src (2)         (1) dst (2)       alu    mem
		(  nop,  always, ( const,  unused ), ( reg1,   unused ), nop,   nop     ) when x"0000",	-- LI
		(  nop,  always, ( const,  unused ), ( unused, reg1   ), nop,   load    ) when x"0001",	-- LD abs
		(  nop,  always, ( reg2,   unused ), ( reg1,   unused ), nop,   nop     ) when x"0002",	-- MOV
		(  nop,  always, ( const,  reg1   ), ( unused, unused ), nop,   store   ) when x"0003",	-- ST abs
		(  nop,  always, ( reg2,   unused ), ( unused, reg1   ), nop,   load    ) when x"0004",	-- LD [r]
		(  nop,  always, ( reg1,   reg2   ), ( unused, unused ), nop,   store   ) when x"0005",	-- ST [r]
		(  halt, always, ( unused, unused ), ( unused, unused ), nop,   nop     ) when x"0006",	-- HCF
		(  nop,  always, ( unused, unused ), ( unused, unused ), nop,   nop     ) when others;

		i_f.strobe <= decode_strobe and not skip;

		i_f.skip <= skip;

		i_f.jmp <= m.jmp;

		lanes : for l in lane generate
		begin
			with m.src(l) select i_f.op(l).source <=
				unused when unused,
				c_field when const,
				r_field when reg1|reg2|reg3|reg4;
			i_f.op(l).c_value <= c;
			with m.src(l) select i_f.op(l).r_num <=
				(others => 'U') when unused|const,
				r1 when reg1,
				r2 when reg2,
				r3 when reg3,
				r4 when reg4;

			with m.dst(l) select i_f.op(l).writeback_active <=
				'0' when unused,
				'1' when reg1|reg2|reg3|reg4;
			with m.dst(l) select i_f.op(l).writeback_target <=
				(others => 'U') when unused,
				r1 when reg1,
				r2 when reg2,
				r3 when reg3,
				r4 when reg4;
		end generate;

		i_f.cond <= m.cond;

		with m.mem select i_f.store <=
			nop when nop|load,
			store when store;

		i_f.alu <= m.alu;
	end block;

	-- swap block (stop only)
	swap : block is
		alias sw_f : decoded_insn_f is i_f;
		alias sw_r : decoded_insn_r is i_r;
	begin
		should_halt <= '1' when sw_f.skip = '0' and sw_f.jmp = halt else
			       '0';
	end block;

	-- both register lookup and writeback stage for now
	-- TODO: separate
	reg_access : for l in lane generate
		alias rl_f : decoded_insn_f is i_f;
		alias rl_r : decoded_insn_r is i_r;
		alias wb_f : decoded_insn_f is i_f;
		alias wb_r : decoded_insn_r is i_r;

		signal read_selected_register : reg;
		signal write_selected_register : reg;

		-- what we'd like to read
		signal selected_register : reg;
		-- what we're actually seeing
		signal active_register : reg;

		-- read data, valid when register is already active
		signal r_valid : std_logic;
		signal r_q : word;

		-- read data, including all shortcuts
		signal valid : std_logic;
		signal q : word;

		-- write data
		signal data : word;
		signal wren : std_logic;
	begin
		-- FIXME: assuming enough register ports for all lanes
		r(l).address <= selected_register;
		r(l).data <= data;
		r(l).wren <= wren;

		data <= wb_f.op(l).value;
		wren <= wb_f.op(l).writeback_active and wb_f.op(l).valid;

		read_selected_register <= (others => '0') when reset = '1' else			-- reset
					  rl_f.op(l).r_num when rl_f.op(l).source = r_field else	-- active
					  unaffected;						-- inactive

		rrfb(l) <= (active => wren, number => write_selected_register, value => data) when rising_edge(clk);

		write_selected_register <= (others => '0') when reset = '1' else
					   wb_f.op(l).writeback_target when wb_f.op(l).writeback_active = '1';

		selected_register <= write_selected_register when wren = '1' else
				     read_selected_register;

		-- replicate delay of register file
		active_register <= (others => '0') when reset = '1' else
				   selected_register when rising_edge(clk);

		-- FIXME: assuming enough register ports for all lanes
		r_valid <= '1' when active_register = selected_register else
				  '0';
		r_q <= r(l).q;

		shortcut : block is
			subtype std_logic_per_lane is std_logic_vector(lane);
			type word_per_lane is array(lane) of word;

			-- read data, interfaces between r-r shortcut blocks
			signal valid_in, valid_out : std_logic_per_lane;
			signal q_in, q_out : word_per_lane;
		begin
			-- selectors for all shortcut paths
			selector : for ll in lane generate
				signal active : std_logic;
			begin
				active <= '0' when rrfb(ll).active = '0' else
					  '1' when rrfb(ll).number = read_selected_register else
					  '0';
				valid_out(ll) <= active or valid_in(ll);
				q_out(ll) <= rrfb(ll).value when active = '1' else
					     q_in(ll);
			end generate;

			-- connections between selectors
			valid <= valid_out(lane'low);
			q <= q_out(lane'low);

			connection : for ll in lane'low + 1 to lane'high generate
			begin
				valid_in(ll - 1) <= valid_out(ll);
				q_in(ll - 1) <= q_out(ll);
			end generate;

			valid_in(lane'high) <= r_valid;
			q_in(lane'high) <= r_q;
		end block;

		rl_f.op(l).r_valid <= valid;
		rl_f.op(l).r_value <= q;

		with rl_f.op(l).source select rl_r.op(l).reg_lookup_busy <=
			'0' when unused|c_field,
			not rl_f.op(l).r_valid when r_field;

		with rl_f.op(l).source select rl_f.op(l).valid <=
			'0' when unused,
			'1' when c_field,
			rl_f.op(l).r_valid when r_field;
		with rl_f.op(l).source select rl_f.op(l).value <=
			(others => 'U') when unused,
			rl_f.op(l).c_value when c_field,
			rl_f.op(l).r_value when r_field;

		wb_r.op(l).reg_writeback_busy <= not wb_f.op(l).valid when wb_f.op(l).writeback_active = '1' else
					       '0';

		rl_r.op(l).busy <= rl_r.op(l).reg_lookup_busy or wb_r.op(l).reg_writeback_busy;
	end generate;

	mem_access : block
		alias st_f : decoded_insn_f is i_f;
		alias st_r : decoded_insn_r is i_r;

		signal store_active : std_logic;
		signal store_ready : std_logic;
	begin
		with st_f.store select store_active <=
			'1' when store,
			'0' when nop;
		store_ready <= st_f.op(1).valid and st_f.op(2).valid;

		-- store value from lane 2 to address from lane 1

		st_r.store_busy <= store_active and not store_ready;

		process(reset, clk) is
		begin
			if(reset = '1') then
				d_addr <= (others => 'U');
				d_rdreq <= '0';
				d_wrreq <= '0';
			elsif(rising_edge(clk)) then
				d_addr <= (others => 'U');
				d_rdreq <= '0';
				d_wrreq <= '0';
				if(store_active = '1' and store_ready = '1') then
					d_addr <= st_f.op(1).value;
					d_wrdata <= st_f.op(2).value;
					d_wrreq <= '1';
				end if;
			end if;
		end process;
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
