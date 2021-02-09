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

entity awg_core_tb is
end awg_core_tb;

architecture Behavioral of awg_core_tb is

    -- Component Declaration for the Unit Under Test (UUT)
    
    component awg_core is
    generic (
        bH : integer := 14; -- angle input precision high index
        bL : integer := -17 -- angle input precision low index
    );
    Port (
        clk_in : in  STD_LOGIC;
        generator1On : in STD_LOGIC;
        generator2On : in STD_LOGIC;
        phase_sync : in STD_LOGIC;
        phase_val : in STD_LOGIC_VECTOR(bH downto 0);        
        --AWG1
        genSignal_1     : out signed (11 downto 0);
        ram_addrb_awg_1 : out STD_LOGIC_VECTOR (14 downto 0);
        generatorType_1 : in  STD_LOGIC_VECTOR (3 downto 0);
        generatorVoltage_1 : in  sfixed(0 downto -11);
        generatorOffset_1 : in  SIGNED (11 downto 0);
        generatorDuty_1 : in  signed(11 downto 0);
        generatorDelta_1 : in  STD_LOGIC_VECTOR(bH-bL downto 0);
        generatorCustomSample_1 : in  STD_LOGIC_VECTOR (11 downto 0);
        --AWG2
        genSignal_2     : out signed (11 downto 0);
        ram_addrb_awg_2 : out STD_LOGIC_VECTOR (14 downto 0);
        generatorType_2 : in  STD_LOGIC_VECTOR (3 downto 0);
        generatorVoltage_2 : in  sfixed(0 downto -11);
        generatorOffset_2 : in  SIGNED (11 downto 0);
        generatorDuty_2 : in  signed(11 downto 0);
        generatorDelta_2 : in  STD_LOGIC_VECTOR(bH-bL downto 0);
        generatorCustomSample_2 : in  STD_LOGIC_VECTOR (11 downto 0);
        --DAC programming signals
        dac_data_1 : out STD_LOGIC_VECTOR (11 downto 0);
        dac_data_2 : out STD_LOGIC_VECTOR (11 downto 0);
        dac_clk : out STD_LOGIC
        );
    end component;
    
    component se_to_ddr is
    Port ( i_clk : in std_logic;
           o_clk : out std_logic;
           o_clk_inv  : out std_logic;
           i_data_1 : in std_logic_vector (11 downto 0);
           i_data_2 : in std_logic_vector (11 downto 0);
           o_data_ddr : out std_logic_vector (11 downto 0));
    end component;
    
    constant bH : integer := 14; -- angle input precision high index
    constant bL : integer := -17; -- angle input precision low index
    
    --clk and enable signals
    signal clk : std_logic := '0';
    signal generator1On : std_logic := '0';
    signal generator2On : std_logic := '0';
    signal phase_sync : STD_LOGIC := '0';
    signal phase_val : STD_LOGIC_VECTOR(bH downto 0):=std_logic_vector(to_signed(0,bH+1));
    signal phase_val_tmp : STD_LOGIC_VECTOR(bH downto 0):=std_logic_vector(to_signed(0,bH+1));
    
    --AWG1
	signal genSignal_1     			: signed (11 downto 0);
    signal ram_addrb_awg_1          : STD_LOGIC_VECTOR (14 downto 0);
    signal generatorType_1          : STD_LOGIC_VECTOR (3 downto 0) := std_logic_vector(to_unsigned(0,4));
    signal generatorVoltage_1       : sfixed(0 downto -11):="011111111111";
    signal generatorOffset_1        : SIGNED (11 downto 0):="000000000000";
    signal generatorDuty_1          : signed(11 downto 0):="000000000000";
    signal generatorDelta_1         : STD_LOGIC_VECTOR(bH-bL downto 0):=std_logic_vector(to_unsigned(0,bH-bL+1));
    signal generatorCustomSample_1  : STD_LOGIC_VECTOR (11 downto 0):="000000000000";
    --AWG2
    signal genSignal_2              : signed (11 downto 0);
    signal ram_addrb_awg_2          : STD_LOGIC_VECTOR (14 downto 0);
    signal generatorType_2          : STD_LOGIC_VECTOR (3 downto 0) := std_logic_vector(to_unsigned(0,4));
    signal generatorVoltage_2       : sfixed(0 downto -11):="011111111111";
    signal generatorOffset_2        : SIGNED (11 downto 0):="000000000000";
    signal generatorDuty_2          : signed(11 downto 0):="000000000000";
    signal generatorDelta_2         : STD_LOGIC_VECTOR(bH-bL downto 0):=std_logic_vector(to_unsigned(0,bH-bL+1));
    signal generatorCustomSample_2  : STD_LOGIC_VECTOR (11 downto 0):="000000000000";
    --DAC programming signals
    signal dac_data_1               : STD_LOGIC_VECTOR (11 downto 0);
    signal dac_data_2               : STD_LOGIC_VECTOR (11 downto 0);
    signal dac_clk                  : STD_LOGIC;
    
    --DAC interface
    signal dac_clk_1 : std_logic := '0';
    signal dac_clk_2 : std_logic := '0';
    signal dac_data : std_logic_vector (11 downto 0);
    
    -- Clock period definitions
    constant clk_period : time := 5 ns;
    
