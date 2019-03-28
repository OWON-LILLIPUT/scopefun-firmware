----------------------------------------------------------------------------------
--    Copyright (C) 2019 Dejan Priversek
--
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <http://www.gnu.org/licenses/>.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity timer is
    Port ( clk : in  STD_LOGIC;
           t_reset : in  STD_LOGIC;
           t_start : in  STD_LOGIC;
           holdoff : in  STD_LOGIC_VECTOR (31 downto 0);
           o_end : out  STD_LOGIC);
end timer;

architecture Behavioral of timer is

signal t_start_d : std_logic:='0';

signal s_counter : unsigned (31 downto 0):=to_unsigned(0,32);
signal s_holdoff : unsigned (31 downto 0):=to_unsigned(0,32);
signal s_start : std_logic:='0';
signal s_start_d : std_logic:='0';
signal s_end : std_logic:='0';

begin

o_end <= s_end;

timer_process: process(clk)

begin

	if (rising_edge(clk)) then
		if t_reset = '1' then
			t_start_d <= '0';
			s_start <= '0';
			s_end <= '0';
			s_holdoff <= to_unsigned(0,32);
			s_counter <= to_unsigned(0,32);		
		else
			t_start_d <= t_start;
			if t_start_d = '0' AND t_start = '1' then
				s_start <= '1'; --begin counting
			end if;
			if s_start = '1' OR t_start = '1' OR t_start_d = '1' then
				--if counter has reached Holdoff
				if s_counter = unsigned(holdoff) then
					s_counter <= to_unsigned(0,32);--reset counter
					s_start <= '0';--de-assert start flag
					s_end <= '1';  --assert end flag
				else
					--count UP
					s_counter <= s_counter + 1;
					s_end <= '0';
				end if;
			else
				s_end <= '0'; --de-assert end flag
			end if;
		end if;
	end if;

end process;

end Behavioral;

