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
-- Scopefun firmware: DDR interface for DAC
--


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;


entity se_to_ddr is
    Port ( i_clk : in std_logic;
           o_clk : out std_logic;
           o_clk_inv  : out std_logic;
           i_data_1 : in std_logic_vector (11 downto 0);
           i_data_2 : in std_logic_vector (11 downto 0);
           o_data_ddr : out std_logic_vector (11 downto 0);
           pll_locked : out std_logic
           );
end se_to_ddr;

architecture Behavioral of se_to_ddr is

signal i_clk_0 : std_logic;
signal i_clk_90 : std_logic;
signal i_pll_locked : std_Logic;

component clk_gen is
    Port ( clk_in : in std_logic;
           clk_out_0 : out std_logic;
           clk_out_90 : out std_logic;
           pll_locked : out std_logic
           );
end component;

begin

generate_out_clk_inst: clk_gen
    port map ( 
        clk_in => i_clk,
        clk_out_0 => i_clk_0,
        clk_out_90 => i_clk_90,
--        clk_out_270 => i_clk_270
        pll_locked => pll_locked
        );

-- use ODDR primitive to output adc_clock_1 with 90 phase relative to the i_clk
ODDR_CLK: ODDR
	generic map(
		DDR_CLK_EDGE => "SAME_EDGE", -- Sets input alignment
		INIT => '0',      -- Sets initial state of the Q output to '0' or '1'
		SRTYPE => "SYNC") -- Specifies "SYNC" or "ASYNC" set/reset
	port map (
		Q => o_clk,        -- 1-bit output clock
		C => i_clk_90,     -- 1-bit clock input
		CE => '1', -- 1-bit clock enable input
		D1 => '0', -- 1-bit data input
		D2 => '1', -- 1-bit data input
		R => '0'  -- 1-bit reset input
		);

-- use ODDR primitive to output the adc_clock_2 with 270 phase relative to the i_clk
ODDR_CLK_inverted: ODDR
	generic map(
		DDR_CLK_EDGE => "SAME_EDGE", -- Sets input alignment
		INIT => '1',      -- Sets initial state of the Q output to '0' or '1'
		SRTYPE => "SYNC") -- Specifies "SYNC" or "ASYNC" set/reset
	port map (
		Q => o_clk_inv,   -- 1-bit output clock (inverted)
		C => i_clk_90,    -- 1-bit clock input
		CE => '1', -- 1-bit clock enable input
		D1 => '1', -- 1-bit data input
		D2 => '0', -- 1-bit data input
		R => '0'   -- 1-bit reset input
		);

-- output data from ODDR in phase with i_clk
GEN: for i in 0 to 11 generate
	ODDR_data : ODDR
	generic map(
		DDR_CLK_EDGE => "SAME_EDGE", -- Sets input alignment
		INIT => '0',      -- Sets initial state of the Q output to '0' or '1'
		SRTYPE => "SYNC") -- Specifies "SYNC" or "ASYNC" set/reset
	port map (
		Q => o_data_ddr(i), -- 1-bit output data
		C => i_clk,  -- 1-bit clock input
		CE => '1',   -- 1-bit clock enable input
		D1 => i_data_1 (11-i), -- adc_data_1 is mapped to DAC channel IOUT_B which is connected on pcb to AWG1
		D2 => i_data_2 (i),    -- adc_data_2 is mapped to DAC channel IOUT_A which is connected on pcb to AWG2
		                       -- note that bit order is reversed (11-i) for simpler routing of pcb traces
		R => '0'     -- 1-bit reset input
		);
end generate GEN;

end Behavioral;
