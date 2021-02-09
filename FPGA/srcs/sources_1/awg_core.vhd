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
library UNISIM;
use UNISIM.VComponents.all;


entity awg_core is
    generic (
        bH : integer := 14; -- angle input precision high index
        bL : integer := -17 -- angle input precision low index
    );
    Port ( clk_in : in  STD_LOGIC;
            --clk enable
            generator1On : in STD_LOGIC;
            generator2On : in STD_LOGIC;
            phase_sync : in STD_LOGIC;
            phase_val : in STD_LOGIC_VECTOR(bH downto 0);
            --AWG1
            genSignal_1        : out signed (11 downto 0);
            ram_addrb_awg_1    : out STD_LOGIC_VECTOR (14 downto 0);
            generatorType_1    : in  STD_LOGIC_VECTOR (3 downto 0);
            generatorVoltage_1 : in  sfixed(0 downto -11);
            generatorOffset_1  : in  SIGNED (11 downto 0);
            generatorDuty_1    : in  signed(11 downto 0);
            generatorDelta_1   : in  STD_LOGIC_VECTOR(bH-bL downto 0);
            generatorCustomSample_1 : in  STD_LOGIC_VECTOR (11 downto 0);
            --AWG2
            genSignal_2        : out signed (11 downto 0);
            ram_addrb_awg_2    : out STD_LOGIC_VECTOR (14 downto 0);
            generatorType_2    : in  STD_LOGIC_VECTOR (3 downto 0);
            generatorVoltage_2 : in  sfixed(0 downto -11);
            generatorOffset_2  : in  SIGNED (11 downto 0);
            generatorDuty_2    : in  signed(11 downto 0);
            generatorDelta_2   : in  STD_LOGIC_VECTOR(bH-bL downto 0);
            generatorCustomSample_2 : in  STD_LOGIC_VECTOR (11 downto 0);
            --DAC programming signals
            dac_data_1 : out STD_LOGIC_VECTOR (11 downto 0);
            dac_data_2 : out STD_LOGIC_VECTOR (11 downto 0);
            dac_clk : out STD_LOGIC
            --awg_select : out std_logic
            );
			  
attribute use_dsp48: string;

end awg_core;

--attribute use_dsp48 of {entity_name|component_name|signal_name}: {entity|component|signal} is "automax";

architecture Behavioral of awg_core is
		
	component angle_gen
		Port (
			clk : in STD_LOGIC;
			clk_en : in STD_LOGIC;
			generatorDelta : in sfixed(bH downto bL);
            phase_sync : in std_logic;
            phase_val : in sfixed(bH downto bL);
			kot_gen : out sfixed(bH downto 0);
			q_gen : out std_logic_vector(1 downto 0)
			);
	end component;

--signal generatorDelta : sfixed(bH downto bL);
signal kot_gen : sfixed(bH downto 0);
signal q_gen : std_logic_vector(1 downto 0);

--	component cordic_par
--		Port (
--			clk : in  std_logic;
--			generatorOn : in std_logic;
--			kot_gen : in sfixed(bH downto 0);
--			q_gen : in std_logic_vector(1 downto 0);
--			y_sin : out  SIGNED (11 downto 0);
--			x_cos : out  SIGNED (11 downto 0)           
--         );
--	end component;
	
	COMPONENT cordic_0
      PORT (
        aclk : IN STD_LOGIC;
        s_axis_phase_tvalid : IN STD_LOGIC;
        s_axis_phase_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
      );
    END COMPONENT;
	
	component rand_gen
		Port (
			clk : in std_logic;
			enable : in std_logic;
			random_num : out std_logic_vector(11 downto 0)         
			);
	end component;
	
-- AWG internal signals
signal awg_select_i : std_logic;
signal awg_select_i_180 : std_logic;
signal dac_clk_buff_i : std_logic;
signal dac_clk_buff_i_180 : std_logic;

signal generator1On_d : std_logic;
signal generator2On_d : std_logic;

