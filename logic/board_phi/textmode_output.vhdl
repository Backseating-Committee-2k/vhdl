library ieee;

use ieee.std_logic_1164.ALL;
use ieee.std_logic_misc.ALL;
use ieee.numeric_std.ALL;

use work.bss2k.ALL;

entity textmode_output is
	port(
		-- async reset
		reset : in std_logic;

		-- clock
		clk : in std_logic;

		-- target address
		target_address : in std_logic_vector(63 downto 0);
		start : in std_logic;

		-- PCIe interface

		tx_ready : in std_logic;
		tx_valid : out std_logic;
		tx_data : out std_logic_vector(63 downto 0);
		tx_sop : out std_logic;
		tx_eop : out std_logic;
		tx_err : out std_logic;

		cpl_pending : out std_logic;

		tx_req : out std_logic;
		tx_start : in std_logic;

		device_id : in std_logic_vector(15 downto 0);

		-- internal data bus
		d_addr : in address;
		d_wrreq : in std_logic;
		d_wrdata : in word;
		d_waitrequest : out std_logic
	);
end entity;

architecture rtl of textmode_output is
	component textmode_pixel_fifo
		PORT
		(
			aclr		: in std_logic ;
			clock		: in std_logic ;
			data		: in std_logic_vector (63 downto 0);
			rdreq		: in std_logic ;
			wrreq		: in std_logic ;
			almost_full	: out std_logic ;
			empty		: out std_logic ;
			q			: out std_logic_vector (63 downto 0);
			usedw		: out std_logic_vector (7 downto 0)
		);
	end component;

	component textmode_ram
		port
		(
			clock		: in std_logic;
			data		: in std_logic_vector (7 downto 0);
			rdaddress	: in std_logic_vector (10 downto 0);
			wraddress	: in std_logic_vector (10 downto 0);
			wren		: in std_logic;
			q			: out std_logic_vector (7 downto 0)
		);
	end component;

	component textmode_rom
		port
		(
			address		: in std_logic_vector (11 downto 0);
			clock		: in std_logic;
			q			: out std_logic_vector (5 downto 0)
		);
	end component;

	signal writing_char_ram : std_logic;

	signal ram_addr_tmp : std_logic_vector(11 downto 0);
	signal ram_addr : std_logic_vector(10 downto 0);
	signal ram_data : std_logic_vector(7 downto 0);

	signal rom_addr : std_logic_vector(11 downto 0);
	signal rom_data : std_logic_vector(5 downto 0);

	subtype font_x is unsigned(1 downto 0);
	subtype font_y is unsigned(3 downto 0);
	subtype row is unsigned(4 downto 0);
	subtype col is unsigned(6 downto 0);

	constant font_width : font_x := to_unsigned(3, 2);
	constant font_height : font_y := to_unsigned(14, 4);
	constant rows : row := to_unsigned(25, 5);
	constant columns : col := to_unsigned(80, 7);

	signal font_running, font_running_r : std_logic;
	signal font_active : std_logic;
	signal font_done : std_logic;

	signal p, p_r, p_rr : font_x;
	signal l, l_r, l_rr : font_y;
	signal r, r_r, r_rr : row;
	signal c, c_r, c_rr : col;
	signal v, v_r, v_rr : std_logic;

	signal pixels : std_logic_vector(1 downto 0);

	signal tex_rdreq : std_logic;
	signal tex_data : std_logic_vector(63 downto 0);
	signal tex_almost_full : std_logic;
	signal tex_empty : std_logic;
	signal tex_usedw : std_logic_vector(7 downto 0);

	signal transfer_counter : unsigned(11 downto 0);
	constant transfer_count : unsigned(11 downto 0) := to_unsigned(2700, 12);

	signal current_address : std_logic_vector(63 downto 0);
	signal is_64bit : std_logic;

	signal qword_counter : unsigned(4 downto 0);

	signal t0b, t0r, t1b, t1r : std_logic_vector(7 downto 0);
