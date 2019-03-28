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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity blink is
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           trigd : in  STD_LOGIC;
           led_out : out  STD_LOGIC);
end blink;

architecture Behavioral of blink is

signal blinkState : std_logic_vector(1 downto 0);
constant A : std_logic_vector(1 downto 0) := "00";
constant B : std_logic_vector(1 downto 0) := "01";
constant C : std_logic_vector(1 downto 0) := "10";
constant D : std_logic_vector(1 downto 0) := "11";

signal begin_blinking : std_logic;
signal cnt : integer range 0 to 99999999;
constant ON_CNT : integer :=49999999;
constant OFF_CNT : integer :=49999999;
signal trigd_d :std_logic;

begin

led_blink: process(clk)

begin

	if rising_edge(clk) then
	
		trigd_d <= trigd;
		--if trigd rising edge
		if trigd = '1' and trigd_d = '0' then
			begin_blinking <= '1';
		end if;
	
		case blinkState(1 downto 0) is
		
			when A => --IDLE

				led_out <= '0';
				
				if reset = '1' then
					begin_blinking <= '0';
					blinkState <= A;
				elsif begin_blinking = '1' then
					begin_blinking <= '0';
					blinkState <= B;
				else
					blinkState <= A;
				end if;
				
			when B => --LED ON
			
				led_out <= '1';
				
				if reset = '1' then
					begin_blinking <= '0';
					blinkState <= A;
				elsif cnt = ON_CNT then
					cnt <= 0;
					blinkState <= C;
				else
					cnt <= cnt + 1;
					blinkState <= B;
				end if;
			
			when C => --LED OFF

				led_out <= '0';
				
				if reset = '1' then
					begin_blinking <= '0';
					blinkState <= A;				
				elsif cnt = OFF_CNT then
					cnt <= 0;
					blinkState <= A;
				else
					cnt <= cnt + 1;
					blinkState <= C;
				end if;
			
			when others =>
				blinkState <= A;
		
		end case;
		
	end if; --//end rising_edge(clk)
		
end process;

end Behavioral;

