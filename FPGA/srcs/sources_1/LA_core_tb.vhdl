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
use IEEE_PROPOSED.FIXED_PKG.ALL;

entity LA_core_tb is
end LA_core_tb;

architecture Behavioral of LA_core_tb is

    -- Component Declaration for the Unit Under Test (UUT)
    
    component LA_core is
    generic (
        LA_DATA_WIDTH : integer := 12;    -- Data input width
        LA_COUNTER_WIDTH : integer := 16 -- Stage Counter width
    );
    Port (
           clk_in : in std_logic;
           dt_enable : in std_logic;
           dataD : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           digital_trig_mask_0 : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           digital_trig_mask_1 : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           digital_trig_mask_2 : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           digital_trig_mask_3 : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           digital_trig_patternA_0 : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           digital_trig_patternA_1 : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           digital_trig_patternA_2 : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           digital_trig_patternA_3 : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           digital_trig_patternB_0 : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           digital_trig_patternB_1 : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           digital_trig_patternB_2 : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           digital_trig_patternB_3 : in std_logic_vector (LA_DATA_WIDTH-1 downto 0);
           dt_stage_capture : in std_logic_vector (1 downto 0);
           dt_delayMaxcnt_0 : in std_logic_vector (LA_COUNTER_WIDTH-1 downto 0);
           dt_delayMaxcnt_1 : in std_logic_vector (LA_COUNTER_WIDTH-1 downto 0);
           dt_delayMaxcnt_2 : in std_logic_vector (LA_COUNTER_WIDTH-1 downto 0);
           dt_delayMaxcnt_3 : in std_logic_vector (LA_COUNTER_WIDTH-1 downto 0);
           dtSerial : in std_logic;
           dtSerialCh : in std_logic_vector (3 downto 0);
           dt_triggered : out std_logic;
           reset : in std_logic
           );
	end component;
        
	constant LA_DATA_WIDTH : integer := 12;
	constant LA_COUNTER_WIDTH : integer := 16;
    
    --clk and enable signals
    signal clk : std_logic := '0';
    signal dt_enable : std_logic := '0';
    --data
    signal dataD : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal digital_trig_mask_0 : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal digital_trig_mask_1 : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal digital_trig_mask_2 : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal digital_trig_mask_3 : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal digital_trig_patternA_0 : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal digital_trig_patternA_1 : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal digital_trig_patternA_2 : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal digital_trig_patternA_3 : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal digital_trig_patternB_0 : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal digital_trig_patternB_1 : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal digital_trig_patternB_2 : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal digital_trig_patternB_3 : std_logic_vector (LA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal dt_stage_capture : std_logic_vector (1 downto 0) := (others => '0');
    signal dt_delayMaxcnt_0 : std_logic_vector (LA_COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal dt_delayMaxcnt_1 : std_logic_vector (LA_COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal dt_delayMaxcnt_2 : std_logic_vector (LA_COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal dt_delayMaxcnt_3 : std_logic_vector (LA_COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal dtSerial : std_logic := '0';
    signal dtSerialCh : std_logic_vector (3 downto 0) := "0000";
    signal dt_triggered : std_logic := '0';
    signal reset : std_logic := '0';
    
    -- tb signals
    signal dt_triggered_d : std_logic := '0';
    
    -- Clock period definitions
    constant clk_period : time := 4 ns;
    
begin

	-- Instantiate the Unit Under Test (UUT)
	uut: LA_core
	generic map (
        LA_DATA_WIDTH => LA_DATA_WIDTH,
        LA_COUNTER_WIDTH => LA_COUNTER_WIDTH
	)
	port map (
    	clk_in => clk,
    	dt_enable => dt_enable,            
    	dataD => dataD, 
    	digital_trig_mask_0 => digital_trig_mask_0,
    	digital_trig_mask_1 => digital_trig_mask_1,
    	digital_trig_mask_2 => digital_trig_mask_2,
    	digital_trig_mask_3 => digital_trig_mask_3,
    	digital_trig_patternA_0 => digital_trig_patternA_0,
    	digital_trig_patternA_1 => digital_trig_patternA_1,
    	digital_trig_patternA_2 => digital_trig_patternA_2,
    	digital_trig_patternA_3 => digital_trig_patternA_3,
    	digital_trig_patternB_0 => digital_trig_patternB_0,
    	digital_trig_patternB_1 => digital_trig_patternB_1,
    	digital_trig_patternB_2 => digital_trig_patternB_2,
    	digital_trig_patternB_3 => digital_trig_patternB_3,
    	dt_stage_capture => dt_stage_capture,
    	dt_delayMaxcnt_0 => dt_delayMaxcnt_0,
    	dt_delayMaxcnt_1 => dt_delayMaxcnt_1,
    	dt_delayMaxcnt_2 => dt_delayMaxcnt_2,
    	dt_delayMaxcnt_3 => dt_delayMaxcnt_3,
    	dtSerial => dtSerial,
    	dtSerialCh => dtSerialCh,
    	dt_triggered => dt_triggered,
    	reset => reset     
	);

    -- Clock process definitions
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;
 
     -- Digital data generation process
    dig_sig_generate :process
    
        variable cnt : integer range 0 to 1023 := 0;
        
    begin
    
        wait until rising_edge(clk);
        if cnt = 1023 then
            cnt := 0;
        else
            cnt := cnt + 1;
        end if;
        dataD <= std_logic_vector(to_unsigned(cnt,dataD'length));
        
    end process;
     
    -- Stimulus process
    stim_proc: process
        
    begin
    
        for i in 1 to 3 loop
            wait until rising_edge(clk);
        end loop;
		
		digital_trig_patternA_0  <= "000000000100";
		digital_trig_patternB_0  <= "000000001000";
		digital_trig_mask_0      <= "000000001100";
		       
		digital_trig_patternA_1  <= std_logic_vector(to_unsigned(40,12));
		digital_trig_patternB_1  <= std_logic_vector(to_unsigned(40,12));
		digital_trig_mask_1      <= std_logic_vector(to_unsigned(255,12));
		
		digital_trig_patternA_2  <= std_logic_vector(to_unsigned(42,12));
		digital_trig_patternB_2  <= std_logic_vector(to_unsigned(42,12));
		digital_trig_mask_2      <= std_logic_vector(to_unsigned(255,12));

		digital_trig_patternA_3  <= std_logic_vector(to_unsigned(44,12));
		digital_trig_patternB_3  <= std_logic_vector(to_unsigned(44,12));
		digital_trig_mask_3      <= std_logic_vector(to_unsigned(255,12));
		
		dt_delayMaxcnt_0         <= std_logic_vector(to_unsigned(10,16));
		dt_delayMaxcnt_1         <= std_logic_vector(to_unsigned(0,16));
		dt_delayMaxcnt_2         <= std_logic_vector(to_unsigned(0,16));
		dt_delayMaxcnt_3         <= std_logic_vector(to_unsigned(10,16));
				
		dt_stage_capture         <= std_logic_vector(to_unsigned(3,2));
		
        for i in 1 to 3 loop
            wait until rising_edge(clk);
        end loop;
        -- enable digital trigger
        dt_enable <= '1';
		
        for i in 1 to 300 loop
            wait until rising_edge(clk);
            dt_triggered_d <= dt_triggered;
            -- disable digital trigger if LA core asserted dt_triggered
            if dt_triggered_d = '0' and dt_triggered = '1' then
                dt_enable <= '0';
                exit;
            end if;
        end loop;
        
        for i in 1 to 300 loop
            wait until rising_edge(clk);
            dt_triggered_d <= dt_triggered;
            if dt_triggered_d = '0' then
                exit;
            end if;
        end loop;
       
--       --reset LA core 
--        wait until rising_edge(clk);
--        if dt_enable = '1' then
--		  reset <= '1';
--		end if;
--		wait until rising_edge(clk);
--		reset <= '0';

    end process;
       
end;
