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

entity rand_gen is
    Port ( clk : in  STD_LOGIC;
           enable : in  STD_LOGIC;
           random_num : out  STD_LOGIC_VECTOR(11 downto 0)
			  );
end rand_gen;

architecture Behavioral of rand_gen is

	--32-bit LSFR w/ CE
	--12-bit output vector
	CONSTANT randWidth : integer := 12;
	
	signal rand_temp : std_logic_vector(31 downto 0):=(31 => '1', others => '0');
	
begin

process(clk)

begin

   if(rising_edge(clk)) then
      if enable = '1' then 
         rand_temp(31 downto 1) <= rand_temp(30 downto 0);
         rand_temp(0) <= not(rand_temp(31) XOR rand_temp(22) XOR rand_temp(2) XOR rand_temp(1)); 
      end if;
   end if;
	random_num <= rand_temp(randWidth-1 downto 0);	

end process;

end Behavioral;