signal generator1On_dd : std_logic;
signal generator2On_dd : std_logic;

signal s_axis_phase_tvalid_1 : std_logic;
signal s_axis_phase_tdata_1 : std_logic_vector(15 downto 0);
signal m_axis_dout_tvalid_1 : std_logic;
signal m_axis_dout_tdata_1 : std_logic_vector(31 downto 0);

signal s_axis_phase_tvalid_2 : std_logic;
signal s_axis_phase_tdata_2 : std_logic_vector(15 downto 0);
signal m_axis_dout_tvalid_2 : std_logic;
signal m_axis_dout_tdata_2 : std_logic_vector(31 downto 0);

signal CLK0 : std_logic;
signal CLK180 : std_logic;

signal kot_gen_1 : sfixed(bH downto 0);
signal kot_gen_2 : sfixed(bH downto 0);
signal kot_gen_1_tmp : std_logic_vector(bH downto 0);
signal kot_gen_2_tmp : std_logic_vector(bH downto 0);
signal q_gen_1 : std_logic_vector(1 downto 0);
signal q_gen_2 : std_logic_vector(1 downto 0);

signal y_sin : signed(11 downto 0);
signal y_sin_1 : signed(11 downto 0);
signal y_sin_2 : signed(11 downto 0);
signal y_sin_1_d : signed(11 downto 0);
signal y_sin_2_d : signed(11 downto 0);
signal x_cos : signed(11 downto 0);
signal x_cos_1 : signed(11 downto 0);
signal x_cos_2 : signed(11 downto 0);
signal x_cos_1_d : signed(11 downto 0);
signal x_cos_2_d : signed(11 downto 0);

signal genSignal_1_i : sfixed (12 downto 0);
signal genSignal_2_i : sfixed (12 downto 0);
signal genSignalScaled_1: sfixed(12 downto -11);
signal genSignalScaled_2: sfixed(12 downto -11);
signal genSignalScaled_1_tmp: sfixed(12 downto -11);
signal genSignalScaled_2_tmp: sfixed(12 downto -11);
signal genSignal_1_tmp : SIGNED (11 downto 0):=to_signed(0,12);
signal genSignal_2_tmp : SIGNED (11 downto 0):=to_signed(0,12);
signal genSignal_1_tmp_d : SIGNED (11 downto 0);
signal genSignal_1_tmp_dd : SIGNED (11 downto 0);
signal genSignal_2_tmp_d : SIGNED (11 downto 0);
signal genSignal_2_tmp_dd : SIGNED (11 downto 0);
signal genSignal_1_ii : SIGNED (11 downto 0);
signal genSignal_2_ii : SIGNED (11 downto 0);
signal dac_data_1_test : STD_LOGIC_VECTOR (11 downto 0);
signal dac_data_2_test : STD_LOGIC_VECTOR (11 downto 0);

signal generatorVoltage_1d : sfixed(0 downto -11);
signal generatorVoltage_1dd : sfixed(0 downto -11);
signal generatorType_1d : std_logic_vector (3 downto 0);
signal generatorOffset_1d : SIGNED (11 downto 0);
signal generatorDuty_1d : signed(11 downto 0);
signal generatorDelta_1_i : std_logic_vector(bH-bL downto 0) := std_logic_vector(to_unsigned(0,bh-bL+1));
signal generatorCustomSample_1d : STD_LOGIC_VECTOR (11 downto 0);

signal generatorVoltage_2d : sfixed(0 downto -11);
signal generatorVoltage_2dd : sfixed(0 downto -11);
signal generatorType_2d : std_logic_vector (3 downto 0);
signal generatorOffset_2d : SIGNED (11 downto 0);
signal generatorDuty_2d : signed(11 downto 0);
signal generatorDelta_2_i : std_logic_vector(bH-bL downto 0) := std_logic_vector(to_unsigned(0,bh-bL+1));
signal generatorCustomSample_2d : STD_LOGIC_VECTOR (11 downto 0);

