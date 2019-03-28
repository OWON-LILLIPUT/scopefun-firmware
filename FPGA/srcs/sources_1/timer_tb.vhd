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
 
ENTITY timer_tb IS
END timer_tb;
 
ARCHITECTURE behavior OF timer_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT timer
    PORT(
         clk : IN  std_logic;
         t_reset : IN  std_logic;
         t_start : IN  std_logic;
         holdoff : IN  std_logic_vector(31 downto 0);
         o_end : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal t_reset : std_logic := '0';
   signal t_start : std_logic := '0';
   signal holdoff : std_logic_vector(31 downto 0) := (others => '0');

 	--Outputs
   signal o_end : std_logic;

   -- Clock period definitions
   constant clk_period : time := 4 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: timer PORT MAP (
          clk => clk,
          t_reset => t_reset,
          t_start => t_start,
          holdoff => holdoff,
          o_end => o_end
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait until rising_edge(clk);
			holdoff <= std_logic_vector(to_unsigned(1,32));
			t_start <= '1';
	  wait until rising_edge(clk);
            t_start <= '0';
      for i in 1 to 15 loop
            wait until rising_edge(clk);
      end loop;
      wait;
   end process;

END;
