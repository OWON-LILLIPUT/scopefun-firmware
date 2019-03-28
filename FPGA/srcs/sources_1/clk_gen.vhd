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

--
-- Scopefun firmware: generate clock outputs for DAC
--


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity clk_gen is
    Port ( clk_in : in std_logic;
           clk_out_0 : out std_logic;
           clk_out_90 : out std_logic;
--           clk_out_270 : out std_logic
           pll_locked : out std_logic
           );
end clk_gen;

architecture Behavioral of clk_gen is

CONSTANT CLKIN_PERIOD : real := 4.000;

-- PLLE2_BASE
signal CLKFBIN : std_logic;
signal CLKFBOUT : std_logic;
signal CLKOUT0 : std_logic;
signal CLKOUT1 : std_logic;
signal CLKOUT2 : std_logic;
signal CLKOUT3 : std_logic;
signal CLKOUT4 : std_logic;
signal CLKOUT5 : std_logic;
signal DO : std_logic_vector(15 downto 0);
signal DRDY : std_logic;

begin

   -- PLLE2_ADV: Advanced Phase Locked Loop (PLL)
   --            Artix-7
   -- Xilinx HDL Language Template, version 2016.2

   PLLE2_ADV_inst: PLLE2_ADV
   generic map (
      BANDWIDTH => "OPTIMIZED",  -- OPTIMIZED, HIGH, LOW
      CLKFBOUT_MULT => 5,        -- Multiply value for all CLKOUT, (2-64)
      CLKFBOUT_PHASE => 0.0,     -- Phase offset in degrees of CLKFB, (-360.000-360.000).
      -- CLKIN_PERIOD: Input clock period in nS to ps resolution (i.e. 33.333 is 30 MHz).
      CLKIN1_PERIOD => CLKIN_PERIOD,
      CLKIN2_PERIOD => 0.0,
      -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT (1-128)
      CLKOUT0_DIVIDE => 5,
      CLKOUT1_DIVIDE => 5,
      CLKOUT2_DIVIDE => 1,
      CLKOUT3_DIVIDE => 1,
      CLKOUT4_DIVIDE => 1,
      CLKOUT5_DIVIDE => 1,
      -- CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT outputs (0.001-0.999).
      CLKOUT0_DUTY_CYCLE => 0.5,
      CLKOUT1_DUTY_CYCLE => 0.5,
      CLKOUT2_DUTY_CYCLE => 0.5,
      CLKOUT3_DUTY_CYCLE => 0.5,
      CLKOUT4_DUTY_CYCLE => 0.5,
      CLKOUT5_DUTY_CYCLE => 0.5,
      -- CLKOUT0_PHASE - CLKOUT5_PHASE: Phase offset for CLKOUT outputs (-360.000-360.000).
      CLKOUT0_PHASE => 0.0,
      CLKOUT1_PHASE => 90.000,
      CLKOUT2_PHASE => 270.000,
      CLKOUT3_PHASE => 0.0,
      CLKOUT4_PHASE => 0.0,
      CLKOUT5_PHASE => 0.0,
      COMPENSATION => "ZHOLD",   -- ZHOLD, BUF_IN, EXTERNAL, INTERNAL
      DIVCLK_DIVIDE => 1,        -- Master division value (1-56)
      -- REF_JITTER: Reference input jitter in UI (0.000-0.999).
      REF_JITTER1 => 0.075,
      REF_JITTER2 => 0.0,
      STARTUP_WAIT => "FALSE"    -- Delay DONE until PLL Locks, ("TRUE"/"FALSE")
   )
   port map (
      -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
      CLKOUT0 => CLKOUT0,   -- 1-bit output: CLKOUT0
      CLKOUT1 => CLKOUT1,   -- 1-bit output: CLKOUT1
      CLKOUT2 => CLKOUT2,   -- 1-bit output: CLKOUT2
      CLKOUT3 => CLKOUT3,   -- 1-bit output: CLKOUT3
      CLKOUT4 => CLKOUT4,   -- 1-bit output: CLKOUT4
      CLKOUT5 => CLKOUT5,   -- 1-bit output: CLKOUT5
      -- DRP Ports: 16-bit (each) output: Dynamic reconfiguration ports
      DO => DO,             -- 16-bit output: DRP data
      DRDY => DRDY,         -- 1-bit output: DRP ready
      -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
      CLKFBOUT => CLKFBOUT, -- 1-bit output: Feedback clock
      LOCKED => pll_locked,     -- 1-bit output: LOCK
      -- Clock Inputs: 1-bit (each) input: Clock inputs
      CLKIN1 => clk_in,     -- 1-bit input: Primary clock (200 Mhz input)
      CLKIN2 => '0',     -- 1-bit input: Secondary clock
      -- Control Ports: 1-bit (each) input: PLL control ports
      CLKINSEL => '1',   -- 1-bit input: Clock select, High=CLKIN1 Low=CLKIN2
      PWRDWN => '0',     -- 1-bit input: Power-down
      RST => '0',           -- 1-bit input: Reset
      -- DRP Ports: 7-bit (each) input: Dynamic reconfiguration ports
      DADDR => "0000000",       -- 7-bit input: DRP address
      DCLK => '0',         -- 1-bit input: DRP clock
      DEN => '0',           -- 1-bit input: DRP enable
      DI => x"0000",             -- 16-bit input: DRP data
      DWE => '0',           -- 1-bit input: DRP write enable
      -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
      CLKFBIN => CLKFBIN    -- 1-bit input: Feedback clock
   );

   -- End of PLLE2_ADV_inst instantiation

-- PLL feedback buffer
    BUFG_inst1: BUFG
    port map (
       I => CLKFBOUT,
       O => CLKFBIN
    );

-- Output 
    clk_out_0_inst: BUFG
    port map (
       I => CLKOUT0,
       O => clk_out_0
    );
  
-- Output 
    clk_out_90_inst: BUFG
    port map (
       I => CLKOUT1,
       O => clk_out_90
    );

---- Output 
--    clk_out_inv: BUFG
--    port map (
--       I => CLKOUT0,
--       O => clk_out_270
--    );


end Behavioral;