signal generatorVoltage_dd : sfixed(0 downto -11);
signal generatorType_dd : std_logic_vector (3 downto 0);
signal generatorOffset_dd : SIGNED (11 downto 0);
signal generatorDuty_dd : signed(11 downto 0);
signal generatorDelta_dd : sfixed(bH downto bL);
signal generatorCustomSample_dd : STD_LOGIC_VECTOR (11 downto 0);

signal q_gen_1_d1 : std_logic;
signal q_gen_2_d1 : std_logic;

signal random_num_1 : STD_LOGIC_VECTOR (bH downto bH-11);
signal random_num_1_tmp : signed (bH downto bH-11);
signal random_num_2 : STD_LOGIC_VECTOR (bH downto bH-11);
signal random_num_2_tmp : signed (bH downto bH-11);
signal enable_rand_1 : std_logic;
signal enable_rand_2 : std_logic;

signal phase_sync_i : std_logic := '0';
signal phase_val_i : std_logic_vector(bH-bL downto 0) := std_logic_vector(to_unsigned(0,bh-bL+1));

-- set keep attributes for registers
--attribute keep: boolean;
--attribute keep of some_signal: signal is true;
--attribute equivalent_register_removal of some_signal : signal is "no";
--attribute IOB : string;
--attribute IOB of dac_data: signal is "TRUE";

-- attribute strings
attribute KEEP: boolean;
attribute ASYNC_REG: boolean;
attribute mark_debug: boolean;

-- assign KEEP attributes to help debugging
attribute KEEP of generator1On: signal is true;
attribute KEEP of generator1On_d: signal is true;
attribute ASYNC_REG of generator1On_d: signal is true;
attribute KEEP of generator2On: signal is true;
attribute KEEP of generator2On_d: signal is true;
attribute ASYNC_REG of generator2On_d: signal is true;
attribute KEEP of generatorType_1d         : signal is true;
attribute ASYNC_REG of generatorType_1d    : signal is true;
attribute KEEP of generatorVoltage_1d      : signal is true;
attribute ASYNC_REG of generatorVoltage_1d : signal is true;
attribute KEEP of generatorOffset_1d       : signal is true;
attribute ASYNC_REG of generatorOffset_1d  : signal is true;
attribute KEEP of generatorDuty_1d         : signal is true;
attribute ASYNC_REG of generatorDuty_1d     : signal is true;
attribute KEEP of generatorCustomSample_1d : signal is true;
attribute ASYNC_REG of generatorCustomSample_1d : signal is true;
attribute KEEP of generatorType_2d         : signal is true;
attribute ASYNC_REG of generatorType_2d         : signal is true;
attribute KEEP of generatorVoltage_2d      : signal is true;
attribute ASYNC_REG of generatorVoltage_2d      : signal is true;
attribute KEEP of generatorOffset_2d       : signal is true;
attribute ASYNC_REG of generatorOffset_2d       : signal is true;
attribute KEEP of generatorDuty_2d         : signal is true;
attribute ASYNC_REG of generatorDuty_2d         : signal is true;
attribute KEEP of generatorCustomSample_2d : signal is true;
attribute ASYNC_REG of generatorCustomSample_2d : signal is true;
attribute KEEP of phase_val_i      : signal is true;
attribute ASYNC_REG of phase_val_i : signal is true;

attribute KEEP of genSignal_1_tmp_d : signal is true;
attribute mark_debug of genSignal_1_tmp_d : signal is true;
attribute KEEP of dac_data_1 : signal is true;
attribute mark_debug of dac_data_1 : signal is true;



