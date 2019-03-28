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

  LIBRARY ieee;
  USE ieee.std_logic_1164.ALL;
  USE ieee.numeric_std.ALL;

	library IEEE_PROPOSED;
	use ieee_proposed.fixed_float_types.all;
	use ieee_proposed.fixed_pkg.all;

  ENTITY cordic_par_tb IS
  END cordic_par_tb;

  ARCHITECTURE behavior OF cordic_par_tb IS 

  -- Component Declaration
      COMPONENT cordic_par is
			generic (
					bH : integer := 11; -- angle input precision high index
					bL : integer := 0 -- angle input precision low index
			);
			PORT(
				clk : in  std_logic;
				generatorOn : in std_logic;
				kot_gen : in sfixed(bH downto bL);
				q_gen : in std_logic_vector(1 downto 0);
				y_sin : out  SIGNED (11 downto 0);
				x_cos : out  SIGNED (11 downto 0)
          );
          END COMPONENT;

        --constants
        CONSTANT bH : integer := 11;
        CONSTANT bL : integer := 0;
        
        -- inputs
        SIGNAL clk:  std_logic;
        SIGNAL generatorOn :  std_logic;
        -- ANGLE GENERATOR SIGNALS ---
        signal kot_gen : sfixed(bH downto bL):=to_sfixed(0,bH,bL);        
        signal kot_gen_tmp : sfixed(bH downto 0);
        signal q_gen : std_logic_vector(1 downto 0):="00";
        signal q_gen_tmp : std_logic_vector(1 downto 0);
        -- outputs
        signal y_sin : SIGNED (11 downto 0);
        signal x_cos : SIGNED (11 downto 0);
        
        -- signals
        signal curr_angle : sfixed(bH downto bL):=to_sfixed(0,bH,bL);
        signal next_angle : sfixed(bH downto bL):=to_sfixed(0,bH,bL);
        signal quadrant : integer range 0 to 3:=0;
        signal quadrant_d : integer range 0 to 3:=0;
        
        -- Clock period definitions
        constant clk_period : time := 10 ns;
            
  BEGIN

  -- Component Instantiation
          uut: cordic_par PORT MAP(
                  clk => clk,
                  generatorOn => generatorOn,
						kot_gen => kot_gen,
						q_gen => q_gen,
						y_sin => y_sin,
						x_cos => x_cos
          );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
	
  --  Test Bench Statements
     tb : PROCESS
     BEGIN

        wait for 5*clk_period;
        
		generatorOn <= '1';

		wait for 20*clk_period; -- wait until global set/reset completes
		
			for i in 0 to 16*2047 loop
			
				wait for clk_period; -- wait 1 clk cycle
				
                kot_gen_tmp <= '0' & next_angle(bH-1 downto 0);   -- angle output (-2047 to 2047)
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
           
               curr_angle <= resize( arg => curr_angle + to_sfixed(1,bH,bL),
                                               left_index => bH,
                                               right_index => bL,
                                               overflow_style => fixed_wrap);
               next_angle <= curr_angle;
				
			end loop;
        -- Add user defined stimulus here

        wait; -- will wait forever
     END PROCESS tb;
  --  End Test Bench 

  END;
