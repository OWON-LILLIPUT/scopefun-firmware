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

entity PWM is
    generic (
        pwm_precision : integer := 10 -- pwm input precision
    );
    Port ( clk : in  STD_LOGIC;
           v_set : in  STD_LOGIC_VECTOR (pwm_precision-1 downto 0);
           pwm_out : out  STD_LOGIC);
end PWM;

architecture Behavioral of PWM is

signal cnt_i: unsigned(pwm_precision-1 downto 0);
signal pwm_out_i: std_logic;

begin

pwm_out <= pwm_out_i;
		
pwm_generator: process(clk)
	
   begin
           
		if (rising_edge(clk)) then 
		
			cnt_i <= cnt_i + 1;
			
			if cnt_i < unsigned(v_set) then
				pwm_out_i <= '1';
			else
				pwm_out_i <= '0';
			end if;
		
		end if;
		
end process;

end Behavioral;