begin

	angle_generator_1 : angle_gen
	   port map (
            clk => clk_in,
            clk_en => generator1On_d,
            generatorDelta => to_sfixed(generatorDelta_1_i, bH,bL),
            phase_sync => phase_sync_i,
	        phase_val => to_sfixed(0,bH,bL),
	        kot_gen => kot_gen_1,
			q_gen => q_gen_1
			  );
	
	angle_generator_2 : angle_gen
	   port map (
            clk => clk_in,
	 	    clk_en => generator2On_d,
			generatorDelta => to_sfixed(generatorDelta_2_i, bH,bL),
	        phase_sync => phase_sync_i,
	        phase_val => to_sfixed(phase_val_i, bH, bL),
	        kot_gen => kot_gen_2,
			q_gen => q_gen_2
			);
	
--	cordic_par_core_1 : cordic_par
--	   port map (
--              clk => clk_in,
--		 	  generatorOn => generator1On_d,
--	          kot_gen => kot_gen_1(bH downto 0),
--			  q_gen => q_gen_1,
--			  y_sin => y_sin_1,
--			  x_cos => x_cos_1
--			  );

    cordic_0_core_1 : cordic_0
      PORT MAP (
        aclk => clk_in,
        s_axis_phase_tvalid => generator1On_d,
        s_axis_phase_tdata => "00" & kot_gen_1_tmp(bH) & kot_gen_1_tmp(bH) & kot_gen_1_tmp(bH downto bH-11),
        m_axis_dout_tvalid => m_axis_dout_tvalid_1,
        m_axis_dout_tdata => m_axis_dout_tdata_1
      );

    cordic_0_core_2 : cordic_0
      PORT MAP (
        aclk => clk_in,
        s_axis_phase_tvalid => generator1On_d,
        s_axis_phase_tdata => "00" & kot_gen_2_tmp(bH) & kot_gen_2_tmp(bH) & kot_gen_2_tmp(bH downto bH-11),
        m_axis_dout_tvalid => m_axis_dout_tvalid_2,
        m_axis_dout_tdata => m_axis_dout_tdata_2
      );
      
--	cordic_par_core_2 : cordic_par
--	   port map (
--              clk => clk_in,
--		 	  generatorOn => generator2On_d,
--	          kot_gen => kot_gen_2(bH downto 0),
--			  q_gen => q_gen_2,
--			  y_sin => y_sin_2,
--			  x_cos => x_cos_2
--			  );
		  
	psrg_generator_1 : rand_gen
		port map (
				clk => clk_in,
				enable => enable_rand_1,
				random_num => random_num_1
				);
				
	psrg_generator_2 : rand_gen
		port map (
				clk => clk_in,
				enable => enable_rand_2,
				random_num => random_num_2
				);


-- clock forward
dac_clk <= clk_in;

	--========================================--
	--       Signal generator process         --
	--========================================--

awg_core_process: process(clk_in)

begin
	if (rising_edge(clk_in)) then
	
	    generator1On_d <= generator1On;
	    generator2On_d <= generator2On;
	    if generator2On_dd = '0' and generator2On_d = '1' then
	   	   phase_sync_i <= '1';
	   	else
	   	   phase_sync_i <= phase_sync;
	   	end if;
	   	   
		if ( generator1On_d = '1' OR generator2On_d = '1' ) then
			
			    if generator1On_d = '1' then
					--#generator 1 selected#
					
