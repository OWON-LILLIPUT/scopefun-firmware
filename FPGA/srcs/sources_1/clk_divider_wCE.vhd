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

entity clk_divider_wCE is
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           timebase : in  STD_LOGIC_VECTOR (4 downto 0);
           out_CE : out  STD_LOGIC);
end clk_divider_wCE;

architecture Behavioral of clk_divider_wCE is

signal counter : integer range 0 to 99999999;
signal counter_maxcnt : integer range 0 to 199999999;

begin

generate_clk_enable: process(clk)

begin

	if rising_edge(clk) then
	
		if reset = '1' then

			counter <= 0;  --immediately reset counter
			out_CE <= '1'; --force clk enable TRUE
		
		elsif counter = counter_maxcnt then
			
			counter <= 0;
			out_CE <= '1';
			
			case timebase (4 downto 0) is
			
				when "00000" | "11111" =>
					counter_maxcnt <= 0;	       -- 4 ns sampling period
				when "00001" =>
					counter_maxcnt <= 1;	       -- 8 ns
				when "00010" =>
					counter_maxcnt <= 4;	       -- 20 ns
				when "00011" =>
					counter_maxcnt <= 9;	       -- 40 ns
				when "00100" =>
					counter_maxcnt <= 19;	       -- 80 ns					
				when "00101" =>
					counter_maxcnt <= 49;	       -- 200 ns					
				when "00110" =>
					counter_maxcnt <= 99;           -- 400 ns				
				when "00111" =>
					counter_maxcnt <= 199;          -- 800 ns				
				when "01000" =>
					counter_maxcnt <= 499;          -- 2 us				
				when "01001" =>
					counter_maxcnt <= 999;          -- 4 us					
				when "01010" =>
					counter_maxcnt <= 1999;         -- 8 us				
				when "01011" =>
					counter_maxcnt <= 4999;         -- 20 us					
				when "01100" =>
					counter_maxcnt <= 9999;         -- 40 us
				when "01101" =>
					counter_maxcnt <= 19999;        -- 80 us			
				when "01110" =>
					counter_maxcnt <= 49999;        -- 200 us					
				when "01111" =>
					counter_maxcnt <= 99999;        -- 400 us		
				when "10000" =>
					counter_maxcnt <= 199999;       -- 800 us
				when "10001" =>
					counter_maxcnt <= 499999;       -- 2 ms		
				when "10010" =>
					counter_maxcnt <= 999999;       -- 4 ms				
				when "10011" =>
					counter_maxcnt <= 1999999;      -- 8 ms			
				when "10100" =>
					counter_maxcnt <= 4999999;      -- 20 ms			
				when others =>
					null;
				
			end case;
		
		else
			-- else: keep counting
			counter <= counter + 1;
			out_CE <= '0';
			
		end if;
	end if;
			
end process;


end Behavioral;

