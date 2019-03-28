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
library UNISIM;
use UNISIM.VComponents.all;

entity lut_delay is
    Port (  clk : in  STD_LOGIC;
			rst : in STD_LOGIC;
            an_trig_p : in STD_LOGIC;
            an_trig_n : in STD_LOGIC;
		    an_trig_d : out STD_LOGIC;
            tap_reg_out : out  STD_LOGIC_VECTOR (31 downto 0));
end lut_delay;

architecture Behavioral of lut_delay is
	
	component LUT6
		generic (
			INIT : bit_vector (63 downto 0):= X"0000000000000001"
		); -- LUT Contents
		port (
			O : out std_logic; -- LUT general output
			I0 : in std_logic; -- LUT input I0
			I1 : in std_logic; -- LUT input I1
			I2 : in std_logic; -- LUT input I2
			I3 : in std_logic; -- LUT input I3
			I4 : in std_logic; -- LUT input I4
			I5 : in std_logic  -- LUT input I5
		);
	end component;

	component FDRE
		generic ( 
			INIT : bit := '0' );
		port(
			Q : out std_logic;
			C : in std_logic;
			CE : in std_logic;
			D : in std_logic;
			R : in std_logic 	
		);
	end component;

    -- attribute strings
    attribute KEEP: boolean;
    attribute ASYNC_REG: boolean;
    
    signal an_trig: std_logic;

	signal LUT6_I: std_logic_vector(32 downto 0);
	signal FDRE0_Q: std_logic_vector(31 downto 0);
	signal FDRE1_Q: std_logic_vector(31 downto 0);
	
	attribute keep of LUT6_I: signal is true;
	attribute keep of FDRE0_Q: signal is true;
	attribute keep of FDRE1_Q: signal is true;

    -- assign KEEP & ASYNC attributes
    attribute KEEP of an_trig: signal is true;
    attribute KEEP of an_trig_d: signal is true;
    attribute ASYNC_REG of an_trig_d: signal is true;

begin
    
    --analog trigger buffer - diff to se
an_trig_buff_inst: IBUFDS
generic map (
   DIFF_TERM => FALSE,   -- Differential Termination 
   IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
   IOSTANDARD => "LVDS_25")