--					--connect generator #1 to cordic core
--					kot_gen <= kot_gen_1;
--					q_gen <= q_gen_1;

					--registers inputs
					generatorType_1d <= generatorType_1;
					generatorVoltage_1d <= generatorVoltage_1;
					generatorVoltage_1dd <= generatorVoltage_1d;
					generatorOffset_1d <= generatorOffset_1;
					generatorDuty_1d <= generatorDuty_1;
					generatorCustomSample_1d <= generatorCustomSample_1;
					random_num_1_tmp <= signed(random_num_1);
				    generatorDelta_1_i <= '0' & generatorDelta_1(31 downto 1);
				    
					--utilize DSP block (multiply/add)
					genSignal_1_tmp_d <= genSignal_1_tmp;
					genSignal_1_tmp_dd <= genSignal_1_tmp_d;
					genSignalScaled_1_tmp <= to_sfixed(genSignal_1_tmp_dd,11,0) * generatorVoltage_1dd;
					genSignalScaled_1 <= genSignalScaled_1_tmp;
                    genSignal_1_i <= genSignalScaled_1(11 downto 0) + sfixed(generatorOffset_1d);
                    if signed(genSignal_1_i) > to_signed(2047,13) then
                        genSignal_1_ii <= to_signed(2047,12);
                    elsif signed(genSignal_1_i) < to_signed(-2047,13) then
                        genSignal_1_ii <= to_signed(-2047,12);
                    else
                        genSignal_1_ii <= signed(genSignal_1_i(11 downto 0));
                    end if;
                    genSignal_1 <= genSignal_1_ii;
                    --Converting from Two's Complement to Offset Binary
                    --dac_data_1 <= std_logic_vector( genSignal_1_ii + to_signed(2048,12) ); --add Offset
                    dac_data_1 <= std_logic_vector( NOT(genSignal_1_ii(11)) & genSignal_1_ii(10 downto 0) ) ; --convert to offseet binary