begin
	writing_char_ram <= d_wrreq and
			not or_reduce(d_addr(address'high downto 11));

	v <= font_active;

	addr_gen : process(reset, clk) is
	begin
		if(?? reset) then
			p <= to_unsigned(0, p'length);
			l <= to_unsigned(0, l'length);
			r <= to_unsigned(0, r'length);
			c <= to_unsigned(0, c'length);
			font_done <= '0';
		elsif(rising_edge(clk)) then
			if(?? font_active) then
				font_done <= '0';
				if(p = font_width - 1) then
					p <= to_unsigned(0, p'length);
					if(c = columns - 1) then
						c <= to_unsigned(0, c'length);
						if(l = font_height - 1) then
							l <= to_unsigned(0, l'length);
							if(r = rows - 1) then
								r <= to_unsigned(0, r'length);
								font_done <= '1';
							else
								r <= r + 1;
							end if;
						else
							l <= l + 1;
						end if;
					else
						c <= c + 1;
					end if;
				else
					p <= p + 1;
				end if;
			end if;
		end if;
	end process;

	ram_addr_tmp <= std_logic_vector(r * columns + c);
	ram_addr <= ram_addr_tmp(ram_addr'range);

	ram_inst : textmode_ram
		port map(
			clock => clk,
			data => d_wrdata(7 downto 0),
			rdaddress => ram_addr,
			q => ram_data,
			wraddress => d_addr(12 downto 2),
			wren => writing_char_ram
		);

	-- mimic RAM delay
	p_r <= p when rising_edge(clk);
	l_r <= l when rising_edge(clk);
	r_r <= r when rising_edge(clk);
	c_r <= c when rising_edge(clk);
	v_r <= v when rising_edge(clk);

	d_waitrequest <= '0';

	rom_addr <= ram_data & std_logic_vector(l);

	rom_inst : textmode_rom
		port map(
			clock => clk,
			address => rom_addr,
			q => rom_data
		);

	-- mimic ROM delay
	p_rr <= p_r when rising_edge(clk);
	l_rr <= l_r when rising_edge(clk);
	r_rr <= r_r when rising_edge(clk);
	c_rr <= c_r when rising_edge(clk);
	v_rr <= v_r when rising_edge(clk);

	-- TODO clean up
	font_running <= '1' when ?? start else
					'0' when ?? font_done else
					font_running_r;
	font_running_r <= '0' when ?? reset else
					font_running when rising_edge(clk);

	font_active <= font_running and not tex_almost_full;

	with p_rr select pixels <=
			rom_data(5 downto 4) when "00",
			rom_data(3 downto 2) when "01",
			rom_data(1 downto 0) when "10",
			"UU" when others;

	t1b <= x"ff" when ?? pixels(1) else "0" & std_logic_vector(c_rr);
	t1r <= x"ff" when ?? pixels(1) else "000" & std_logic_vector(r_rr);
	t0b <= x"ff" when ?? pixels(0) else "0" & std_logic_vector(c_rr);
	t0r <= x"ff" when ?? pixels(0) else "000" & std_logic_vector(r_rr);

	fifo_inst : textmode_pixel_fifo
		port map(
			aclr => reset,
			clock => clk,
			data(63 downto 56) => x"ff",
			data(55 downto 48) => t0b,
			data(47 downto 40) => (others => pixels(0)),
			data(39 downto 32) => t0r,
			data(31 downto 24) => x"ff",
			data(23 downto 16) => t1b,
			data(15 downto 8) => (others => pixels(1)),
			data(7 downto 0) => t1r,
			wrreq => v_rr,
			almost_full	=> tex_almost_full,
			empty => tex_empty,
			rdreq => tex_rdreq,
			q => tex_data,
			usedw => tex_usedw
		);

	cpl_pending <= '0';
	tx_err <= '0';

	current_address <= target_address(63 downto 20) &
						std_logic_vector(transfer_counter) &
						"00000000";
	is_64bit <= or_reduce(target_address(63 downto 32));

	pcie_write : process(reset, clk) is
		type state is (idle, waiting, header, data);
		variable s : state;

		procedure defaults is
		begin
			tx_req <= '0';
			tx_valid <= '0';
			tex_rdreq <= '0';
		end procedure;
	begin
		if(?? reset) then
			s := idle;
			transfer_counter <= to_unsigned(0, transfer_counter'length);
			defaults;
		elsif(rising_edge(clk)) then
			defaults;
			case s is
				when idle =>
					if(?? font_done) then
						transfer_counter <= to_unsigned(0, transfer_counter'length);
					end if;
					if(not (?? tex_empty)) then
						s := waiting;
						tx_req <= '1';
					end if;
				when waiting =>
					if(?? tx_start) then
						s := header;
						tx_valid <= '1';
						tx_data <= device_id &		-- requester id
									x"00" &			-- tag (unused)
									x"ff" &			-- byte enables
									"0" &			-- reserved
									"1" &			-- data attached
									is_64bit &		-- 64 bit address
									"00000" &		-- type: memory access
									"0" &			-- reserved
									"000" &			-- traffic class
									"0000" &		-- reserved
									"0" &			-- no digest
									"0" &			-- not poisoned
									"00" &			-- attributes
									"00" &			-- reserved
									"0001000000";	-- 64 DWORDs
						tx_sop <= '1';
						tx_eop <= '0';
						tex_rdreq <= '1';
					else
						tx_req <= '1';
					end if;
				when header =>
					if(transfer_counter = transfer_count - 1) then
						transfer_counter <= to_unsigned(0, transfer_counter'length);
					else
						transfer_counter <= transfer_counter + 1;
					end if;
					tx_valid <= '1';
					s := data;
					tex_rdreq <= '1';
					qword_counter <= to_unsigned(0, qword_counter'length);
					if(?? is_64bit) then
						tx_data <= current_address(31 downto 2) & "00" &
									current_address(63 downto 32);
					else
						tx_data <= x"00000000" &
									current_address(31 downto 2) & "00";
					end if;
					tx_sop <= '0';
					tx_eop <= '0';
				when data =>
					if(?? tx_ready) then
						tx_valid <= '1';
						tx_data <= tex_data;
						tx_sop <= '0';
						if(qword_counter = x"1f") then
							if(not (?? tex_empty)) then
								tx_req <= '1';
								s := waiting;
							else
								s := idle;
							end if;
							tex_rdreq <= '0';
							tx_eop <= '1';
						elsif(qword_counter = x"1e") then
							qword_counter <= qword_counter + 1;
							tex_rdreq <= '0';
							tx_eop <= '0';
						else
							qword_counter <= qword_counter + 1;
							tex_rdreq <= '1';
							tx_eop <= '0';
						end if;
					end if;
			end case;
		end if;
	end process;
end architecture;
