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
library IEEE_PROPOSED;
use ieee_proposed.fixed_float_types.all;
use ieee_proposed.fixed_pkg.all;

entity angle_gen is
    generic (
        bH : integer := 14; -- angle input precision high index
        bL : integer := -17 -- angle input precision low index
    );
    Port ( clk : in STD_LOGIC;
			 clk_en : in STD_LOGIC;
	 generatorDelta : in sfixed(bH downto bL);
	        kot_gen : out sfixed(bH downto 0);
			  q_gen : out std_logic_vector(1 downto 0)
			  );
			  
attribute use_dsp48: string;
--attribute use_dsp48 of angle_gen : entity is "automax";

end angle_gen;

architecture Behavioral of angle_gen is

-- ANGLE GENERATOR SIGNALS ---
signal q_gen_tmp : std_logic_vector(1 downto 0):="00";
signal kot_gen_tmp : sfixed(bH downto 0):=to_sfixed(0,bH,0);
signal kot_g : sfixed(bH downto bL):=to_sfixed(0,bH,bL);

signal curr_angle : sfixed(bH downto bL):=to_sfixed(0,bH,bL);
signal next_angle : sfixed(bH downto bL):=to_sfixed(0,bH,bL);

signal quadrant : integer range 0 to 3 := 0;
signal generatorDelta_d : sfixed(bH downto bL):=to_sfixed(0,bH,bL);
signal generatorDelta_dd : sfixed(bH downto bL):=to_sfixed(0,bH,bL);

signal init_complete : std_logic:='0';

-- attribute strings
attribute KEEP: boolean;
attribute ASYNC_REG: boolean;
attribute mark_debug: boolean;

attribute KEEP of generatorDelta_d: signal is true; 
attribute ASYNC_REG of generatorDelta_d: signal is true; 
attribute KEEP of generatorDelta_dd: signal is true; 
attribute ASYNC_REG of generatorDelta_dd: signal is true; 

begin

--angle generator outputs

--angle generator core process
angle_generator: process(clk)


begin

   if (rising_edge(clk)) then	
	
		if clk_en = '1' then
		
			-- register inputs
			generatorDelta_d <= generatorDelta;
			generatorDelta_dd <= generatorDelta_d;
						
            kot_gen_tmp <= '0' & next_angle(bH-1 downto 0);   -- angle output (0 to 2047)
            kot_gen <= kot_gen_tmp;
            q_gen_tmp <= std_logic_vector(to_unsigned(quadrant,2));
            q_gen <= q_gen_tmp;           
       
            if (curr_angle(bH) = '1' and next_angle(bH)='0') or
               (curr_angle(bH) = '0' and next_angle(bH)='1') then
                  if quadrant = 3 then
                       quadrant <= 0;
                  else
                       quadrant <= quadrant + 1;
                  end if;
            end if;
       
           curr_angle <= resize( arg => curr_angle + generatorDelta_dd,
                                           left_index => bH,
                                           right_index => bL,
                                           overflow_style => fixed_wrap); -- start from 0 if overflow
           next_angle <= curr_angle;
     
      end if;
			
	end if;

end process;
	
end Behavioral;