--					dac_data_1 <= dac_data_1_test;
					
					--======================
					-- Custom Signal - AWG  
					--======================		

					if unsigned(generatorType_1d) = 0 then
						genSignal_1_tmp <= signed(generatorCustomSample_1d); -- read Custom Sample from RAM
						---genSignal_tmp <= signed(awg_doutB(11 downto 0));
						-- increment RAM address according to angle generator output
						if q_gen_1(0) = '0' then
							ram_addrb_awg_1 <= std_logic_vector(kot_gen_1(bH downto 0));
						elsif q_gen_1 = "01" then
							ram_addrb_awg_1 <= std_logic_vector(to_signed(2**bH,bH)+signed(kot_gen_1(bH downto 0)));
						elsif q_gen_1 = "10" then
							ram_addrb_awg_1 <= std_logic_vector(kot_gen_1(bH downto 0));
						else
							ram_addrb_awg_1 <= std_logic_vector(to_signed(2**bH,bH)+signed(kot_gen_1(bH downto 0)));
						end if;
						enable_rand_1 <= '0';
						
					--======================
					-- Sin 
					--======================

					elsif unsigned(generatorType_1d) = 1 then
						-- generate phase
						if q_gen_1(0) = '0' then
                            kot_gen_1_tmp <= std_logic_vector(signed(kot_gen_1(bH downto 0)));
                        else
                            kot_gen_1_tmp <= std_logic_vector(to_signed(-16384,bH+1)+signed(kot_gen_1(bH downto 0)));
                        end if;
                        -- read signal from cordic_0
                        if m_axis_dout_tdata_1(28 downto 27) = "10" then
                            y_sin_1_d <= to_signed(-2048,12);
                        elsif m_axis_dout_tdata_1(28 downto 27) = "01" then
                            y_sin_1_d <= to_signed(2047,12);
                        else
						    y_sin_1_d <= signed(m_axis_dout_tdata_1(28) & m_axis_dout_tdata_1(26 downto 16));
                        end if;
                        genSignal_1_tmp <= y_sin_1_d;
						enable_rand_1 <= '0';
						
					--======================
					-- Cos
					--======================

					elsif unsigned(generatorType_1d) = 2 then
						-- generate phase
						if q_gen_1(0) = '0' then
                            kot_gen_1_tmp <= std_logic_vector(signed(kot_gen_1(bH downto 0)));
                        else
                            kot_gen_1_tmp <= std_logic_vector(to_signed(-16384,bH+1)+signed(kot_gen_1(bH downto 0)));
                        end if;
                        -- read signal from cordic_0
                        if m_axis_dout_tdata_1(12 downto 11) = "10" then
                            x_cos_1_d <= to_signed(-2048,12);
                        elsif m_axis_dout_tdata_1(12 downto 11) = "01" then
                            x_cos_1_d <= to_signed(2047,12);
                        else
						    x_cos_1_d <= signed(m_axis_dout_tdata_1(12) & m_axis_dout_tdata_1(10 downto 0));
						end if;
                        genSignal_1_tmp <= x_cos_1_d;
						enable_rand_1 <= '0';
						
					--======================
					-- Triangle
					--======================

					elsif unsigned(generatorType_1d) = 3 then
						if q_gen_1 = "00" OR q_gen_1 = "10" then
							genSignal_1_tmp <= to_signed(-2048,12)+signed(kot_gen_1(bH-1 downto bH-12));
							--signed(kot_gen_2(bH downto bH-11));
						elsif q_gen_1 = "01" OR q_gen_1 = "11" then
						    genSignal_1_tmp <= to_signed(2047,12)-signed(kot_gen_1(bH-1 downto bH-12));
						end if;
						enable_rand_1 <= '0';
						
					--======================
					-- Ramp Up
					--======================

					elsif unsigned(generatorType_1d) = 4 then
						if q_gen_1(0) = '0' then
							genSignal_1_tmp <= signed(kot_gen_1(bH downto bH-11));
						else
							genSignal_1_tmp <= to_signed(-2047,12)+signed(kot_gen_1(bH downto bH-11));
						end if;
						enable_rand_1 <= '0';
						
					--======================
					-- Ramp Down
					--======================

					elsif unsigned(generatorType_1d) = 5 then
						if q_gen_1(0) = '0' then
							genSignal_1_tmp <= -signed(kot_gen_1(bH downto bH-11));
						else
							genSignal_1_tmp <= to_signed(2047,12)-signed(kot_gen_1(bH downto bH-11));
						end if;
						enable_rand_1 <= '0';
						
					--======================
					-- Square
					--======================

					elsif unsigned(generatorType_1d) = 6 then
						if q_gen_1(0) = '1' then
					        if signed(kot_gen_1(bH downto bH-11)) < 2*(to_signed(-1024,12)+generatorDuty_1d) then
					            genSignal_1_tmp <= to_signed(2047,12);
						    else
							    genSignal_1_tmp <= to_signed(-2047,12);       
						    end if;
						else
						    if signed(kot_gen_1(bH downto bH-11)) < 2*(generatorDuty_1d) then
					            genSignal_1_tmp <= to_signed(2047,12);
						    else
							    genSignal_1_tmp <= to_signed(-2047,12);       
						    end if;					
						end if;
						enable_rand_1 <= '0';
						
					--======================
					-- Delta
					--======================

					elsif unsigned(generatorType_1d) = 7 then			
						q_gen_1_d1 <= q_gen_1(0);
						if q_gen_1_d1 = '1' and q_gen_1(0) = '0' then
							genSignal_1_tmp <= to_signed(2047,12);
						else
							genSignal_1_tmp <= to_signed(-2047,12);
						end if;
						enable_rand_1 <= '0';
						
					--======================
					-- DC
					--======================
					elsif unsigned(generatorType_1d) = 8 then
						genSignal_1_tmp <= to_signed(0,12);
						enable_rand_1 <= '0';

					--======================
					-- Noise
					--======================

					elsif unsigned(generatorType_1d) = 9 then
						enable_rand_1 <= '1';
						genSignal_1_tmp <= random_num_1_tmp;
						
					end if;
					
				end if;
				
				if generator2On_d = '1' then
					--#generator 2 selected#

