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

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY mavg_tb IS
END mavg_tb;
 
ARCHITECTURE behavior OF mavg_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
	component mavg is
    generic (
        MAX_MAVG_LEN_LOG  : integer := 3
    );
    port (
        i_clk         : in  std_logic;
        i_rst         : in  std_logic;
        -- input
        mavg_len_log  : in integer range 0 to MAX_MAVG_LEN_LOG;
        i_data_en     : in  std_logic;
        i_data        : in  std_logic_vector(9 downto 0);
        -- output
        o_data_valid  : out std_logic;
        o_data        : out std_logic_vector(9 downto 0));
	end component;
    
	--constants
	CONSTANT MAX_MAVG_LEN_LOG : integer := 3;
	
    --Inputs
    signal i_clk : std_logic := '0';
    signal i_rst : std_logic := '0';
    signal i_data_en : std_logic := '0';
    signal mavg_len_log : integer range 0 to MAX_MAVG_LEN_LOG :=MAX_MAVG_LEN_LOG;
    signal i_data : std_logic_vector(9 downto 0) := (others => '0');
    
 	 --Outputs
    signal o_data_valid : std_logic;
    signal o_data : std_logic_vector(9 downto 0);
	
   -- Clock period definitions
   constant clk_period : time := 10 ns;
   constant clk_divide_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: mavg
      generic map (MAX_MAVG_LEN_LOG => MAX_MAVG_LEN_LOG) 
      PORT MAP (
          i_clk => i_clk,
          i_rst => i_rst,
          mavg_len_log => mavg_len_log,
          i_data_en => i_data_en,
          i_data => i_data,
          o_data_valid => o_data_valid,
          o_data => o_data
        );

   -- Clock process definitions
   clk_process :process
   begin
		i_clk <= '0';
		wait for clk_period/2;
		i_clk <= '1';
		wait for clk_period/2;
   end process;

   -- Stimulus process
   stim_proc: process
   		variable counter1 : signed (9 downto 0) := to_signed(-12,i_data'length);
		variable counter2 : signed (9 downto 0) := to_signed(-12,i_data'length);
   begin	
		
		i_rst <= '0';
		wait until rising_edge(i_clk);  
		mavg_len_log <= MAX_MAVG_LEN_LOG;
		i_rst <= '1';
		wait until rising_edge(i_clk);  
		i_rst <= '0';
		--generate input data
		while counter1 < to_signed(63,counter1'LENGTH) loop
            wait until rising_edge(i_clk);
            counter1 := counter1 + 2;
            i_data_en <= '1';
            i_data <= std_logic_vector(counter1);
		end loop;
		wait until rising_edge(i_clk);
		i_rst <= '0'; 
		i_data_en <= '0';
   end process;

END;
