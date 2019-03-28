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

entity SDP_BRAM_custom_signal is
    Port ( clka : in  STD_LOGIC;
           wea : in  STD_LOGIC;
           addra : in  STD_LOGIC_VECTOR (14 downto 0);
           dina  : in  STD_LOGIC_VECTOR (11 downto 0);
           clkb : in  STD_LOGIC;
           addrb : in  STD_LOGIC_VECTOR (14 downto 0);
           doutb : out STD_LOGIC_VECTOR (11 downto 0));
end SDP_BRAM_custom_signal;

architecture Behavioral of SDP_BRAM_custom_signal is

constant DATA_DEPTH : integer := 32768;
constant DATA_WIDTH : integer := 12;

type ram_type is array (DATA_DEPTH-1 downto 0) of std_logic_vector (DATA_WIDTH-1 downto 0);
signal ram : ram_type;

ATTRIBUTE ram_style: string;
ATTRIBUTE ram_style OF ram: SIGNAL IS "block";

begin

write: process (clka)
begin
	if (rising_edge(clka)) then
		if (wea = '1') then
			ram(to_integer(unsigned(addra))) <= dina;
		end if;
	end if;
end process write;

read: process (clkb)
begin
	if (rising_edge(clkb)) then
		doutb <= ram(to_integer(unsigned(addrb)));
	end if;
end process read;

end Behavioral;