port map (
   O => an_trig,
   I => an_trig_p,
   IB => an_trig_n
);
    
    -- propagate an_trig through a tapped lut chain
    -- each lut delays input signal
    -- signal from lut taps is sampled with clk input into a chain of flops
    -- flop outputs are sampled with another chain of flops
     
	LUT6_I(0) <= an_trig;
		
	--Invert odd flops output
	invert_output: for i in 0 to 31 generate
		inverted: if (i rem 2) = 0 generate
			tap_reg_out(i) <= not FDRE1_Q(i);
		end generate;
		
		straight: if (i rem 2) /= 0 generate
			tap_reg_out(i) <= FDRE1_Q(i);
		end generate;
	end generate;
	
	-- LUT6: 6-input Look-Up Table with general output
	-- Spartan-6
	-- Xilinx HDL Libraries Guide, version 12.4
	LUT_0 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(1), -- LUT general output
	I0 => LUT6_I(0), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);
	
	LUT_1 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(2), -- LUT general output
	I0 => LUT6_I(1), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_2 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(3), -- LUT general output
	I0 => LUT6_I(2), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_3 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(4), -- LUT general output
	I0 => LUT6_I(3), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_4 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(5), -- LUT general output
	I0 => LUT6_I(4), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_5 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(6), -- LUT general output
	I0 => LUT6_I(5), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);	

	LUT_6 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(7), -- LUT general output
	I0 => LUT6_I(6), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);
	
	LUT_7 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(8), -- LUT general output
	I0 => LUT6_I(7), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_8 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(9), -- LUT general output
	I0 => LUT6_I(8), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_9 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(10), -- LUT general output
	I0 => LUT6_I(9), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_10 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(11), -- LUT general output
	I0 => LUT6_I(10), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_11 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(12), -- LUT general output
	I0 => LUT6_I(11), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_12 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(13), -- LUT general output
	I0 => LUT6_I(12), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);
	
	LUT_13 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(14), -- LUT general output
	I0 => LUT6_I(13), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_14 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(15), -- LUT general output
	I0 => LUT6_I(14), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_15 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(16), -- LUT general output
	I0 => LUT6_I(15), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_16 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(17), -- LUT general output
	I0 => LUT6_I(16), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_17 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(18), -- LUT general output
	I0 => LUT6_I(17), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_18 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(19), -- LUT general output
	I0 => LUT6_I(18), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_19 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(20), -- LUT general output
	I0 => LUT6_I(19), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_20 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(21), -- LUT general output
	I0 => LUT6_I(20), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_21 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(22), -- LUT general output
	I0 => LUT6_I(21), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_22 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(23), -- LUT general output
	I0 => LUT6_I(22), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_23 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(24), -- LUT general output
	I0 => LUT6_I(23), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_24 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(25), -- LUT general output
	I0 => LUT6_I(24), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_25 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(26), -- LUT general output
	I0 => LUT6_I(25), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_26 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(27), -- LUT general output
	I0 => LUT6_I(26), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_27 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(28), -- LUT general output
	I0 => LUT6_I(27), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_28 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(29), -- LUT general output
	I0 => LUT6_I(28), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_29 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(30), -- LUT general output
	I0 => LUT6_I(29), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_30 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(31), -- LUT general output
	I0 => LUT6_I(30), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	LUT_31 : LUT6
	generic map (
	INIT => X"0000000000000001") -- Specify LUT Contents
	port map (
	O => LUT6_I(32), -- LUT general output
	I0 => LUT6_I(31), -- LUT input I0
	I1 => '0', -- LUT input I1
	I2 => '0', -- LUT input I2
	I3 => '0', -- LUT input I3
	I4 => '0', -- LUT input I4
	I5 => '0'  -- LUT input I5
	);

	-- FDRE: Single Data Rate D Flip-Flop with Synchronous Reset and
	-- Clock Enable (posedge clk).
	-- Spartan-6
	-- Xilinx HDL Libraries Guide, version 12.4
	FDRE0_inst_0 : FDRE
	generic map (
	INIT => '0') -- Initial value of register (’0’ or ’1’)
	port map (
	D => LUT6_I(1), -- Data input
	Q => FDRE0_Q(0), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE0_inst_1 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(2), -- Data input
	Q => FDRE0_Q(1), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE0_inst_2 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(3), -- Data input
	Q => FDRE0_Q(2), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE0_inst_3 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(4), -- Data input
	Q => FDRE0_Q(3), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE0_inst_4 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(5), -- Data input
	Q => FDRE0_Q(4), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE0_inst_5 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(6), -- Data input
	Q => FDRE0_Q(5), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE0_inst_6 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(7), -- Data input
	Q => FDRE0_Q(6), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE0_inst_7 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(8), -- Data input
	Q => FDRE0_Q(7), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE0_inst_8 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(9), -- Data input
	Q => FDRE0_Q(8), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE0_inst_9 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(10), -- Data input
	Q => FDRE0_Q(9), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
	
	FDRE0_inst_10 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(11), -- Data input
	Q => FDRE0_Q(10), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
	
	FDRE0_inst_11 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(12), -- Data input
	Q => FDRE0_Q(11), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_12 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(13), -- Data input
	Q => FDRE0_Q(12), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_13 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(14), -- Data input
	Q => FDRE0_Q(13), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_14 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(15), -- Data input
	Q => FDRE0_Q(14), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_15 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(16), -- Data input
	Q => FDRE0_Q(15), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_16 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(17), -- Data input
	Q => FDRE0_Q(16), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_17 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(18), -- Data input
	Q => FDRE0_Q(17), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_18 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(19), -- Data input
	Q => FDRE0_Q(18), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_19 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(20), -- Data input
	Q => FDRE0_Q(19), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_20 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(21), -- Data input
	Q => FDRE0_Q(20), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_21 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(22), -- Data input
	Q => FDRE0_Q(21), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_22 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(23), -- Data input
	Q => FDRE0_Q(22), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_23 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(24), -- Data input
	Q => FDRE0_Q(23), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_24 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(25), -- Data input
	Q => FDRE0_Q(24), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_25 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(26), -- Data input
	Q => FDRE0_Q(25), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_26 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(27), -- Data input
	Q => FDRE0_Q(26), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
	
	FDRE0_inst_27 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(28), -- Data input
	Q => FDRE0_Q(27), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_28 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(29), -- Data input
	Q => FDRE0_Q(28), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_29 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(30), -- Data input
	Q => FDRE0_Q(29), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_30 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(31), -- Data input
	Q => FDRE0_Q(30), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE0_inst_31 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => LUT6_I(32), -- Data input
	Q => FDRE0_Q(31), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	--Second stage flops--
	
	FDRE1_inst_0 : FDRE
	generic map (
	INIT => '0') -- Initial value of register (’0’ or ’1’)
	port map (
	D => FDRE0_Q(0), -- Data input
	Q => FDRE1_Q(0), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE1_inst_1 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(1), -- Data input
	Q => FDRE1_Q(1), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE1_inst_2 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(2), -- Data input
	Q => FDRE1_Q(2), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE1_inst_3 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(3), -- Data input
	Q => FDRE1_Q(3), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE1_inst_4 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(4), -- Data input
	Q => FDRE1_Q(4), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE1_inst_5 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(5), -- Data input
	Q => FDRE1_Q(5), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE1_inst_6 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(6), -- Data input
	Q => FDRE1_Q(6), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE1_inst_7 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(7), -- Data input
	Q => FDRE1_Q(7), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE1_inst_8 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(8), -- Data input
	Q => FDRE1_Q(8), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);

	FDRE1_inst_9 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(9), -- Data input
	Q => FDRE1_Q(9), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
	
	FDRE1_inst_10 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(10), -- Data input
	Q => FDRE1_Q(10), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
	
	FDRE1_inst_11 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(11), -- Data input
	Q => FDRE1_Q(11), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_12 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(12), -- Data input
	Q => FDRE1_Q(12), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_13 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(13), -- Data input
	Q => FDRE1_Q(13), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_14 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(14), -- Data input
	Q => FDRE1_Q(14), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_15 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(15), -- Data input
	Q => FDRE1_Q(15), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_16 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(16), -- Data input
	Q => FDRE1_Q(16), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_17 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(17), -- Data input
	Q => FDRE1_Q(17), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_18 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(18), -- Data input
	Q => FDRE1_Q(18), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_19 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(19), -- Data input
	Q => FDRE1_Q(19), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_20 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(20), -- Data input
	Q => FDRE1_Q(20), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_21 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(21), -- Data input
	Q => FDRE1_Q(21), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_22 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(22), -- Data input
	Q => FDRE1_Q(22), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_23 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(23), -- Data input
	Q => FDRE1_Q(23), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_24 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(24), -- Data input
	Q => FDRE1_Q(24), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_25 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(25), -- Data input
	Q => FDRE1_Q(25), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_26 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(26), -- Data input
	Q => FDRE1_Q(26), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
	
	FDRE1_inst_27 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(27), -- Data input
	Q => FDRE1_Q(27), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_28 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(28), -- Data input
	Q => FDRE1_Q(28), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_29 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(29), -- Data input
	Q => FDRE1_Q(29), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_30 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(30), -- Data input
	Q => FDRE1_Q(30), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
	FDRE1_inst_31 : FDRE
	generic map (
	INIT => '0')
	port map (
	D => FDRE0_Q(31), -- Data input
	Q => FDRE1_Q(31), -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);
		
			
	FDRE_an_trig_d : FDRE
	generic map (
	INIT => '0')
	port map (
	D => an_trig, -- Data input
	Q => an_trig_d, -- Data output
	C => clk, -- Clock input
	CE => '1', -- Clock enable input
	R => rst -- Synchronous reset input
	);


end Behavioral;

