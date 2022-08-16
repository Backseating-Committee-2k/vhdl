library ieee;

use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity interrupt_encoder is
	port(
		-- async reset
		reset : in std_logic;

		-- clock
		clk : in std_logic;

		-- interrupt sources
		int_sts : in std_logic_vector(31 downto 0);

		-- legacy interrupt interface
		legacy_int_sts : out std_logic;
		legacy_int_ack : in std_logic;

		-- MSI interrupt interface
		msi_int_req : out std_logic;
		msi_int_num : out std_logic_vector(4 downto 0);
		msi_int_tc : out std_logic_vector(2 downto 0);
		msi_int_ack : in std_logic
	);
end entity;

architecture rtl of interrupt_encoder is
	constant num_irqs : natural := 32;
	subtype int is integer range num_irqs - 1 downto 0;

	subtype ints is std_logic_vector(int);

	signal already_sent : ints;

	type state is (idle, waiting_for_ack, waiting_for_not_ack);
	signal s : state;
begin
	-- TODO not implemented yet
	legacy_int_sts <= '0';

	process(reset, clk) is
		variable pending : ints;
		variable have_int : boolean;
		variable highest : int;
	begin
		if(?? reset) then
			already_sent <= (others => '0');
			s <= idle;
			msi_int_req <= '0';
			msi_int_num <= (others => '0');
			msi_int_tc <= (others => '0');
		elsif(rising_edge(clk)) then
			case s is
				when idle =>
					pending := int_sts and not already_sent;

					have_int := false;

					for i in pending'range loop
						if(?? pending(i)) then
							if(not have_int) then
								have_int := true;
								highest := i;
								already_sent(i) <= '1';
							end if;
						elsif(not (?? int_sts(i))) then
							already_sent(i) <= '0';
						end if;
					end loop;

					if(have_int) then
						s <= waiting_for_ack;
						msi_int_req <= '1';
						msi_int_num <= std_logic_vector(to_unsigned(highest, 5));
						msi_int_tc <= (others => '0');
					end if;
				when waiting_for_ack =>
					already_sent <= already_sent and int_sts;
					if(not (?? int_sts(highest))) then
						s <= idle;
						msi_int_req <= '0';
					end if;
					if(?? msi_int_ack) then
						s <= waiting_for_not_ack;
						msi_int_req <= '0';
					end if;
				when waiting_for_not_ack =>
					already_sent <= already_sent and int_sts;
					if(not (?? msi_int_ack)) then
						s <= idle;
					end if;
			end case;
		end if;
	end process;
end architecture;
