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

entity cordic_par is
    generic (
        bH : integer := 11; -- angle input precision high index
        bL : integer := 0; -- angle input precision low index
		aW : natural := 10 -- number of parallel cordic cores
    );
    Port ( clk : in  std_logic;
			  generatorOn : in std_logic;
	        kot_gen : in sfixed(bH downto bL);
			  q_gen : in std_logic_vector(1 downto 0);
			  y_sin : out  SIGNED (11 downto 0);
              x_cos : out  SIGNED (11 downto 0)           
           );
			  
attribute use_dsp48: string;
--attribute use_dsp48 of fpga : entity is "automax";

end cordic_par;

architecture Behavioral of cordic_par is

-- CORDIC signals --
signal q_gen_d : std_logic_vector(1 downto 0);
signal q_gen_2d : std_logic_vector(1 downto 0);
signal q_gen_3d : std_logic_vector(1 downto 0);
signal q_gen_4d : std_logic_vector(1 downto 0);
signal q_gen_5d : std_logic_vector(1 downto 0);
signal q_gen_6d : std_logic_vector(1 downto 0);
signal q_gen_7d : std_logic_vector(1 downto 0);
signal q_gen_8d : std_logic_vector(1 downto 0);
signal q_gen_9d : std_logic_vector(1 downto 0);
signal q_gen_10d : std_logic_vector(1 downto 0);
signal q_gen_11d : std_logic_vector(1 downto 0);
signal q_gen_12d : std_logic_vector(1 downto 0);
signal q_gen_13d : std_logic_vector(1 downto 0);

signal kot_gen_d : sfixed(bH downto bL);
signal kot_gen_dd : sfixed(bH downto bL);

TYPE kot_mem IS ARRAY (0 to aW) of sfixed(bH downto bL);
signal kot : kot_mem := (others=> to_sfixed(0,bH,bL));
TYPE kot_temp_mem IS ARRAY (0 to aW) of sfixed(bH+1 downto bL);
signal kot_temp : kot_temp_mem := (others=> to_sfixed(0,bH+1,bL));
signal sin_core : SIGNED (11 downto 0);
signal cos_core : SIGNED (11 downto 0);
signal sin_tmp : SIGNED (11 downto 0);
signal cos_tmp : SIGNED (11 downto 0);
TYPE cnt_cordic_mem IS ARRAY (0 to aW) of INTEGER range 0 to aW;
signal cnt_cordic : cnt_cordic_mem := (10,9,8,7,6,5,4,3,2,1,others =>0);
TYPE quadrant_mem IS ARRAY (0 to aW)of std_logic_vector(1 downto 0);
signal quadrant: quadrant_mem := (others=>"00");
TYPE Y_mem IS ARRAY (0 to aW) of SIGNED (11 downto 0);
signal Y: Y_mem := (others=>"000000000000");
TYPE X_mem IS ARRAY (0 to aW) of SIGNED (11 downto 0);
signal X: X_mem := (others=>"010011011011");
signal cordic_begin : integer range 0 to 1:=0;

-- ATAN(1/(2^i))*2047.999/(pi/2) <-- lookup table is normalized (pi/2 = 2047.999)
TYPE da_mem IS ARRAY (0 to 10) OF sfixed(bH downto bL); 
CONSTANT da : da_mem := (
to_sfixed( 1023.5000 ,bH,bL),
to_sfixed(  604.2073 ,bH,bL),
to_sfixed(  319.2466 ,bH,bL),
to_sfixed(  162.0545 ,bH,bL),
to_sfixed(   81.3417 ,bH,bL),
to_sfixed(   40.7105 ,bH,bL),
to_sfixed(   20.3602 ,bH,bL),
to_sfixed(   10.1807 ,bH,bL),
to_sfixed(    5.0904 ,bH,bL),
to_sfixed(    2.5452 ,bH,bL),
to_sfixed(    1.2726 ,bH,bL)
);    

begin

sin_generator: process(clk)

   TYPE dx_mem IS ARRAY (0 to aW) of SIGNED (11 downto 0);
   variable dx: dx_mem := (others=>"000000000000");
   TYPE dy_mem IS ARRAY (0 to aW) of SIGNED (11 downto 0);
   variable dy: dx_mem := (others=>"000000000000");
   
begin

   if (rising_edge(clk)) then
	   
		if generatorOn = '1' then
		
			-- register inputs
			kot_gen_d <= kot_gen;
			q_gen_d <= q_gen;
			-- delay q_gen
			q_gen_2d <= q_gen_d;
			q_gen_3d <= q_gen_2d;
			q_gen_4d <= q_gen_3d;
			q_gen_5d <= q_gen_4d;
			q_gen_6d <= q_gen_5d;
			q_gen_7d <= q_gen_6d;
			q_gen_8d <= q_gen_7d;
			q_gen_9d <= q_gen_8d;
			q_gen_10d <= q_gen_9d;
			q_gen_11d <= q_gen_10d;
			q_gen_12d <= q_gen_11d;
			q_gen_13d <= q_gen_12d;
            			
			-- create aW-bit fully pipelined cordic from aW-parallel cordic cores
			for i in 0 to aW loop
				if ( cnt_cordic(i) = aW ) then
					-- each parallel cordic routine calculates sin and cos after aW clk cycles
                    sin_core <= Y(i);
                    cos_core <= X(i);
					kot(i) <= kot_gen_d(bH downto bL); -- use bH-bL precision for angle calculations
					cnt_cordic(i) <= 0;
					kot_temp(i) <= to_sfixed(0,bH+1,bL);
					X(i) <= "010011011011"; --X=0.60725296*2048=1243 ---> will converge to X=cos(kot)
					Y(i) <= "000000000000"; --Y=0                    ---> will converge to Y=sin(kot)
				else
					dx(i) := shift_right(X(i),cnt_cordic(i));
					dy(i) := shift_right(Y(i),cnt_cordic(i));
					if( kot_temp(i) > kot(i) ) then
						X(i) <= X(i) + dy(i);
						Y(i) <= Y(i) - dx(i);
						kot_temp(i) <= resize(kot_temp(i) - da(cnt_cordic(i)),bH+1,bL);
					else
						X(i) <= X(i) - dy(i);
						Y(i) <= Y(i) + dx(i);
						kot_temp(i) <= resize(kot_temp(i) + da(cnt_cordic(i)),bH+1,bL);
					end if;
					cnt_cordic(i) <= cnt_cordic(i) + 1;
				end if;
			end loop;
			
			if q_gen_13d = "00" then
                sin_tmp <= sin_core;   --  0 ->  1
                cos_tmp <= cos_core;   --  1 ->  0
            elsif q_gen_13d = "01" then
                sin_tmp <= cos_core;   --  1 ->  0
                cos_tmp <= -sin_core;  --  0 -> -1
            elsif q_gen_13d = "10" then
                sin_tmp <= -sin_core;  --  0 -> -1
                cos_tmp <= -cos_core;  -- -1 ->  0
            elsif q_gen_13d = "11" then
                sin_tmp <= -cos_core;  -- -1 ->  0
                cos_tmp <= sin_core;   --  0 ->  1
            end if;
            
			-- register inputs
			y_sin <= sin_tmp;
			x_cos <= cos_tmp;
		
		end if;
     
   end if;
   
end process;

end Behavioral;