--					--connect generator #2 to cordic core
--					kot_gen <= kot_gen_2;
--					q_gen <= q_gen_2;
				    
					--registers inputs
					generatorType_2d <= generatorType_2;
					generatorVoltage_2d <= generatorVoltage_2;
					generatorVoltage_2dd <= generatorVoltage_2d;
					generatorOffset_2d <= generatorOffset_2;
					generatorDuty_2d <= generatorDuty_2;
					generatorCustomSample_2d <= generatorCustomSample_2;
					random_num_2_tmp <= signed(random_num_2);
				    generatorDelta_2_i <= '0' & generatorDelta_2(31 downto 1);
					phase_val_i <= phase_val & std_logic_vector(to_unsigned(0,abs(bL)));
					
					--utilize DSP block (multiply/add)
					genSignal_2_tmp_d <= genSignal_2_tmp;
					genSignal_2_tmp_dd <= genSignal_2_tmp_d;
					genSignalScaled_2_tmp <= to_sfixed(genSignal_2_tmp_dd,11,0) * generatorVoltage_2dd;
					genSignalScaled_2 <= genSignalScaled_2_tmp;
                    genSignal_2_i <= genSignalScaled_2(11 downto 0) + sfixed(generatorOffset_2d);
                    if signed(genSignal_2_i) > to_signed(2047,13) then
                        genSignal_2_ii <= to_signed(2047,12);
                    elsif signed(genSignal_2_i) < to_signed(-2047,13) then
                        genSignal_2_ii <= to_signed(-2047,12);
                    else
                        genSignal_2_ii <= signed(genSignal_2_i(11 downto 0));
                    end if;
                    genSignal_2 <= genSignal_2_ii;
                    --Converting from Two's Complement to Offset Binary
                    --dac_data_2 <= std_logic_vector( genSignal_2_ii + to_signed(2048,12) ); --add Offset
                    dac_data_2 <= std_logic_vector( NOT(genSignal_2_ii(11)) & genSignal_2_ii(10 downto 0) ) ; --convert to offset binary
