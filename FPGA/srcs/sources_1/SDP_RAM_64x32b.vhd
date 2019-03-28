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

--
-- Dual-Port RAM, Distributed, Read-First mode
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SDP_RAM_64x32b is
    port (clk1 : in std_logic;
          clk2 : in std_logic;
          we   : in std_logic;
          addr1 : in std_logic_vector(5 downto 0);
          addr2 : in std_logic_vector(5 downto 0);
          di1   : in std_logic_vector(31 downto 0);
          do1  : out std_logic_vector(31 downto 0);
          do2  : out std_logic_vector(31 downto 0));
end SDP_RAM_64x32b;

architecture Behavioral of SDP_RAM_64x32b is

constant DATA_DEPTH : integer := 64;
constant DATA_WIDTH : integer := 32;

type ram_type is array (DATA_DEPTH-1 downto 0) of std_logic_vector (DATA_WIDTH-1 downto 0);
signal RAM : ram_type;

ATTRIBUTE ram_style: string;
ATTRIBUTE ram_style OF ram: SIGNAL IS "distributed";

begin

clk1_side:process (clk1)
begin
    if (rising_edge(clk1)) then
        if (we = '1') then
            RAM(to_integer(unsigned(addr1))) <= di1;
        end if;
		  do1 <= RAM(to_integer(unsigned(addr1)));
     end if;
end process;
   
clk2_side:process (clk2)
begin
		if (rising_edge(clk2)) then
			do2 <= RAM(to_integer(unsigned(addr2)));
		end if;
end process;

end Behavioral;