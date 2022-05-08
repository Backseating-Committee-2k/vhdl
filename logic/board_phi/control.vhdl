library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity control is
	port(
		-- async reset
		reset : in std_logic;

		-- clock
		clk : in std_logic;

		-- PCIe interface (Avalon-ST)
		rx_ready : out std_logic;
		rx_valid : in std_logic;
		rx_data : in std_logic_vector(63 downto 0);
		rx_sop : in std_logic;
		rx_eop : in std_logic;
		rx_err : in std_logic;

		rx_bardec : in std_logic_vector(7 downto 0);

		tx_ready : in std_logic;
		tx_valid : out std_logic;
		tx_data : out std_logic_vector(63 downto 0);
		tx_sop : out std_logic;
		tx_eop : out std_logic;
		tx_err : out std_logic;

		completer_id : in std_logic_vector(15 downto 0);

		-- interrupt
		int : out std_logic;

		-- CPU control interface
		cpu_reset : out std_logic;
		cpu_halted : in std_logic
	);
end entity;

architecture rtl of control is
	constant reg_bar : integer := 2;

	-- control register
	signal should_reset : std_logic;

	-- interrupt mask register
	signal mask : std_logic;

	constant reg_addr_bits : integer := 8;
	subtype reg_addr is std_logic_vector(reg_addr_bits - 1 downto 0);

	constant reg_status	: reg_addr := "00000000";
	constant reg_control	: reg_addr := "00001000";
	constant reg_int_status	: reg_addr := "00010000";
	constant reg_int_mask	: reg_addr := "00011000";

	type sel is (sel_status, sel_control, sel_int_status, sel_int_mask, sel_invalid);

	subtype pci_address_bdf is std_logic_vector(15 downto 0);
	subtype pcie_type is std_logic_vector(4 downto 0);
	subtype pcie_tc is std_logic_vector(2 downto 0);
	subtype pcie_attr is std_logic_vector(1 downto 0);
	subtype pcie_tag is std_logic_vector(7 downto 0);
	subtype pcie_lower_address is std_logic_vector(6 downto 0);

	constant mem_access : pcie_type := "00000";
	constant completion : pcie_type := "01010";

	signal readback_sel : sel;
	signal readback_strobe : std_logic;
	signal readback_requester_id : pci_address_bdf;
	signal readback_tc : pcie_tc;
	signal readback_attr : pcie_attr;
	signal readback_tag : pcie_tag;
	signal readback_lower_address : pcie_lower_address;
begin
	rx_ready <= '1';

	cpu_reset <= should_reset;

	process(reset, clk) is
		variable has_data : std_logic;
		variable has_64bit_address : std_logic;
		variable ty : pcie_type;
		variable tc : std_logic_vector(2 downto 0);
		variable ep : std_logic;
		variable attr : pcie_attr;
		variable length : std_logic_vector(9 downto 0);
		variable requester_id : pci_address_bdf;
		variable tag : pcie_tag;
		variable last_be : std_logic_vector(3 downto 0);
		variable first_be : std_logic_vector(3 downto 0);
		variable address : std_logic_vector(31 downto 0);

		type state is (header1, header2, data, ignore);

		variable s : state;

		variable reg_address : reg_addr;

		variable selected : sel;
	begin
		if(reset = '1') then
			readback_strobe <= '0';
			mask <= '0';
			should_reset <= '1';
			s := header1;
		elsif(rising_edge(clk)) then
			readback_strobe <= '0';
			if(?? rx_valid) then
				if(?? rx_sop) then
					-- first QWORD, header DWORDs 0/1
					has_data := rx_data(30);
					has_64bit_address := rx_data(29);
					ty := rx_data(28 downto 24);
					tc := rx_data(22 downto 20);
					ep := rx_data(14);
					attr := rx_data(13 downto 12);
					length := rx_data(9 downto 0);
					requester_id := rx_data(63 downto 48);
					tag := rx_data(47 downto 40);
					last_be := rx_data(39 downto 36);
					first_be := rx_data(35 downto 32);

					s := header2;
				else
					case s is
						when header1 =>
							report "invalid packet"
								severity error;
							s := ignore;
						when header2 =>
							address := rx_data(31 downto 0);
							if(?? rx_bardec(2)) then
								reg_address := address(reg_addr'range);

								case? reg_address is
									when reg_status		=> selected := sel_status;
									when reg_control	=> selected := sel_control;
									when reg_int_status	=> selected := sel_int_status;
									when reg_int_mask	=> selected := sel_int_mask;
									when others		=> selected := sel_invalid;
								end case?;
								if(?? has_data) then
									-- write access
									s := data;
								else
									-- read access
									assert ?? rx_eop report "no data, but not end of packet" severity error;
									readback_sel <= selected;
									readback_attr <= attr;
									readback_tag <= tag;
									readback_requester_id <= requester_id;
									readback_lower_address <= reg_address(pcie_lower_address'range);
									readback_strobe <= '1';
									s := header1;
								end if;
							else
								s := ignore;
							end if;
						when data =>
							-- write access
							case selected is
								when sel_status =>
									null;		-- read only
								when sel_control =>
									should_reset <= rx_data(0);
								when sel_int_status =>
									null;		-- read only
								when sel_int_mask =>
									mask <= rx_data(0);
								when sel_invalid =>
									null;
							end case;
						when ignore =>
							null;
					end case;
				end if;
			end if;
		end if;
	end process;

	process(reset, clk) is
		type state is (idle, header1, header2, data);
		variable s : state;

		-- fixme
		constant status : std_logic_vector(2 downto 0) := "000";
	begin
		if(?? reset) then
			s := idle;
		elsif(rising_edge(clk)) then
			tx_valid <= '0';
			tx_data <= (others => 'U');
			tx_sop <= 'U';
			tx_eop <= 'U';
			tx_err <= 'U';
			case s is
				when idle =>
					if(?? readback_strobe) then
						s := header1;
					end if;
				when header1 =>
					if(?? tx_ready) then
						tx_valid <= '1';
						tx_data <= completer_id & status & '0' & x"008" & '0' & "10" & completion & '0' & readback_tc & "0000" & '0' & '0' & readback_attr & "00" & "0000000010";
						tx_sop <= '1';
						tx_eop <= '0';
						tx_err <= '0';
						s := header2;
					end if;
				when header2 =>
					if(?? tx_ready) then
						tx_valid <= '1';
						tx_data <= x"00000000" & readback_requester_id & readback_tag & '0' & readback_lower_address;
						tx_sop <= '0';
						tx_eop <= '0';
						tx_err <= '0';
						s := data;
					end if;
				when data =>
					if(?? tx_ready) then
						tx_valid <= '1';
						case readback_sel is
							when sel_status =>
								tx_data <= (0 => not cpu_halted, others => '0');
							when sel_control =>
								tx_data <= (0 => should_reset, others => '0');
							when sel_int_status =>
								tx_data <= (0 => cpu_halted, others => '0');
							when sel_int_mask =>
								tx_data <= (0 => mask, others => '0');
							when sel_invalid =>
								tx_data <= (others => '1');
						end case;
						tx_sop <= '0';
						tx_eop <= '1';
						tx_err <= '0';
						s := idle;
					end if;
			end case;
		end if;
	end process;
end architecture;