--					dac_data_2 <= dac_data_2_test;
					                    
					--======================
					-- Custom Signal - AWG  
					--======================		

					if unsigned(generatorType_2d) = 0 then
						genSignal_2_tmp <= signed(generatorCustomSample_2d); -- read Custom Sample from RAM
						---genSignal_tmp <= signed(awg_doutB(11 downto 0));
						-- increment RAM address according to angle generator output
						if q_gen_2 = "00" then
							ram_addrb_awg_2 <= std_logic_vector(kot_gen_2(bH downto 0));
						elsif q_gen_2 = "01" then
							ram_addrb_awg_2 <= std_logic_vector(to_signed(2**bH,bH)+signed(kot_gen_2(bH downto 0)));
						elsif q_gen_2 = "10" then
							ram_addrb_awg_2 <= std_logic_vector(kot_gen_2(bH downto 0));
						else
							ram_addrb_awg_2 <= std_logic_vector(to_signed(2**bH,bH)+signed(kot_gen_2(bH downto 0)));
						end if;
						enable_rand_2 <= '0';
						
					--======================
					-- Sin 
					--======================

					elsif unsigned(generatorType_2d) = 1 then
						-- generate phase
						if q_gen_2(0) = '0' then
                            kot_gen_2_tmp <= std_logic_vector(signed(kot_gen_2(bH downto 0)));
                        else
                            kot_gen_2_tmp <= std_logic_vector(to_signed(-16384,bH+1)+signed(kot_gen_2(bH downto 0)));
                        end if;
                        -- read signal from cordic_0
                        if m_axis_dout_tdata_2(28 downto 27) = "10" then
                            y_sin_2_d <= to_signed(-2048,12);
                        elsif m_axis_dout_tdata_2(28 downto 27) = "01" then
                            y_sin_2_d <= to_signed(2047,12);
                        else
                            y_sin_2_d <= signed(m_axis_dout_tdata_2(28) & m_axis_dout_tdata_2(26 downto 16));
                        end if;
                        genSignal_2_tmp <= y_sin_2_d;
						enable_rand_2 <= '0';
						
					--======================
					-- Cos
					--======================

					elsif unsigned(generatorType_2d) = 2 then
                        -- generate phase
						if q_gen_2(0) = '0' then
                            kot_gen_2_tmp <= std_logic_vector(signed(kot_gen_2(bH downto 0)));
                        else
                            kot_gen_2_tmp <= std_logic_vector(to_signed(-16384,bH+1)+signed(kot_gen_2(bH downto 0)));
                        end if;
                        -- read signal from cordic_0
                        if m_axis_dout_tdata_2(12 downto 11) = "10" then
                            x_cos_2_d <= to_signed(-2048,12);
                        elsif m_axis_dout_tdata_2(12 downto 11) = "01" then
                            x_cos_2_d <= to_signed(2047,12);
                        else
                            x_cos_2_d <= signed(m_axis_dout_tdata_2(12) & m_axis_dout_tdata_2(10 downto 0));
                        end if;
                        genSignal_2_tmp <= x_cos_2_d;
						enable_rand_2 <= '0';
						
					--======================
					-- Triangle
					--======================

					elsif unsigned(generatorType_2d) = 3 then
						if q_gen_2 = "00" OR q_gen_2 = "10" then
							genSignal_2_tmp <= to_signed(-2048,12)+signed(kot_gen_2(bH-1 downto bH-12));
							--signed(kot_gen_2(bH downto bH-11));
						elsif q_gen_2 = "01" OR q_gen_2 = "11" then
						    genSignal_2_tmp <= to_signed(2047,12)-signed(kot_gen_2(bH-1 downto bH-12));
						end if;
						enable_rand_2 <= '0';
						
					--======================
					-- Ramp Up
					--======================

					elsif unsigned(generatorType_2d) = 4 then
						if q_gen_2(0) = '0' then
							genSignal_2_tmp <= signed(kot_gen_2(bH downto bH-11));
						else
							genSignal_2_tmp <= to_signed(-2047,12)+signed(kot_gen_2(bH downto bH-11));
						end if;
						enable_rand_2 <= '0';
						
					--======================
					-- Ramp Down
					--======================

					elsif unsigned(generatorType_2d) = 5 then
						if q_gen_2(0) = '0' then
							genSignal_2_tmp <= -signed(kot_gen_2(bH downto bH-11));
						else
							genSignal_2_tmp <= to_signed(2047,12)-signed(kot_gen_2(bH downto bH-11));
						end if;
						enable_rand_2 <= '0';
						
					--======================
					-- Square
					--======================

					elsif unsigned(generatorType_2d) = 6 then
						if q_gen_2(0) = '1' then
					        if signed(kot_gen_2(bH downto bH-11)) < 2*(to_signed(-1024,12)+generatorDuty_2d) then
					            genSignal_2_tmp <= to_signed(2047,12);
						    else
							    genSignal_2_tmp <= to_signed(-2047,12);       
						    end if;
						else
						    if signed(kot_gen_2(bH downto bH-11)) < 2*(generatorDuty_2d) then
					            genSignal_2_tmp <= to_signed(2047,12);
						    else
							    genSignal_2_tmp <= to_signed(-2047,12);       
						    end if;					
						end if;
						enable_rand_2 <= '0';
						
					--======================
					-- Delta
					--======================

					elsif unsigned(generatorType_2d) = 7 then
						q_gen_2_d1 <= q_gen_2(0);
						if q_gen_2_d1 = '1' and q_gen_2(0) = '0' then
							genSignal_2_tmp <= to_signed(2047,12);
						else
							genSignal_2_tmp <= to_signed(-2047,12);
						end if;
						enable_rand_2 <= '0';
							
					--======================
					-- DC
					--======================
					
					elsif unsigned(generatorType_2d) = 8 then
						genSignal_2_tmp <= to_signed(0,12);
						enable_rand_2 <= '0';
						
					--======================
					-- Noise
					--======================

					elsif unsigned(generatorType_2d) = 9 then
						genSignal_2_tmp <= random_num_2_tmp;
						enable_rand_2 <= '1';
						
					end if;
			end if;
--	    else
--	       	dac_data_1_test <= std_logic_vector(unsigned(dac_data_1_test) + 1);
--            dac_data_1 <= dac_data_1_test;
--            dac_data_2_test <= std_logic_vector(unsigned(dac_data_1_test) + 1);
--            dac_data_2 <= not(dac_data_2_test);
		end if;
	end if;
	
end process;

end Behavioral;