begin

	-- Instantiate the Unit Under Test (UUT)
	uut: awg_core
	generic map (
        bH => bH,
        bL => bL
	)
	port map (
        clk_in                  =>  clk,
        generator1On            =>  generator1On,
        generator2On            =>  generator2On,
        phase_sync              =>  phase_sync,
        phase_val               =>  phase_val,
        genSignal_1     	    =>  genSignal_1,
        ram_addrb_awg_1         =>  ram_addrb_awg_1,
        generatorType_1         =>  generatorType_1,
        generatorVoltage_1      =>  generatorVoltage_1,
        generatorOffset_1       =>  generatorOffset_1,
        generatorDuty_1         =>  generatorDuty_1,
        generatorDelta_1        =>  generatorDelta_1,
        generatorCustomSample_1 =>  generatorCustomSample_1,
        genSignal_2             =>  genSignal_2,
        ram_addrb_awg_2         =>  ram_addrb_awg_2,
        generatorType_2         =>  generatorType_2,
        generatorVoltage_2      =>  generatorVoltage_2,
        generatorOffset_2       =>  generatorOffset_2,
        generatorDuty_2         =>  generatorDuty_2,
        generatorDelta_2        =>  generatorDelta_2,
        generatorCustomSample_2 =>  generatorCustomSample_2,
        dac_data_1              =>  dac_data_1,
        dac_data_2              =>  dac_data_2,
        dac_clk                 =>  dac_clk          
	);
	
	dac_interface: se_to_ddr
    port map (
            i_clk => dac_clk,
            o_clk => dac_clk_1,
            o_clk_inv => dac_clk_2,
            i_data_1 => dac_data_1,
            i_data_2 => dac_data_2,
            o_data_ddr => dac_data
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
    
        wait until rising_edge(clk);
        --initialise awg_core signals
        phase_sync <= '0';
--        phase_val <= std_logic_vector(to_unsigned(1000000000,bH-bL+1));
        phase_val <= std_logic_vector(to_signed(-8382,bH+1));
        wait until rising_edge(clk);
        
        generator1On <= '1';
        generatorDelta_1 <= std_logic_vector(to_unsigned(100000000,bH-bL+1));
        generatorDelta_2 <= std_logic_vector(to_unsigned(100000000,bH-bL+1));
        generatorType_1 <= std_logic_vector(to_unsigned(3,4));
        generatorType_2 <= std_logic_vector(to_unsigned(3,4));
        generatorDuty_1 <= "000000000000";
        generatorDuty_2 <= to_signed(50,12);
        
        for i in 1 to 100 loop
            wait until rising_edge(clk);
        end loop;
        generator2On <= '1';
        for i in 1 to 200 loop
            wait until rising_edge(clk);
        end loop;
        phase_sync <= '1';
        wait until rising_edge(clk);
        for i in 1 to 1500 loop
            wait until rising_edge(clk);
        end loop;
        phase_sync <= '0';
        
    end process;
       
end;
