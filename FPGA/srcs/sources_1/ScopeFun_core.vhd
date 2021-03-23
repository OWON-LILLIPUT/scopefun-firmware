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
-- Scopefun firmware: FGPA core
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;      
use IEEE.NUMERIC_STD.ALL;
library IEEE_PROPOSED;
use IEEE_PROPOSED.FIXED_PKG.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity fpga is
	
	Port (
	-- FX3 interface
		fdata         : inout STD_LOGIC_VECTOR(31 downto 0);	-- FIFO data lines. 
		faddr         : out STD_LOGIC_VECTOR(1 downto 0);		-- FIFO select lines
		slcs          : out STD_LOGIC;                          -- Slave select control line
		slwr          : out STD_LOGIC;                          -- Write control line (asserted_low)	  
		slrd_sloe     : out STD_LOGIC;                          -- Read control line (SLOE & SLRD are tied together) 
		LED           : out STD_LOGIC_VECTOR(3 downto 1);       -- LED indicators
		flaga         : in STD_LOGIC;                           -- EP2 - OUT Empty flag (all flags acive low)
		flagb         : in STD_LOGIC;                           -- EP4 - OUT Empty flag
		pktend        : out STD_LOGIC;                          -- Commit short packet (asserted_low)
		flagd         : in STD_LOGIC;                           -- EP6 - IN Full Flag
		clk_fx3       : out STD_LOGIC;                          -- FX3 GPIF Clock
	-- ADC interface
        clk_adc_p     : in STD_LOGIC;           -- ADC clock LVDS p
        clk_adc_n     : in STD_LOGIC;
		dataA_p       : in std_logic_vector(4 downto 0);  -- ADC CHA data (LVDS DDR)
		dataA_n       : in std_logic_vector(4 downto 0);  -- ADC CHA data
		dataB_p       : in std_logic_vector(4 downto 0);  -- ADC CHB data (LVDS DDR)
		dataB_n       : in std_logic_vector(4 downto 0);  -- ADC CHB data
		adc_sclk      : out STD_LOGIC;        -- ADC serial-interface clock
		adc_sdin      : out STD_LOGIC;        -- ADC serial-interface data
		adcA_cs		  : out STD_LOGIC;        -- ADC CH1 serial-interface cs#
		adcB_cs		  : out STD_LOGIC;        -- ADC CH2 serial-interface cs#
	-- DIGITAL channels inteface signals
		dataD         : inout std_logic_vector (11 downto 0);
		dir_11_6      : out STD_LOGIC;  -- D11, ..., D6: in/out direction select
		dir_5_0       : out STD_LOGIC;  -- D5, ...., D0: in/out direction select
		dpot_cs       : out std_logic;  -- digital POT SPI interface signals
		dpot_sck      : out std_logic;  -- for setting the reference voltage of digtal ch.
		dpot_si       : out std_logic;
	-- DAC interface
	    -- control DAC
		dasync        : out STD_LOGIC;		-- V-DAC serial-interface update signal
		dasclk        : out STD_LOGIC;		-- V-DAC serial-interface clock
		dasdin        : out STD_LOGIC;		-- V-DAC serial-interface data
	   -- generator DAC
		dac_clk_1     : out STD_LOGIC;      -- I-DAC data clock
		dac_clk_2     : out STD_LOGIC;      -- I-DAC data clock (inverted)
		dac_en        : out STD_LOGIC;      -- I-DAC enable
		dac_data      : out STD_LOGIC_VECTOR (11 downto 0); -- I-DAC data lines (DDR)
    -- Analog Trigger for CH-A ETS
		an_trig_p     : in STD_LOGIC;  -- analog/ets trigger
		an_trig_n     : in STD_LOGIC;  --
		an_trig_level : out STD_LOGIC; -- analog/ets trigger level (PWM generated)
	-- Analog switching
		ch1_dc	      : out STD_LOGIC;    -- DC/AC switch
		ch2_dc	      : out STD_LOGIC;
		ch1_gnd       : out STD_LOGIC;    -- GND switch
		ch2_gnd       : out STD_LOGIC;
		ch1_k         : out STD_LOGIC;    -- attenuator switch
		ch2_k         : out STD_LOGIC;
		cc_ab         : out STD_LOGIC;    -- connect ch1 to both ADC inputs (for ADC interleaving mode)
    -- DDR3
        ddr3_dq      : inout std_logic_vector(15 downto 0);
        ddr3_dqs_p   : inout std_logic_vector(1 downto 0);
        ddr3_dqs_n   : inout std_logic_vector(1 downto 0);
        ddr3_addr    : out std_logic_vector(14 downto 0);
        ddr3_ba      : out std_logic_vector(2 downto 0);
        ddr3_ras_n   : out std_logic;
        ddr3_cas_n   : out std_logic;
        ddr3_we_n    : out std_logic;
        ddr3_reset_n : out std_logic;
        ddr3_ck_p    : out std_logic_vector(0 downto 0);
        ddr3_ck_n    : out std_logic_vector(0 downto 0);
        ddr3_cke     : out std_logic_vector(0 downto 0);
        ddr3_odt     : out std_logic_vector(0 downto 0) 
	   );				 	            

end fpga;

architecture rtl of fpga is

	--define constants
	
	--max number of oscilloscope configuration registers
    CONSTANT CONFIG_DATA_SIZE : integer := 32;    -- number of 32-bit Words for scope config
    CONSTANT FRAME_HEADER_SIZE : integer := 256;  -- number of 32-bit Words for frame header
    CONSTANT DDR3_MAX_SAMPLES : integer := 2**27; -- 2^27 = 128M samples
    CONSTANT AWG_MAX_SAMPLES : integer := 32768;  -- number of samples for AWG custom signal and dig. pattern generator
    --CONSTANT AWG_MAX_SAMPLES : integer := 4096;
    --digital ch. interface width
    CONSTANT LA_DATA_WIDTH : INTEGER := 12;
    CONSTANT LA_COUNTER_WIDTH : INTEGER := 16;
    --USB buffers
    CONSTANT FX3_DMA_BUFFER_SIZE : INTEGER := 1024;  -- FX3 DMA BUFER SIZE (number of bytes)
    
    CONSTANT bH : INTEGER := 14;  -- sfixed high index
    CONSTANT bL : INTEGER := -17; -- sfixed low index
   
    CONSTANT DATA_DEPTH: integer := AWG_MAX_SAMPLES;
    CONSTANT DATA_WIDTH: integer := 12;
    
    component adc_if is
    Port ( 
        i_clk_p : in STD_LOGIC;
        i_clk_n : in STD_LOGIC;
        i_clk_ref : in std_logic;
        i_reset_n : in std_logic;
        i_en_fifo : in std_logic;
        i_read_calib_start : in std_logic;
        i_read_calib_source : in std_logic;
        i_data_1_p : in STD_LOGIC_VECTOR (4 downto 0);
        i_data_1_n : in STD_LOGIC_VECTOR (4 downto 0);
        i_data_2_p : in STD_LOGIC_VECTOR (4 downto 0);
        i_data_2_n : in STD_LOGIC_VECTOR (4 downto 0);
        o_clk : out STD_LOGIC;
        o_data_1 : out STD_LOGIC_VECTOR (9 downto 0);
        o_data_2 : out STD_LOGIC_VECTOR (9 downto 0));
    end component;
     
    component RAM_DDR3 is
    port (
       -- TOP level signals
       sys_clk_i : in std_logic; -- System clock 250 Mhz
       clk_ref_i : in std_logic; -- Reference clock 200 Mhz
       ui_clk : out std_logic; -- Output clock for user logic (100 Mhz)
       rst : in STD_LOGIC;
       FrameSize : in std_logic_vector(26 downto 0);
       DataIn : in STD_LOGIC_VECTOR (31 downto 0);
       PreTrigSaving : in std_logic;  -- assrted (de-asserted) at start (end) of pre-trigger
       PreTrigWriteEn : in std_logic; -- pre-trigger data write enable
       PreTrigLen : in std_logic_vector(26 downto 0); -- number of pre-trigger samples 
       DataWriteEn : in STD_LOGIC;
       FrameSaveEnd : in STD_LOGIC;
       DataOut : out STD_LOGIC_VECTOR (31 downto 0);
       DataOutEnable : in std_logic;
       DataOutValid : out STD_LOGIC;
       ReadingFrame : in std_logic;
       ram_rdy : out std_logic;
       init_calib_complete : out STD_LOGIC;
       device_temp : out std_logic_vector(11 downto 0);
       -- DDR3 PHY
       -- Inouts
       ddr3_dq      : inout std_logic_vector(15 downto 0);
       ddr3_dqs_p   : inout std_logic_vector(1 downto 0);
       ddr3_dqs_n   : inout std_logic_vector(1 downto 0);
       -- Outputs 
       ddr3_addr    : out   std_logic_vector(14 downto 0);
       ddr3_ba      : out   std_logic_vector(2 downto 0);
       ddr3_ras_n   : out   std_logic;
       ddr3_cas_n   : out   std_logic;
       ddr3_we_n    : out   std_logic;
       ddr3_reset_n : out   std_logic;
       ddr3_ck_p    : out   std_logic_vector(0 downto 0);
       ddr3_ck_n    : out   std_logic_vector(0 downto 0);
       ddr3_cke     : out   std_logic_vector(0 downto 0);
       ddr3_odt     : out   std_logic_vector(0 downto 0) 
       );
    end component;
  
	component SDP_RAM_64x32b is
      port (
		 clk1 : in std_logic;
         clk2 : in std_logic;
         we   : in std_logic;
         addr1 : in std_logic_vector(5 downto 0);
         addr2 : in std_logic_vector(5 downto 0);
         di1   : in std_logic_vector(31 downto 0);
         do1  : out std_logic_vector(31 downto 0);
         do2  : out std_logic_vector(31 downto 0));
	end component;
	
--    component SDP_BRAM_10240x36b
--       port(
--          clka : IN  std_logic;
--          wea : IN  std_logic;
--          addra : IN  std_logic_vector(13 downto 0);
--          dina : IN  std_logic_vector(35 downto 0);
--          clkb : IN  std_logic;
--          addrb : IN  std_logic_vector(13 downto 0);
--          doutb : OUT  std_logic_vector(35 downto 0));
--   end component;
	 
	component SDP_BRAM_custom_signal
	  generic (
          DATA_DEPTH : integer;
          DATA_WIDTH : integer 
       );
	   port (
	      clka: IN std_logic;
			wea: IN std_logic;
			addra: IN std_logic_VECTOR(14 downto 0);
			dina: IN std_logic_VECTOR(11 downto 0);
			clkb: IN std_logic;
			addrb: IN std_logic_VECTOR(14 downto 0);
			doutb: OUT std_logic_VECTOR(11 downto 0));
   end component;
		
	component pwm -- PWM generated DC voltage (ets trigger level)
	 Port ( clk : in  STD_LOGIC;
           v_set : in  STD_LOGIC_VECTOR (9 downto 0);
           pwm_out : out  STD_LOGIC);
	end component;

	component lut_delay is
    Port ( clk : in  STD_LOGIC;
		   rst : in STD_LOGIC;
           an_trig_p : in  STD_LOGIC;
           an_trig_n : in  STD_LOGIC;
		   an_trig_d : out STD_LOGIC;
           tap_reg_out : out  STD_LOGIC_VECTOR (31 downto 0)
			  );
	end component;
	
    component awg_core is
    Port (  clk_in : in  STD_LOGIC;
            --clk enable
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
--			awg_select : out STD_LOGIC
			);
	 end component;
	 
	 component se_to_ddr is
         Port ( i_clk : in std_logic;
                o_clk : out std_logic;
                o_clk_inv  : out std_logic;
                i_data_1 : in std_logic_vector (11 downto 0);
                i_data_2 : in std_logic_vector (11 downto 0);
                o_data_ddr : out std_logic_vector (11 downto 0);
                pll_locked : out std_logic
                );
     end component;
	 
	 component spi is
	  generic (
            SPI_LENGTH : integer -- NUMBER OF BITS TRANSFERED
            );
	  Port ( clk : in  std_logic;				
		     rst : in std_logic;
		     clk_divide : in std_logic_vector (4 downto 0);
			 spi_data : in  std_logic_vector (SPI_LENGTH-1 downto 0);
			 spi_write_trig : in std_logic;	
			 sck_idle_value : in std_logic;
			 spi_busy : out std_logic;
             cs : out  std_logic;				
             sck : out  std_logic;			
             si : out  std_logic
			 );			
	end component;
	
	COMPONENT timer
	PORT(
		clk : IN std_logic;
		t_reset : IN std_logic;
		t_start : IN std_logic;
		holdoff : IN std_logic_vector(31 downto 0);          
		o_end : OUT std_logic
		);
	END COMPONENT;
	
	COMPONENT blink
	PORT(
		clk : IN std_logic;
		reset : IN std_logic;
		trigd : IN std_logic;          
		led_out : OUT std_logic
		);
	END COMPONENT;
	
	COMPONENT clk_divider_wCE
	PORT(
		clk : IN std_logic;
		reset : IN std_logic;
		timebase : IN std_logic_vector(4 downto 0);          
		out_CE : OUT std_logic
		);
	END COMPONENT;
    
    -- Logic analyzer
    component LA_core
        generic (
        LA_DATA_WIDTH : integer := LA_DATA_WIDTH;    -- Data input width
        LA_COUNTER_WIDTH : integer := LA_COUNTER_WIDTH -- Stage Counter width
    );
    Port ( clk_in : in std_logic;
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
           dt_delaymaxcnt_0 : in std_logic_vector (LA_COUNTER_WIDTH-1 downto 0);
           dt_delaymaxcnt_1 : in std_logic_vector (LA_COUNTER_WIDTH-1 downto 0);
           dt_delaymaxcnt_2 : in std_logic_vector (LA_COUNTER_WIDTH-1 downto 0);
           dt_delaymaxcnt_3 : in std_logic_vector (LA_COUNTER_WIDTH-1 downto 0);
           dtSerial : in std_logic;
           dtSerialCh : in std_logic_vector (3 downto 0);
           dt_triggered : out std_logic;
           reset : in std_logic);
    end component;

    -- Create 200 Mhz clk_ref
    component clk_gen_pll
    Port ( clk_in : in STD_LOGIC;
           clk_out_1 : out STD_LOGIC;
           clk_out_2 : out STD_LOGIC;
           pll_locked : out STD_LOGIC);
    end component;

    component clk_wiz_0
    port
     (-- Clock in ports
      -- Clock out ports
      clk_out1          : out    std_logic;
      clk_out2          : out    std_logic;
      -- Status and control signals
      reset             : in     std_logic;
      locked            : out    std_logic;
      clk_in1           : in     std_logic
     );
    end component;
    
	component mavg is
    generic (
        MAX_MAVG_LEN_LOG  : integer := 2
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

signal clk_adc_dclk : std_logic;    
signal clk_adc_p_delayed : std_logic;
signal clk_adc_n_delayed : std_logic;

signal clk_ref_i : std_logic;
signal pll_locked : std_logic;
signal pll_reset : std_logic := '0';
signal assert_pll_counter : integer range 0 to 65535;

signal dataA : std_logic_vector(9 downto 0);
signal dataB : std_logic_vector(9 downto 0);

signal ifclk : std_logic;
signal fdata_d: std_logic_VECTOR(15 downto 0);
--
signal cfg_addrA: std_logic_VECTOR(5 downto 0);	     -- memory addr written to / read out on the SPO
signal cfg_addrA_d: std_logic_VECTOR(5 downto 0);	 -- memory addr written to / read out on the SPO
signal cfg_data_in: std_logic_VECTOR(31 downto 0);	 -- memory location read out on the DPO
signal cfg_data_in_d: std_logic_VECTOR(31 downto 0); -- memory location read out on the DPO (delayed 1 clk)
signal cfg_addrB: std_logic_VECTOR(5 downto 0);
signal cfg_addrB_d: std_logic_VECTOR(5 downto 0);
signal cfg_we: std_logic;
signal cfg_we_d: std_logic;
signal cfg_do_A: std_logic_VECTOR(31 downto 0); -- port A data out (clk)
signal cfg_do_B: std_logic_VECTOR(31 downto 0); -- port B data out (adc_clk)
signal cfg_data_cnt: integer range 0 to (CONFIG_DATA_SIZE-1) := 0;
--
signal y_sin : signed(11 downto 0);
signal x_cos : signed(11 downto 0);

signal flaga_d	 : STD_LOGIC;
signal flaga_id  : std_logic;
signal flaga_idd : std_logic;
signal flagb_d	 : STD_LOGIC;
signal flagb_dd	 : STD_LOGIC;
signal flagb_ddd : STD_LOGIC;
signal flagd_d	 : STD_LOGIC;
signal flagd_dd : STD_LOGIC;
signal slwr_assert_cnt : integer range 0 to (FX3_DMA_BUFFER_SIZE/4) := 0;
signal flag_ep6_ready : std_logic;
signal cnt_after_flagd : integer range 0 to 7;
signal faddr_i     : STD_LOGIC_VECTOR(1 downto 0); 
signal slrd_i      : STD_LOGIC:='1';
signal slwr_i      : STD_LOGIC:='1';
signal sloe_i 		 : STD_LOGIC:='1';
signal LED_i    : STD_LOGIC_VECTOR(3 downto 1):="000";
signal MasterState : STD_LOGIC_VECTOR(3 downto 0):="0000";	 -- Counter to sequence the fifo signals.
signal GetSampleState : STD_LOGIC_VECTOR(2 downto 0):="000"; -- Counter to sequence ADC samples save.
signal DAC_state	 : STD_LOGIC_VECTOR(2 downto 0):="000";	 -- Counter to control DAC output voltages.
signal LA_state	 : STD_LOGIC_VECTOR(2 downto 0):="000";	 -- Counter to control DAC output voltages.
signal ReturnToStreamingState : STD_LOGIC := '0';	 -- MasterState return flag
signal ReturnToFrameRequest : STD_LOGIC := '0';	 -- MasterState return flag

-- OSCILOSCOPE RAM POINTERS --
signal frame_start_pointer : STD_LOGIC_VECTOR (26 downto 0);	-- START OF FRAME (LOCATION OF FIRST SAMPLE)
signal frame_start_pointer_d : STD_LOGIC_VECTOR (26 downto 0);
signal frame_start_pointer_dd : STD_LOGIC_VECTOR (26 downto 0);
signal packet_start_pointer : STD_LOGIC_VECTOR (1 downto 0); 	-- START OF FRAME sent to FX3
signal framesize    : STD_LOGIC_VECTOR (26 downto 0) := std_logic_vector(to_unsigned(10000,27)); -- SIZE OF FRAME BUFFER
signal framesize_d  : STD_LOGIC_VECTOR (26 downto 0) := std_logic_vector(to_unsigned(10000,27)); -- SIZE OF FRAME BUFFER
signal framesize_dd : STD_LOGIC_VECTOR (26 downto 0) := std_logic_vector(to_unsigned(10000,27)); -- SIZE OF FRAME BUFFER
signal pre_trigger : UNSIGNED (26 downto 0);		   -- PreTrigger size
signal pre_trigger_d : UNSIGNED (26 downto 0);
signal pre_trigger_cnt : UNSIGNED (26 downto 0);	-- Sample save counter for preTrigger
signal post_trigger : UNSIGNED (26 downto 0);		-- PostTrigger size
signal saved_sample_cnt : integer range 0 to 2**27-1;
signal saved_sample_cnt_d :integer range 0 to 2**27-1;
--signal saved_sample_cnt_dd : UNSIGNED (13 downto 0);
signal saving_progress : UNSIGNED (26 downto 0);
signal saving_progress_d : UNSIGNED (26 downto 0);
signal saving_progress_dd : UNSIGNED (26 downto 0);
signal saving_progress_ddd : UNSIGNED (26 downto 0);
signal sending_progress : UNSIGNED (26 downto 0);
signal frame_pos_d : UNSIGNED (26 downto 0);
signal send_sample_cnt : integer range 0 to DDR3_MAX_SAMPLES-1 := 0;
signal send_frame_cnt : integer range 0 to 4095;
signal hword_cnt_i : integer range 0 to FRAME_HEADER_SIZE := 0; --header word counter
signal dword_cnt_i : integer range 0 to FX3_DMA_BUFFER_SIZE/4 := 0; --data word counter
signal sent_word_cnt : integer range 0 to 255 := 0;
signal faddr_rdy_cnt_i : integer range 0 to 3 := 0; --data word counter
signal slrd_rdy_cnt : integer range 0 to 7 := 0;
signal slrd_cnt : integer range 0 to FX3_DMA_BUFFER_SIZE-1 := 0;

-- flags --
signal slwr_assert : STD_LOGIC := '1'; -- initally, FX3 buffer is empty			
signal get_new_frame_flag : STD_LOGIC;
signal get_new_frame_flag_d : STD_LOGIC; -- delayed get_new_frame_flag signal (for edge synchronization)
signal get_new_frame_flag_dd : STD_LOGIC;		-- 2 clk delayed get_new_frame_flag signal (for edge synchronization)
signal get_new_frame_flag_ddd : STD_LOGIC;	-- 3 clk
signal new_frame_ready_flag : STD_LOGIC;
signal new_frame_ready_flag_d : STD_LOGIC;
signal cordic_complete_flag : STD_LOGIC;
signal gl_reset : std_logic := '0';  -- global reset (Minimum Reset pulse width for idelayctrl = 60 ns)
                                     -- Reset to ready for IDELAYCTRL = 3.67 us
--signal gl_reset_i : std_logic := '1';

signal ConfigureADC : std_logic :='0';
signal ConfigureVdac : std_logic :='0';
signal faddr_rdy : std_logic;

-- frame save/send sync flags
signal getnewframe : std_logic;
signal getnewframe_d : std_logic;
signal getnewframe_dd : std_logic;
signal newFrameRequestRevcd : std_logic:='0';
signal triggered : STD_LOGIC;
signal triggered_d : STD_LOGIC;
signal triggered_dd : STD_LOGIC;
signal triggered_ddd : STD_LOGIC;
signal triggered_dddd : STD_LOGIC;
signal requestFrame : std_logic;
signal requestFrame_d : std_logic;
signal requestFrame_dd : std_logic;
signal frame_ready_to_send : std_logic;
signal frame_ready_to_send_d : std_logic;
signal sendingFrameSlow : std_logic;
signal ReadingFrame : std_logic:= '0';
signal roll : std_logic;
signal roll_d : std_logic;
signal ScopeConfigChanged : std_logic;
signal cnt_restart_framesave : integer range 0 to 15;
signal cnt_rst_triggered : integer range 0 to 3;
signal sampling_CE : std_logic;


CONSTANT A: STD_LOGIC_VECTOR (3 DownTo 0) := "0000";
CONSTANT B: STD_LOGIC_VECTOR (3 DownTo 0) := "0001";
CONSTANT C: STD_LOGIC_VECTOR (3 DownTo 0) := "0010";
CONSTANT D: STD_LOGIC_VECTOR (3 DownTo 0) := "0011";
CONSTANT E: STD_LOGIC_VECTOR (3 DownTo 0) := "0100";
CONSTANT F: STD_LOGIC_VECTOR (3 DownTo 0) := "0101";
CONSTANT G: STD_LOGIC_VECTOR (3 DownTo 0) := "0110";
CONSTANT H: STD_LOGIC_VECTOR (3 DownTo 0) := "0111";
CONSTANT I: STD_LOGIC_VECTOR (3 DownTo 0) := "1000";

CONSTANT ADC_A: STD_LOGIC_VECTOR (2 DownTo 0) := "000";
CONSTANT ADC_B: STD_LOGIC_VECTOR (2 DownTo 0) := "001";
CONSTANT ADC_C: STD_LOGIC_VECTOR (2 DownTo 0) := "010";
CONSTANT ADC_D: STD_LOGIC_VECTOR (2 DownTo 0) := "011";
CONSTANT ADC_E: STD_LOGIC_VECTOR (2 DownTo 0) := "100";
CONSTANT ADC_F: STD_LOGIC_VECTOR (2 DownTo 0) := "101";

CONSTANT DAC_A: STD_LOGIC_VECTOR (2 DownTo 0) := "000";
CONSTANT DAC_B: STD_LOGIC_VECTOR (2 DownTo 0) := "001";
CONSTANT DAC_C: STD_LOGIC_VECTOR (2 DownTo 0) := "010";
CONSTANT DAC_D: STD_LOGIC_VECTOR (2 DownTo 0) := "011";
CONSTANT DAC_E: STD_LOGIC_VECTOR (2 DownTo 0) := "100";

CONSTANT LA_A: STD_LOGIC_VECTOR (2 DownTo 0) := "000";
CONSTANT LA_B: STD_LOGIC_VECTOR (2 DownTo 0) := "001";
CONSTANT LA_C: STD_LOGIC_VECTOR (2 DownTo 0) := "010";
CONSTANT LA_D: STD_LOGIC_VECTOR (2 DownTo 0) := "011";
CONSTANT LA_E: STD_LOGIC_VECTOR (2 DownTo 0) := "100";
CONSTANT LA_F: STD_LOGIC_VECTOR (2 DownTo 0) := "101";
CONSTANT LA_G: STD_LOGIC_VECTOR (2 DownTo 0) := "110";

-- ADC CLK sample save divider signals
--signal clk_adc_dclk_DIVIDED : STD_LOGIC;
signal timebase : std_logic_vector (4 downto 0);
signal timebase_d : std_logic_vector (4 downto 0);
signal timebase_dd : std_logic_vector (4 downto 0);
signal timebase_ddd : std_logic_vector (4 downto 0);

-- Signal Generator
signal dac_data_1 : std_logic_vector(11 downto 0);
signal dac_data_2 : std_logic_vector(11 downto 0);
signal dac_clk : std_logic;
signal dac_pll_locked : std_logic;
--signal dac_clk_1 : std_logic_vector(11 downto 0);
--signal dac_clk_2 : std_logic_vector(11 downto 0);
signal generator1On : std_logic;
signal generator2On : std_logic;
signal sig_out_enable : std_logic;
signal sig_out_enable_d : std_logic;
signal phase_sync : STD_LOGIC := '0';
signal phase_val : STD_LOGIC_VECTOR(bH downto 0);

-- AWG custom buffer
signal wea_awg : STD_LOGIC;
signal addra_awg     : STD_LOGIC_VECTOR (14 downto 0);
signal dina_awg      : STD_LOGIC_VECTOR (11 downto 0);
signal dina_awg_tmp  : STD_LOGIC_VECTOR (11 downto 0);
signal addrb_awg     : STD_LOGIC_VECTOR (14 downto 0);
signal doutb_awg     : STD_LOGIC_VECTOR (11 downto 0);

-- AWG2 custom buffer
signal wea_awg2 : STD_LOGIC;
signal addra_awg2    : STD_LOGIC_VECTOR (14 downto 0);
signal dina_awg2     : STD_LOGIC_VECTOR (11 downto 0);
signal dina_awg2_tmp : STD_LOGIC_VECTOR (11 downto 0);
signal addrb_awg2    : STD_LOGIC_VECTOR (14 downto 0);
signal doutb_awg2    : STD_LOGIC_VECTOR (11 downto 0);

-- Digital custom buffer
signal wea_dig : STD_LOGIC;
signal addra_dig     : STD_LOGIC_VECTOR (14 downto 0);
signal dina_dig      : STD_LOGIC_VECTOR (11 downto 0);
signal dina_dig_tmp  : STD_LOGIC_VECTOR (11 downto 0);
signal addrb_dig     : STD_LOGIC_VECTOR (14 downto 0);
signal doutb_dig     : STD_LOGIC_VECTOR (11 downto 0);
signal doutb_dig_d   : STD_LOGIC_VECTOR (11 downto 0);

signal digitalClkDivide : unsigned(31 downto 0) := to_unsigned(15,32);
signal digitalClkDivide_H : STD_LOGIC_VECTOR (15 downto 0);
signal digitalClkDivide_L : STD_LOGIC_VECTOR (15 downto 0);
signal digitalClkDivide_tmp : STD_LOGIC_VECTOR (31 downto 0);
signal digitalClkDivide_cnt : unsigned(31 downto 0);

signal buffersel : std_logic_vector (1 downto 0);

-- DELAY registers
signal dataAd	: SIGNED (9 downto 0);
signal dataAdd	: SIGNED (9 downto 0);
signal dataBd	: SIGNED (9 downto 0);
signal dataBdd	: SIGNED (9 downto 0);
signal dataDd : std_logic_vector (11 downto 0);
signal dataD1d : std_logic_vector (11 downto 0);
signal dora_i : std_logic;
signal dorb_i : std_logic;
signal trig_signal 	: SIGNED (9 downto 0);
signal trig_signal_d : SIGNED (9 downto 0);
signal triggered_led : std_logic;
signal triggered_led_d : std_logic;

signal an_trig_d : std_logic;
signal an_trig_dd : std_logic;
signal an_trig_ddd : std_logic;
signal an_trig_dddd : std_logic;

signal clearflags : STD_LOGIC:='0';
signal clearflags_d : STD_LOGIC :='0';

-- RAM allocation for oscilloscope configuration
--type memory_array is array(1 to 64) of STD_LOGIC_VECTOR (15 downto 0);
--signal mem : memory_array:=((others=> (others=>'0')));
signal trig_level : SIGNED (9 downto 0);
signal trig_level_d : SIGNED (9 downto 0);
signal trig_level_r_dd : SIGNED (9 downto 0);
signal trig_level_f_dd : SIGNED (9 downto 0);
signal trig_hysteresis : SIGNED (9 downto 0);
signal trig_hysteresis_d : SIGNED (9 downto 0);
signal trigger_source : STD_LOGIC_VECTOR (2 downto 0);
signal trigger_source_d : STD_LOGIC_VECTOR (2 downto 0);
signal trigger_slope : STD_LOGIC_VECTOR (1 downto 0);
signal trigger_slope_d : STD_LOGIC_VECTOR (1 downto 0);
signal trigger_mode : STD_LOGIC_VECTOR (1 downto 0);
signal trigger_mode_d : STD_LOGIC_VECTOR (1 downto 0);
signal trigger_mode_dd : STD_LOGIC_VECTOR (1 downto 0);
signal s_trigger_mode : STD_LOGIC_VECTOR (1 downto 0);
signal s_trigger_rearm : std_logic;
signal s_trigger_rearm_completed : std_logic;
signal holdOff : UNSIGNED (31 downto 0);
signal holdOff_d : UNSIGNED (31 downto 0);
signal t_start : std_logic; -- holdoff input: start timer
signal o_end : std_logic;   -- holdoff output: timer ended
signal VgainA : std_logic_vector(11 downto 0);
signal VgainA_d : std_logic_vector(11 downto 0);
signal VgainB : std_logic_vector(11 downto 0);
signal VgainB_d : std_logic_vector(11 downto 0);
signal OffsetA : std_logic_vector(11 downto 0);
signal OffsetA_d : std_logic_vector(11 downto 0);
signal OffsetA_2d : std_logic_vector(11 downto 0);
signal OffsetA_3d : std_logic_vector(11 downto 0);
signal OffsetA_4d : std_logic_vector(11 downto 0);
signal OffsetA_5d : std_logic_vector(11 downto 0);
signal OffsetA_6d : std_logic_vector(11 downto 0);
signal OffsetA_7d : std_logic_vector(11 downto 0);
signal OffsetA_8d : std_logic_vector(11 downto 0);
signal OffsetA_9d : std_logic_vector(11 downto 0);
signal OffsetB : std_logic_vector(11 downto 0);
signal OffsetB_d : std_logic_vector(11 downto 0);
signal analogTrigTresh : std_logic_vector(9 downto 0);
signal fdata_tmp : std_logic_vector(15 downto 0);
signal mem_tmp : std_logic_vector(15 downto 0);
signal mem_tmp_d : std_logic_vector(15 downto 0);

-- digital logic analyzer signals
signal dt_triggered : std_logic;
signal dt_delayMaxcnt_0 : std_logic_vector(15 downto 0);
signal dt_delayMaxcnt_1 : std_logic_vector(15 downto 0);
signal dt_delayMaxcnt_2 : std_logic_vector(15 downto 0);
signal dt_delayMaxcnt_3 : std_logic_vector(15 downto 0);
signal digital_trig_patternA_0 : std_logic_vector(15 downto 0);
signal digital_trig_patternA_1 : std_logic_vector(15 downto 0);
signal digital_trig_patternA_2 : std_logic_vector(15 downto 0);
signal digital_trig_patternA_3 : std_logic_vector(15 downto 0);
signal digital_trig_patternB_0 : std_logic_vector(15 downto 0);
signal digital_trig_patternB_1 : std_logic_vector(15 downto 0);
signal digital_trig_patternB_2 : std_logic_vector(15 downto 0);
signal digital_trig_patternB_3 : std_logic_vector(15 downto 0);
signal dt_enable : std_logic;


type trig_patternA_mem is array(0 to 3) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal digital_trig_patternA : trig_patternA_mem :=((others=> (others=>'0')));
type trig_patternB_mem is array(0 to 3) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal digital_trig_patternB : trig_patternB_mem :=((others=> (others=>'0')));
type digital_trig_mask_mem is array(0 to 3) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal digital_trig_mask : digital_trig_mask_mem :=((others=> (others=>'0')));
signal dt_stage : integer range 0 to 3;
signal dt_stage_capture : integer range 0 to 3; --stage number when trigger fires
signal dt_stage_capture_d : integer range 0 to 3;
type dt_delaycnt_mem is array(0 to 3) of unsigned (15 downto 0);
signal dt_delaycnt : dt_delaycnt_mem :=((others=> (others=>'0')));
type dt_delayMaxcnt_mem is array(0 to 3) of unsigned (15 downto 0);
signal dt_delayMaxcnt : dt_delayMaxcnt_mem :=((others=> (others=>'0')));
type dt_delayMaxcnt_d_mem is array(0 to 3) of unsigned (15 downto 0);
signal dt_delayMaxcnt_d : dt_delayMaxcnt_d_mem :=((others=> (others=>'0')));
type dt_edge_trigger_mem is array(0 to 3) of std_logic;
signal dt_edge_trigger : dt_edge_trigger_mem := (others=> '0');
signal dtSerial : std_logic;
signal dtSerial_d : std_logic;
signal dtSerialCh : integer range 0 to 15;
signal dtSerialCh_d : integer range 0 to 15;
signal dir_11_6_i : std_logic;
signal dir_5_0_i : std_logic;
signal digital_WiperCode : std_logic_vector (7 downto 0);
signal digital_Direction : std_logic_vector (1 downto 0);
signal digital_Direction_d : std_logic_vector (1 downto 0);
signal digital_Direction_dd : std_logic_vector (1 downto 0);
signal digital_OutputWord : std_logic_vector (15 downto 0);
signal digital_OutputWord_d : std_logic_vector (15 downto 0);
signal digital_OutputWordMask : std_logic_vector (15 downto 0);
signal digital_OutputWordMask_d : std_logic_vector (15 downto 0);

-- ADC SPI interface counters and registers
signal adc_cfg_reg : std_logic_vector (15 downto 0);
signal adc_cfg_reg_d : std_logic_vector (15 downto 0);
signal adc_cfg_data : std_logic_vector (7 downto 0);
signal adc_cfg_data_d : std_logic_vector (7 downto 0);
signal adc_spi_data : std_logic_vector (23 downto 0);
signal sclk_counter : integer range 0 to 15;     -- DAC sclk divider
signal adc_sclk_counter : integer range 0 to 7; -- ADC sclk divider
signal adc_spi_bit_count : integer range 0 to 15:=15;
signal adc_configured_flag : STD_LOGIC;
signal configure_dac : STD_LOGIC;
signal adc_cs_i : STD_LOGIC := '1';
signal adc_sclk_i : STD_LOGIC;
signal adc_sdin_i : STD_LOGIC;
signal adcA_spi_busy : std_logic;
signal adcB_spi_busy : std_logic;

-- DPOT SPI interface
signal dpot_spi_busy : std_logic;
signal dpot_spi_write_trig : std_logic;
signal dpot_spi_WiperCode : std_logic_vector(15 downto 0);

-- V-DAC SPI interface (gain/offset control)
type spi_array is array(1 to 4) of STD_LOGIC_VECTOR (15 downto 0);
signal dac_cfg_array : spi_array:=((others=> (others=>'0')));
signal dac_cfg_array3_d : STD_LOGIC_VECTOR (15 downto 0);
signal dac_cfg_array3_2d : STD_LOGIC_VECTOR (15 downto 0);
signal dac_cfg_array3_3d : STD_LOGIC_VECTOR (15 downto 0);
signal dac_cfg_array3_4d : STD_LOGIC_VECTOR (15 downto 0);
signal dac_cfg_reg : std_logic_vector (15 downto 0);
signal dac_array_count : integer range 1 to 4:=1; -- DAC out selection
signal dac_cs_i : STD_LOGIC :='1';
signal dac_sclk_i : STD_LOGIC;
signal dac_sdin_i : STD_LOGIC;
signal dac_spi_busy : std_logic;
signal DAC_pogramming_start : std_logic;
signal DAC_programming_finished : std_logic;
signal cnt_dac_out_stable : integer range 0 to 16383;

---- AWG internal signals
signal generator1Voltage : sfixed(0 downto -11);
signal generator1Type : std_logic_vector (3 downto 0);
signal generator1Delta : std_logic_vector(bH-bL downto 0);
signal generator1Delta_H : STD_LOGIC_VECTOR(15 downto 0);
signal generator1Delta_L : STD_LOGIC_VECTOR(15 downto 0);
signal generator1Offset : signed (11 downto 0);
signal generator1Duty : signed(11 downto 0);

signal generator2Voltage : sfixed(0 downto -11);
signal generator2Type : std_logic_vector (3 downto 0);
signal generator2Delta : std_logic_vector(bH-bL downto 0);
signal generator2Delta_H : STD_LOGIC_VECTOR(15 downto 0);
signal generator2Delta_L : STD_LOGIC_VECTOR(15 downto 0);
signal generator2Offset : signed (11 downto 0);
signal generator2Duty : signed(11 downto 0);

signal clk_gen : std_logic;
signal genSignal_1 : signed (11 downto 0);
signal genSIgnal_2 : signed (11 downto 0);
signal genSignal_1_d : signed (9 downto 0);
signal genSignal_2_d : signed (9 downto 0);
signal genSignal_1_dd : signed (9 downto 0);
signal genSignal_2_dd : signed (9 downto 0);
signal accumulate_addra_awg : std_logic := '0'; -- start addra counter
signal accumulate_addra_dig : std_logic := '0'; -- start addra counter

-- analog switching
signal ch1_dc_i  : STD_LOGIC;
signal ch2_dc_i  : STD_LOGIC;
signal ch1_gnd_i : STD_LOGIC;
signal ch2_gnd_i : STD_LOGIC;
signal ch1_k_i : STD_LOGIC;
signal ch2_k_i : STD_LOGIC;

-- delay counters and flags
signal dasync_wait_cnt : integer range 0 to 15;
signal auto_trigger : std_logic;
signal auto_trigger_d : std_logic;
signal auto_trigger_cnt : integer range 0 to 400000;
signal auto_trigger_maxcnt : integer range 0 to 400000;
signal adc_clk_divide_cnt : integer range 0 to 99999999;
signal adc_clk_divide_maxcnt : integer range 0 to 199999999;
--signal Timer_cnt : integer range 0 to 4095 := 0;
signal Timer_cnt : integer range 0 to (2**26)-1 := 0;
signal startup_timer_cnt : integer range 0 to 250000 := 0;
signal clk_div_cnt : integer range 0 to 100*(10**6); 
signal clk_div_cnt_2 : integer range 0 to 250*(10**6);
signal cnt_rd_last : std_logic := '0';
signal cnt_dw_stop : integer range 0 to 7 := 0;

--LUT delay line signals
signal lut_delay_rst : std_logic;
signal lut_reg_out : std_logic_vector(31 downto 0);
signal lut_reg_out_d : std_logic_vector(31 downto 0);
signal lut_reg_out_dd : std_logic;
signal an_trig_delay : std_logic_vector(5 downto 0);
signal an_trig_delay_d : std_logic_vector(5 downto 0);
signal an_trig_delay_dd : unsigned(5 downto 0);
signal an_trig_delay_max : unsigned(5 downto 0);
signal an_trig_delay_min : unsigned(5 downto 0) :="000001";
signal lut_reg_out_tmp0 : std_logic_vector(15 downto 0);
signal lut_reg_out_tmp1 : std_logic_vector(15 downto 0);
signal lut_reg_out_tmp0_d : std_logic_vector(15 downto 0);
signal lut_reg_out_tmp1_d : std_logic_vector(15 downto 0);
signal lut_reg_out_tmp0_dd : std_logic_vector(15 downto 0);
signal lut_reg_out_tmp1_dd : std_logic_vector(15 downto 0);

--ETS
signal ets_on : std_logic;
signal ets_on_d : std_logic;
signal ets_test  : std_logic;
--ADC interleaving
signal adc_interleaving : std_logic;
signal adc_interleaving_d : std_logic;

--Debug Signals
signal DebugMState : integer range 0 to 7;
signal DebugADCState : integer range 0 to 7;
signal DebugADCState_d : integer range 0 to 7;
signal PreTrigSaving : std_logic := '0';
signal DDR3DataIn : std_logic_vector(31 downto 0);
signal DataInTest : unsigned (31 downto 0);
signal DataWriteEn : std_logic;
signal DataWriteEn_d : std_logic;
signal PreTrigWriteEn : std_logic;
signal PreTrigWriteEn_d : std_logic;
signal PreTrigLen : std_logic_vector (26 downto 0);
signal DataOut : std_logic_vector(31 downto 0);
signal DataOutEnable : std_logic;
signal DataOutEnable_cnt : integer range 0 to 15;
signal DataOutValid : std_logic;
signal init_calib_complete : std_logic;
signal init_calib_complete_d : std_logic;
signal calib_done : std_logic;
signal read_calib_start : std_logic :='0';
signal read_calib_source : std_logic := '0';  -- '0' calibrate CH1, '1' calibrate CH2
signal device_temp : std_logic_vector(11 downto 0);
signal device_temp_d : std_logic_vector(11 downto 0);
signal device_temp_dd : std_logic_vector(11 downto 0);
signal ram_rdy : std_logic;

--adc post-processing
signal mavg_enA: std_logic;
signal mavg_enA_d: std_logic;
signal mavg_datavalidA : std_logic;
signal mavg_dataA : std_logic_vector(9 downto 0);
signal mavg_enB: std_logic;
signal mavg_enB_d: std_logic;
signal mavg_datavalidB : std_logic;
signal mavg_dataB : std_logic_vector(9 downto 0);

-- attribute strings
attribute KEEP: boolean;
attribute ASYNC_REG: boolean;
attribute mark_debug: boolean;

-- assign KEEP attributes to help debugging
attribute KEEP of an_trig_d: signal is true;
attribute KEEP of DebugMState: signal is true;
attribute KEEP of DebugADCState: signal is true;
attribute KEEP of DebugADCState_d: signal is true;
attribute ASYNC_REG of DebugADCState_d: signal is true;
attribute KEEP of newFrameRequestRevcd: signal is true;
attribute KEEP of slwr_assert_cnt: signal is true;
attribute KEEP of cnt_dw_stop: signal is true;
attribute KEEP of dword_cnt_i: signal is true;

-- CDC registers (clock domain crossing signals)
attribute KEEP of send_sample_cnt: signal is true;
attribute KEEP of timebase: signal is true;
attribute KEEP of timebase_d: signal is true;
attribute KEEP of timebase_dd: signal is true;
attribute KEEP of timebase_ddd: signal is true;
attribute ASYNC_REG of timebase_d: signal is true;
attribute ASYNC_REG of timebase_dd: signal is true;
attribute ASYNC_REG of timebase_ddd: signal is true;
attribute KEEP of frame_start_pointer: signal is true;
attribute KEEP of frame_start_pointer_d: signal is true;
attribute KEEP of frame_start_pointer_dd: signal is true;
attribute ASYNC_REG of frame_start_pointer_d: signal is true;
attribute ASYNC_REG of frame_start_pointer_dd: signal is true;
attribute KEEP of saving_progress: signal is true;
attribute KEEP of saving_progress_d: signal is true;
attribute KEEP of saving_progress_dd: signal is true;
attribute ASYNC_REG of saving_progress_d: signal is true;
attribute ASYNC_REG of saving_progress_dd: signal is true;
attribute KEEP of genSignal_1_d: signal is true;
attribute ASYNC_REG of genSignal_1_d: signal is true;
attribute KEEP of genSignal_2_d: signal is true;
attribute ASYNC_REG of genSignal_2_d: signal is true;
attribute KEEP of genSignal_1_dd: signal is true;
attribute ASYNC_REG of genSignal_1_dd: signal is true;
attribute KEEP of genSignal_2_dd: signal is true;
attribute ASYNC_REG of genSignal_2_dd: signal is true;
attribute KEEP of an_trig_delay_d: signal is true;
attribute KEEP of an_trig_delay_dd: signal is true;
attribute ASYNC_REG of an_trig_delay_d: signal is true;
attribute ASYNC_REG of an_trig_delay_dd: signal is true;
attribute KEEP of clearflags: signal is true;
attribute KEEP of clearflags_d: signal is true;
attribute ASYNC_REG of clearflags_d: signal is true;
attribute KEEP of requestFrame: signal is true;
attribute KEEP of requestFrame_d: signal is true;
attribute ASYNC_REG of requestFrame_d: signal is true;
attribute KEEP of sig_out_enable: signal is true;
attribute KEEP of sig_out_enable_d: signal is true;
attribute ASYNC_REG of sig_out_enable_d: signal is true;
attribute KEEP of triggered: signal is true;
attribute ASYNC_REG of triggered: signal is true;
attribute KEEP of triggered_d: signal is true;
attribute ASYNC_REG of triggered_d: signal is true;
attribute KEEP of triggered_dd: signal is true;
attribute ASYNC_REG of triggered_dd: signal is true;
attribute KEEP of triggered_ddd: signal is true;
attribute ASYNC_REG of triggered_ddd: signal is true;
attribute KEEP of triggered_dddd: signal is true;
attribute ASYNC_REG of triggered_dddd: signal is true;
attribute KEEP of framesize_d: signal is true;
attribute ASYNC_REG of framesize_d: signal is true;
attribute KEEP of framesize_dd: signal is true;
attribute ASYNC_REG of framesize_dd: signal is true;
attribute KEEP of init_calib_complete_d: signal is true;
attribute ASYNC_REG of init_calib_complete_d: signal is true;
attribute KEEP of flaga_id: signal is true;
attribute ASYNC_REG of flaga_id: signal is true;
attribute KEEP of flaga_idd: signal is true;
attribute ASYNC_REG of flaga_idd: signal is true;

attribute KEEP of getnewframe_d: signal is true;
attribute ASYNC_REG of getnewframe_d: signal is true;
attribute KEEP of getnewframe_dd:  signal is true;
attribute ASYNC_REG of getnewframe_dd: signal is true;

--attribute KEEP of : signal is true;
--attribute ASYNC_REG of : signal is true;
--attribute KEEP of : signal is true;
--attribute ASYNC_REG of : signal is true;
--attribute KEEP of : signal is true;
--attribute ASYNC_REG of : signal is true;

attribute mark_debug of DebugMState : signal is true;
attribute mark_debug of DebugADCState_d : signal is true;
attribute mark_debug of slwr_i : signal is true;
attribute mark_debug of slrd_i : signal is true;
attribute mark_debug of flaga_d : signal is true;
attribute mark_debug of flagb_d : signal is true;
attribute mark_debug of flagd_d : signal is true;
attribute mark_debug of adc_cs_i : signal is true;
attribute mark_debug of adc_sclk_i : signal is true;
attribute mark_debug of adc_sdin_i : signal is true;
attribute mark_debug of ConfigureADC : signal is true;
attribute mark_debug of Timer_cnt : signal is true;
attribute mark_debug of dataA : signal is true;
attribute mark_debug of dataB : signal is true;
attribute mark_debug of DataOutValid : signal is true;
attribute mark_debug of DataOut : signal is true;
attribute mark_debug of DataOutEnable : signal is true;
attribute mark_debug of dac_cs_i : signal is true;
attribute mark_debug of dac_sclk_i : signal is true;
attribute mark_debug of dac_sdin_i : signal is true;
attribute mark_debug of ConfigureVdac : signal is true;
attribute mark_debug of gl_reset : signal is true;
attribute mark_debug of init_calib_complete : signal is true;
attribute mark_debug of cfg_we : signal is true;
attribute mark_debug of cfg_addrA : signal is true;
attribute mark_debug of cfg_do_A : signal is true;
attribute mark_debug of cfg_data_in_d : signal is true;
attribute mark_debug of slwr_assert : signal is true;
attribute mark_debug of saved_sample_cnt : signal is true;
attribute mark_debug of send_sample_cnt : signal is true;
attribute mark_debug of DataWriteEn : signal is true;
attribute mark_debug of trigger_mode_dd : signal is true;
attribute mark_debug of getnewframe_dd : signal is true;
attribute mark_debug of getnewframe_d : signal is true;
attribute mark_debug of newFrameRequestRevcd : signal is true;

attribute mark_debug of dina_awg   : signal is true;
attribute mark_debug of dina_awg2  : signal is true;
attribute mark_debug of addra_awg  : signal is true;
attribute mark_debug of addra_awg2 : signal is true;
attribute mark_debug of wea_awg    : signal is true;
attribute mark_debug of BufferSel  : signal is true;
attribute mark_debug of faddr_i    : signal is true;
attribute mark_debug of accumulate_addra_awg : signal is true;
attribute mark_debug of slrd_rdy_cnt         : signal is true;
attribute mark_debug of slrd_cnt   : signal is true;

attribute mark_debug of dpot_spi_WiperCode   : signal is true;
attribute mark_debug of dpot_spi_write_trig  : signal is true;
attribute mark_debug of dpot_sck : signal is true;
attribute mark_debug of dpot_cs  : signal is true;
attribute mark_debug of dpot_si  : signal is true;

attribute mark_debug of slwr_assert_cnt: signal is true;
attribute mark_debug of cnt_dw_stop: signal is true;
attribute mark_debug of dword_cnt_i: signal is true;

begin

ADC_interface: adc_if
port map (
    i_clk_p => clk_adc_p,
    i_clk_n => clk_adc_n,
    i_clk_ref => clk_ref_i,
    i_reset_n => pll_locked,
    i_en_fifo => calib_done,
    i_read_calib_start => read_calib_start,
    i_read_calib_source => read_calib_source,
    i_data_1_p => dataA_p,
    i_data_1_n => dataA_n, 
    i_data_2_p => dataB_p, 
    i_data_2_n => dataB_n,     
    o_clk => clk_adc_dclk,
    o_data_1 => dataA,
    o_data_2 => dataB
    );
    
RAM_DDR3_inst: RAM_DDR3
port map (
       -- TOP level signals
       sys_clk_i => clk_adc_dclk,
       clk_ref_i => clk_ref_i,
       ui_clk => ifclk,
       rst => clearflags,
       FrameSize => framesize_dd,
       DataIn => DDR3DataIn,
       PreTrigSaving => PreTrigSaving,
       PreTrigWriteEn => PreTrigWriteEn_d,
       PreTrigLen => std_logic_vector(pre_trigger_d),
       DataWriteEn => DataWriteEn_d,
       FrameSaveEnd => t_start,
       DataOut => DataOut,
       DataOutEnable => DataOutEnable,
       DataOutValid => DataOutValid,
       ReadingFrame => ReadingFrame,
       ram_rdy => ram_rdy,
       init_calib_complete => init_calib_complete,
       device_temp => device_temp,
       ddr3_dq      => ddr3_dq,    
       ddr3_dqs_p   => ddr3_dqs_p,  
       ddr3_dqs_n   => ddr3_dqs_n,  
       ddr3_addr    => ddr3_addr,   
       ddr3_ba      => ddr3_ba,     
       ddr3_ras_n   => ddr3_ras_n,  
       ddr3_cas_n   => ddr3_cas_n,  
       ddr3_we_n    => ddr3_we_n,   
       ddr3_reset_n => ddr3_reset_n,
       ddr3_ck_p    => ddr3_ck_p,   
       ddr3_ck_n    => ddr3_ck_n,   
       ddr3_cke     => ddr3_cke,
       ddr3_odt     => ddr3_odt
);
 
--sample_buffer: SDP_BRAM_10240x36b
--	port map (
--         clka => clk_adc_dclk,
--         wea => wea,
--         addra => addra,
--         dina => dina,
--         clkb => ifclk,
--         addrb => addrb,
--         doutb => doutb
--       );	  

config_RAM: SDP_RAM_64x32b
	port map (
		addr1 => cfg_addrA, -- memory location written to and memory location read out on the SPO
		di1 => cfg_data_in,
		addr2 => cfg_addrB, -- memory location read out on the DPO
		clk1 => ifclk,
		we => cfg_we,
		clk2 => clk_adc_dclk,
		do1 => cfg_do_A, -- port A data out (clk)
		do2 => cfg_do_B  -- port B data out (adc_clk)
	);

awg_custom_signal: SDP_BRAM_custom_signal
    generic map (DATA_DEPTH => AWG_MAX_SAMPLES, DATA_WIDTH => 12)
	port map (
		clka => ifclk, -- RAM write clk
		wea => wea_awg,
		addra => addra_awg,
		dina => dina_awg,
		clkb => clk_gen, -- RAM read clk
		addrb => addrb_awg,
		doutb => doutb_awg);
		
awg2_custom_signal: SDP_BRAM_custom_signal
    generic map (DATA_DEPTH => AWG_MAX_SAMPLES, DATA_WIDTH => 12)
	port map (
		clka => ifclk, -- RAM write clk
		wea => wea_awg2,
		addra => addra_awg2,
		dina => dina_awg2,
		clkb => clk_gen, -- RAM read clk
		addrb => addrb_awg2,
		doutb => doutb_awg2);

dig_custom_signal: SDP_BRAM_custom_signal
    generic map (DATA_DEPTH => AWG_MAX_SAMPLES, DATA_WIDTH => 12)
	port map (
		clka => ifclk, -- RAM write clk
		wea => wea_dig,
		addra => addra_dig,
		dina => dina_dig,
		clkb => clk_adc_dclk, -- RAM read clk
		addrb => addrb_dig,
		doutb => doutb_dig);

lut_delay_inst: lut_delay
   port map (
		clk => clk_adc_dclk,
		rst => lut_delay_rst,
		an_trig_p => an_trig_p,
		an_trig_n => an_trig_n,
		an_trig_d => an_trig_d,
		tap_reg_out => lut_reg_out
		);
		
signal_generator_inst: awg_core
port map (
	    clk_in => clk_gen,
	    --Signal Generator(clk) enable
	    generator1On => generator1On AND sig_out_enable_d,
	    generator2On => generator2On AND sig_out_enable_d,
	    phase_sync => phase_sync,
	    phase_val => phase_val,
	    --AWG1
	 	genSignal_1 => genSignal_1,
	    ram_addrb_awg_1 => addrb_awg,
	    generatorType_1 => generator1Type,
	    generatorVoltage_1 => generator1Voltage,
	    generatorOffset_1 => generator1Offset,
	    generatorDuty_1 => generator1Duty,
	    generatorDelta_1 => generator1Delta,
 	    generatorCustomSample_1 => doutb_awg,
		--AWG2
		genSignal_2 => genSignal_2,
		ram_addrb_awg_2 => addrb_awg2,
	    generatorType_2 => generator2Type,
	    generatorVoltage_2 => generator2Voltage,
	    generatorOffset_2 => generator2Offset,
	    generatorDuty_2 => generator2Duty,
	    generatorDelta_2 => generator2Delta,
	    generatorCustomSample_2 => doutb_awg2,	
   	    --DAC programming signals
	    dac_data_1 => dac_data_1,
	    dac_data_2 => dac_data_2,
	    dac_clk => dac_clk
		);
			
dac_interface: se_to_ddr
port map (
        i_clk => dac_clk,
        o_clk => dac_clk_1,
        o_clk_inv => dac_clk_2,
        i_data_1 => dac_data_1,
        i_data_2 => dac_data_2,
        o_data_ddr => dac_data,
        pll_locked => dac_pll_locked
        );        
        
pwm_output_inst: pwm
port map (
		clk => clk_adc_dclk,
        v_set => AnalogTrigTresh,
        pwm_out => an_trig_level
		);
		
dpot_spi_interface: spi
generic map (SPI_LENGTH => 16)
port map (
		clk => ifclk,
        rst => '0',
        clk_divide => "11111",					    -- POT:0, POT:1 are midscale after power-up
        spi_data =>	dpot_spi_WiperCode,
        spi_write_trig => dpot_spi_write_trig,
		sck_idle_value => '1',
		spi_busy => dpot_spi_busy,
        cs => dpot_cs,
        sck => dpot_sck,
        si => dpot_si
		);
			
ADC_CH1_spi_interface: spi
generic map (SPI_LENGTH => 24)
port map (
		clk => ifclk,			
        rst => '0',
        --clk_divide =>	"01110",
        clk_divide =>	"11101",
        spi_data =>	adc_spi_data,
        spi_write_trig =>	ConfigureADC,
		sck_idle_value => '0',
		spi_busy => adcA_spi_busy,
        cs => adc_cs_i,				
        sck => adc_sclk_i,			
        si => adc_sdin_i
		);
				
VDAC_spi_interface: spi
generic map (SPI_LENGTH => 16)
port map (
		clk => ifclk,			
        rst => '0',
        --clk_divide =>	"10011",
        clk_divide =>	"11101",
        spi_data =>	dac_cfg_reg,
        spi_write_trig => configureVdac,
		sck_idle_value => '1',
		spi_busy => dac_spi_busy,
        cs => dac_cs_i,				
        sck => dac_sclk_i,
		si => dac_sdin_i
		);

Holdoff_timer: timer
PORT MAP(
	clk => clk_adc_dclk,
	t_reset => clearflags_d,	--input: reset timer
	t_start => t_start,			--input: start timer
	holdoff => std_logic_vector(holdOff_d),   --input: select duration
	o_end => o_end					--output: asserted when timer has finshed
);

trigger_led_blink: blink 
PORT MAP(
	clk => ifclk,
	reset => clearflags,
	trigd => triggered_dddd,
	led_out => LED_i(3)
);

Inst_clk_divider_wCE: clk_divider_wCE
PORT MAP(
	clk => clk_adc_dclk,
	reset => clearflags_d,
	timebase => timebase_d,
	out_CE => sampling_CE
);

logic_analyzer: LA_core
port map(
    clk_in => clk_adc_dclk,
    dt_enable => dt_enable,            
    dataD => dataDd, 
    digital_trig_mask_0 => digital_trig_mask(0),
    digital_trig_mask_1 => digital_trig_mask(1),
    digital_trig_mask_2 => digital_trig_mask(2),
    digital_trig_mask_3 => digital_trig_mask(3),
    digital_trig_patternA_0 => digital_trig_patternA(0),
    digital_trig_patternA_1 => digital_trig_patternA(1),
    digital_trig_patternA_2 => digital_trig_patternA(2),
    digital_trig_patternA_3 => digital_trig_patternA(3),
    digital_trig_patternB_0 => digital_trig_patternB(0),
    digital_trig_patternB_1 => digital_trig_patternB(1),
    digital_trig_patternB_2 => digital_trig_patternB(2),
    digital_trig_patternB_3 => digital_trig_patternB(3),
    dt_stage_capture => std_logic_vector(to_unsigned(dt_stage_capture,2)),
    dt_delayMaxcnt_0 => std_logic_vector(dt_delayMaxcnt(0)(LA_COUNTER_WIDTH-1 downto 0)),
    dt_delayMaxcnt_1 => std_logic_vector(dt_delayMaxcnt(1)(LA_COUNTER_WIDTH-1 downto 0)),
    dt_delayMaxcnt_2 => std_logic_vector(dt_delayMaxcnt(2)(LA_COUNTER_WIDTH-1 downto 0)),
    dt_delayMaxcnt_3 => std_logic_vector(dt_delayMaxcnt(3)(LA_COUNTER_WIDTH-1 downto 0)),
    dtSerial => dtSerial,
    dtSerialCh => std_logic_vector(to_unsigned(dtSerialCh,4)),
    dt_triggered => dt_triggered,
    reset => clearflags_d
    );

    -- Create 200 Mhz clk_ref
--clk_gen_pll_inst: clk_gen_pll
--Port map ( clk_in => clk_adc_dclk,
--           clk_out_1 => clk_ref_i,
--           clk_out_2 => clk_gen,
--           pll_locked => pll_locked);

clk_wiz_0_pll : clk_wiz_0
   port map ( 
  -- Clock out ports  
   clk_out1 => clk_ref_i,
   clk_out2 => clk_gen,
  -- Status and control signals                
   reset => pll_reset,
   locked => pll_locked,
   -- Clock in ports
   clk_in1 => clk_adc_dclk
 );

mavg_ch1: mavg
  generic map (MAX_MAVG_LEN_LOG => 2) 
  PORT MAP (
      i_clk => clk_adc_dclk,
      i_rst => clearflags_d,
      mavg_len_log => 2,
      i_data_en => mavg_enA,
      i_data => dataA,
      o_data_valid => mavg_datavalidA,
      o_data => mavg_dataA
);

mavg_ch2: mavg
  generic map (MAX_MAVG_LEN_LOG => 2) 
  PORT MAP (
      i_clk => clk_adc_dclk,
      i_rst => clearflags_d,
      mavg_len_log => 2,
      i_data_en => mavg_enB,
      i_data => dataB,
      o_data_valid => mavg_datavalidB,
      o_data => mavg_dataB
);

clk_fx3 <= not(ifclk);
slcs <= '0';
		
LED(1) <= LED_i(1) OR NOT(init_calib_complete_d);
LED(2) <= LED_i(2) OR NOT(init_calib_complete_d);
LED(3) <= LED_i(3) OR NOT(init_calib_complete_d);
slrd_sloe  <= slrd_i;
slwr  <= slwr_i;
faddr <= faddr_i;
--sloe  <= sloe_i;

adc_sclk <= adc_sclk_i;
adc_sdin <= adc_sdin_i; -- 1 -> 0 transiotion resets clock
adcA_cs <= adc_cs_i;
adcB_cs <= adc_cs_i;

dasclk <= dac_sclk_i; --data is sampled on rising edge of sclk
dasdin <= dac_sdin_i;
dasync <= dac_cs_i;

ch1_dc  <= ch1_dc_i;
ch2_dc  <= ch2_dc_i;
ch1_gnd <= ch1_gnd_i;
ch2_gnd <= ch2_gnd_i;
ch1_k <= ch1_k_i;
ch2_k <= ch2_k_i;
	
cc_ab  <= NOT(adc_interleaving_d);
pktend <= '1';  -- TODO: use pktend for slow capture speeds

DDR3DataIn <= std_logic_vector(dataAd) & std_logic_vector(dataBd) & dataDd(11 downto 0);
--DDR3DataIn <= std_logic_vector(to_unsigned(saved_sample_cnt_d,32)); --* debug!
--DDR3DataIn <=   std_logic_vector(DataInTest (9 downto 0))
--            & std_logic_vector(DataInTest (9 downto 0))
--            & std_logic_vector(DataInTest(11 downto 0));

ADC_interface_rising: process(clk_adc_dclk)

begin
	
	if (rising_edge(clk_adc_dclk)) then	
                                    
        -- assert global reset after 8us and hold it for 8us
        if startup_timer_cnt = 4000 then
            gl_reset <= '0';
        elsif startup_timer_cnt < 2000 then
            gl_reset <= '0';
            startup_timer_cnt <= startup_timer_cnt + 1;
        else
            gl_reset <= '1';
            startup_timer_cnt <= startup_timer_cnt + 1;
        end if;
        
        -- read digital channels
		dataDd <= dataD;
		--dataDd <= "00" & std_logic_vector(unsigned(genSignal_1_dd));  --test (debug)!
        -- read ADC data and enable averaging
        if mavg_enA_d = '1' then
            dataAd <= signed(mavg_dataA);
        else
            dataAd <= signed(dataA);
        end if;
        if mavg_enB_d = '1' then
            dataBd <= signed(mavg_dataB);
        else
            dataBd <= signed(dataB);
        end if;

        genSignal_1_d <= genSignal_1(11 downto 2);
        genSignal_1_dd <= genSignal_1_d;
        genSignal_2_d <= genSignal_2(11 downto 2);
        genSignal_2_dd <= genSignal_2_d;
        
		------------------------------
		--  DIGITAL CH. DIRECTION   --
		------------------------------
		-- select digital channels direction: IN or OUT (74AVCH16T245 datasheet)
		dir_11_6 <= digital_direction(1); -- if '0' = OUT  FPGA=portB -->-- portA=Connector
		dir_5_0 <= digital_direction(0);  -- if '1' = IN   FPGA=portB --<-- portA=Connector
		
		--LED_1=>ON if power=ON and at least one byte direction is OUT
		LED_i(1) <= (sig_out_enable_d AND (digital_direction(1) NAND digital_direction(0)));
		
		case digital_direction(1) is
			when '0' =>
				dataD(11 downto 6) <= (NOT(digital_OutputWordMask_d(11 downto 6)) AND doutb_dig(11 downto 6))
									    OR (digital_OutputWordMask_d(11 downto 6) AND digital_OutputWord_d(11 downto 6));
			when '1' =>
				dataD(11 downto 6) <= "ZZZZZZ";
			when others =>
				null;
		end case;
		
		case digital_direction(0) is
			when '0' =>
				dataD(5 downto 0) <= (NOT(digital_OutputWordMask_d(5 downto 0)) AND doutb_dig(5 downto 0))
									   OR (digital_OutputWordMask_d(5 downto 0) AND digital_OutputWord_d(5 downto 0));
			when '1' =>
				dataD(5 downto 0) <= "ZZZZZZ";
			when others =>
				null;
		end case;

		LED_i(2) <= sig_out_enable_d AND (generator1On OR generator2On); --'1' when at least one AWG is ON
		dac_en <= sig_out_enable_d AND (generator1On OR generator2On); -- enable/disable generator DAC
		------------------------------------------
		--DIGITAL PATTTERN GENERATOR CLK DIVIDER--
		------------------------------------------
		if digitalClkDivide_cnt >= digitalClkDivide then
			digitalClkDivide_cnt <= to_unsigned(0,32);
		else
			digitalClkDivide_cnt <= digitalClkDivide_cnt + 1;			
		end if;
		if digitalClkDivide_cnt = to_unsigned(0,32) then
            if ( addrb_dig = std_logic_vector(to_unsigned(AWG_MAX_SAMPLES-1,15)) ) then
                addrb_dig <= "000000000000000";
            else
                addrb_dig <= std_logic_vector(unsigned(addrb_dig) + 1);
            end if;
        end if;

		--AWG1/AWG2 master ON/OFF signal
		sig_out_enable_d <= sig_out_enable;
		--external analog trigger
		an_trig_dd <= an_trig_d;
		an_trig_ddd <= an_trig_dd;
		
		-- ext. analog trigger_level 
		-- offset signal range for pwm input (0.9V common mode voltage)
		-- 3,3 Volt / 2048 bit = 3.223e-3 Volt/bit
		-- 0.9 VOlt / 3.223e-3 Volt/bit = 279 bit
		if signed(trig_level) < to_signed(-279,10) then
			AnalogTrigTresh <= std_logic_vector(to_signed(0,10));
		else
			AnalogTrigTresh <= std_logic_vector(signed(trig_level)+to_signed(279,10));
		end if;			
		
		if cfg_addrB = std_logic_vector(to_unsigned(CONFIG_DATA_SIZE-1,6)) then
			cfg_addrB <= std_logic_vector(to_unsigned(1,6));
		else
			cfg_addrB <= std_logic_vector(unsigned(cfg_addrB) + 1);
		end if;

		cfg_addrB_d <= cfg_addrB;
		--reading config data 
		case to_integer(unsigned(cfg_addrB_d) + 1) is

			when 4 =>
				ets_on <= cfg_do_B(23);
				adc_interleaving <= cfg_do_B(22);
				trigger_mode <= cfg_do_B(1 downto 0);
			when 5 =>
				trigger_source <= cfg_do_B(18 downto 16);
				trigger_slope <= cfg_do_B(1 downto 0);
			when 6 =>
				trig_level <= signed(cfg_do_B(25 downto 16));
				trig_hysteresis <= signed(cfg_do_B(9 downto 0));
			when 7 =>
--				pre_trigger(17 downto 2) <= unsigned(cfg_do_B(31 downto 16));
				timebase <= cfg_do_B(4 downto 0);
			when 8 =>
				holdOff <= unsigned(cfg_do_B);
			when 9 =>
                framesize <= std_logic_vector(unsigned(cfg_do_B(26 downto 0))-1);
			when 10 =>
				generator1On <= cfg_do_B(24);
			when 13 =>
				generator2On <= cfg_do_B(24);
			when 16 =>
				digital_trig_patternA(0) <= cfg_do_B(27 downto 16);
				digital_trig_patternB(0) <= cfg_do_B(11 downto 0);
			when 17 =>
				digital_trig_mask(0) <= cfg_do_B(27 downto 16);
				digital_trig_patternA(1) <= cfg_do_B(11 downto 0);
			when 18 =>
				digital_trig_patternB(1) <= cfg_do_B(27 downto 16);
				digital_trig_mask(1) <= cfg_do_B(11 downto 0);	
			when 19 =>
				digital_trig_patternA(2) <= cfg_do_B(27 downto 16);
				digital_trig_patternB(2) <= cfg_do_B(11 downto 0);
			when 20 =>
				digital_trig_mask(2) <= cfg_do_B(27 downto 16);
				digital_trig_patternA(3) <= cfg_do_B(11 downto 0);						
			when 21 =>
				digital_trig_patternB(3) <= cfg_do_B(27 downto 16);
				digital_trig_mask(3) <= cfg_do_B(11 downto 0);
    		when 22 =>
				dt_delayMaxcnt(0) <= unsigned(cfg_do_B(31 downto 16));
				dt_delayMaxcnt(1) <= unsigned(cfg_do_B(15 downto 0));	
			when 23 =>
				dt_delayMaxcnt(2) <= unsigned(cfg_do_B(31 downto 16));	
				dt_delayMaxcnt(3) <= unsigned(cfg_do_B(15 downto 0));	
			when 24 =>
				dt_stage_capture <= to_integer(unsigned(cfg_do_B(25 downto 24)));	
                dtSerial <= cfg_do_B(20);
                dtSerialCh <= to_integer(unsigned(cfg_do_B(19 downto 16)));
--				digital_WiperCode <= cfg_do_B (7 downto 0); --digitalVoltage 
			when 25 =>
				digital_Direction <= cfg_do_B (17 downto 16);   --digitalInputOutput
				digital_OutputWord <= cfg_do_B (15 downto 0);
			when 26 =>
				digital_OutputWordMask <= cfg_do_B(31 downto 16);
				digitalClkDivide_H <= cfg_do_B(15 downto 0);
			when 27 =>
			    digitalClkDivide_L <= cfg_do_B(31 downto 16);
			    digitalClkDivide_tmp <= digitalClkDivide_H & digitalClkDivide_L;
			    mavg_enA <= cfg_do_B(9);
			    mavg_enB <= cfg_do_B(8);
			when 28 =>
			    pre_trigger(26 downto 2) <= unsigned(cfg_do_B(26 downto 2));
			when 29 =>
			    phase_val <= cfg_do_B(30 downto 16);
			    digitalClkDivide <= unsigned(digitalClkDivide_tmp);
			when others => null;
		end case;

		--TEST DIGITAL--
		--dataDd <= "00" & addra;
		
		----------------
		--genSignal_d <= signed(dac_data)-to_signed(2048,12);   --signed(dac_data_rising);
		clearflags_d <= clearflags;
		holdOff_d <= holdOff;
		
		-- detect requestFrame rising edge (new frame request)
		-- new frame can start saving
		requestFrame_d <= requestFrame;
		requestFrame_dd <= requestFrame_d;
		if requestFrame_dd = '0' AND requestFrame_d = '1' then  
			getNewFrame <= '1';		--> START SAVING new frame (ADC process is monitoring this flag)
		end if;
		
		trigger_mode_d <= trigger_mode;
        trigger_source_d <= trigger_source;
        trigger_slope_d <= trigger_slope;
        trig_level_d <= trig_level;
        trig_hysteresis_d <= trig_hysteresis;
		
		trig_level_r_dd <= trig_level_d + trig_hysteresis_d;
		trig_level_f_dd <= trig_level_d - trig_hysteresis_d;
		
	    DataWriteEn_d <= DataWriteEn;
        PreTrigWriteEn_d <= PreTrigWriteEn;
        
		--=======================================================--
		--         Save ADC samples to buffer                    --
		--=======================================================--
	    		
		if ( sampling_CE = '0' ) then -- clock enable for sample save state machine
            
            DataWriteEn <= '0';
            PreTrigWriteEn <= '0';
            
        else

			-- select signal for trigger source
			trig_signal_d <= trig_signal; -- monitor current and next value for trigger
			
			-- Channel 0
			if ( trigger_source_d = "000" ) then					
				trig_signal <= dataAd;		-- if rising
			-- Channel 1
			elsif ( trigger_source_d = "001" ) then
				trig_signal <= dataBd;
			-- AWG
			elsif ( trigger_source_d = "010" ) then
				trig_signal <= genSignal_1_dd;
			elsif ( trigger_source_d = "011" ) then
				trig_signal <= genSignal_2_dd;
			end if;
			
			case GetSampleState(2 downto 0) is
		
			    when ADC_A =>		-- "IDLE STATE"
			
			    --===================================--
			    -- Set timebase and auto trigger    --
			    --===================================--

			    timebase_d <= timebase; -- select sampling frequency for next frame

			    case to_integer(unsigned(timebase_d (4 downto 0))) is
				
					when 0 | 1 =>		-- 4 ns between samples
						auto_trigger_maxcnt <= 400000; -- 1.6 ms auto trigger timeout
					when 2 =>		-- 8 ns
						auto_trigger_maxcnt <= 200000; -- 1.6 ms
					when 3 =>		-- 20 ns
						auto_trigger_maxcnt <= 100000; -- 2 ms
					when 4 =>		-- 40 ns
						auto_trigger_maxcnt <= 100000; -- 4 ms
					when 5 =>		-- 80 ns
						auto_trigger_maxcnt <= 100000; -- 8 ms					
					when 6 =>		-- 200 ns
						auto_trigger_maxcnt <= 50000; -- 10 ms					
					when 7 =>		-- 400 ns
						auto_trigger_maxcnt <= 25000; -- 10 ms				
					when 8 =>		-- 800 ns
						auto_trigger_maxcnt <= 25000;  -- 20 ms				
					when 9 =>		-- 2 us
						auto_trigger_maxcnt <= 10000;  -- 20 ms				
					when 10 =>		-- 4 us
						auto_trigger_maxcnt <= 5000;  -- 20 ms					
					when 11 =>		-- 8 us
						auto_trigger_maxcnt <= 5000;  -- 40 ms					
					when 12 =>		-- 20 us
						auto_trigger_maxcnt <= 5000;  -- 100 ms					
					when 13 =>		-- 40 us
						auto_trigger_maxcnt <= 5000;  -- 200 ms					
					when 14 =>		-- 80 us
						auto_trigger_maxcnt <= 5000;   -- 400 ms				
					when 15 =>		-- 200 us
						auto_trigger_maxcnt <= 2000;   -- 400 ms					
					when 16 =>		-- 400 us
						auto_trigger_maxcnt <= 1000;   -- 400 ms					
					when 17 =>		-- 800 us
						auto_trigger_maxcnt <= 500;    -- 400 ms
					when 18 =>		-- 2 ms
						auto_trigger_maxcnt <= 200;    -- 400 ms				
					when 19 =>		-- 4 ms
						auto_trigger_maxcnt <= 100;    -- 400 ms					
					when 20 =>		-- 8 ms
						auto_trigger_maxcnt <= 100;    -- 800 ms				
					when 21 =>		-- 20 ms
						auto_trigger_maxcnt <= 50;     -- 1000 ms			
					when others =>
						null;	
				end case;
								

				digital_OutputWord_d <= digital_OutputWord;
				digital_OutputWordMask_d <= digital_OutputWordMask;
				digital_direction_d <= digital_Direction;				
				ets_on_d <= ets_on;
				mavg_enA_d <= mavg_enA;
				mavg_enB_d <= mavg_enB;
				
				saved_sample_cnt <= 0;
				saved_sample_cnt_d <= 0;
				
				--addra <= "00000000000000";
				auto_trigger <= '0';
				auto_trigger_d <= '0';
				auto_trigger_cnt <= 0;
				roll <= '0';
				triggered_led <= '0';
				dt_enable <= '0';
				
				if ( getNewFrame = '1' AND clearflags_d = '0' and ram_rdy = '1' ) then
					PreTrigSaving <= '1';
				    PreTrigWriteEn <= '1';
					framesize_d <= framesize;     -- save current frame size
					pre_trigger_d <= pre_trigger; -- size of pre-trigger
					adc_interleaving_d <= adc_interleaving;
					GetSampleState <= ADC_B;   -- goto "PRE-TRIGGER"				
					
				else
					GetSampleState <= ADC_A;
					PreTrigSaving <= '0';
					PreTrigWriteEn <= '0';
					
				end if;
				DebugADCState <= 0;
				
			when ADC_B =>		-- "START SAVE SAMPLES TO FRAME BUFFER: CAPTURE PRE-TRIGGER"
				
				PreTrigSaving <= '1';
				PreTrigWriteEn <= '1';
				triggered <= '0';
				getNewFrame <= '0';			--> reset getNewFrame flag
							
				--post_trigger <= unsigned(framesize_d) - pre_trigger_d + 1;
				
				if ( clearflags_d = '1' ) then
					GetSampleState <= ADC_A;
					pre_trigger_cnt <= to_unsigned(0,pre_trigger_cnt'length);
				-- if sample buffer is filled with pre-trigger data (note: max. pre-trigger_cnt = framesize)
				elsif ( pre_trigger_cnt = unsigned(pre_trigger_d)) then
					-- update saved_sample_cnt, reset pre_trigger_cnt and continue to next state
					pre_trigger_cnt <= to_unsigned(0,pre_trigger_cnt'length);
					saved_sample_cnt <= to_integer(unsigned(pre_trigger_d));
					-- if immediate trigger (roll mode)
					if trigger_mode_d = "11" and pre_trigger_d = 0 then
						GetSampleState <= ADC_C;
						triggered_led <= '1'; -- signal IS TRIGGERED indicator
					-- if not immediate trigger, goto "WAIT FOR TRIGGER ARMED"
					else
						triggered_led <= '0';
						--saved_sample_cnt <= to_integer(unsigned(pre_trigger_d));
						GetSampleState <= ADC_C;
					end if;
				-- else, keep saving pre-trigger data
				else
					pre_trigger_cnt <= pre_trigger_cnt + 1;
					GetSampleState <= ADC_B;
				end if;
				
    			DebugADCState <= 1;
				
			when ADC_C =>		-- "WAIT FOR TRIGGER ARMED"
				
				PreTrigSaving <= '1';
				PreTrigWriteEn <= '1';
				triggered <= '0';				
				if auto_trigger_cnt = auto_trigger_maxcnt then
				    auto_trigger <= '1';
				else
				    auto_trigger_cnt <= auto_trigger_cnt + 1;
				end if;
				
				if ( clearflags_d = '1' ) then
				    dt_enable <= '0';
					GetSampleState <= ADC_A;
				-- define transition to POST-TRIGGER samples capture:
				
				
				-- immediate trigger
				elsif trigger_mode_d = "11" then
				    GetSampleState <= ADC_E;
				
				-- Analog trigger (ETS = ON and 1 -> 0 transition of analog trigger)
				elsif ets_on_d = '1' AND an_trig_ddd = '0' AND an_trig_dd = '1' then
					lut_reg_out_tmp1 <= lut_reg_out(31 downto 16);					
					lut_reg_out_tmp0 <= lut_reg_out(15 downto 0);
					case lut_reg_out(31 downto 0) is
                        when "01111111111111111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(31,6));
                        when "00111111111111111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(30,6));
                        when "00011111111111111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(29,6));
                        when "00001111111111111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(28,6));
                        when "00000111111111111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(27,6));
                        when "00000011111111111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(26,6));
                        when "00000001111111111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(25,6));
                        when "00000000111111111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(24,6));
                        when "00000000011111111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(23,6));
                        when "00000000001111111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(22,6));
                        when "00000000000111111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(21,6));
                        when "00000000000011111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(20,6));
                        when "00000000000001111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(19,6));
                        when "00000000000000111111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(18,6));
                        when "00000000000000011111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(17,6));
                        when "00000000000000001111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(16,6));
                        when "00000000000000000111111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(15,6));
                        when "00000000000000000011111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(14,6));
                        when "00000000000000000001111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(13,6));
                        when "00000000000000000000111111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(12,6));
                        when "00000000000000000000011111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(11,6));
                        when "00000000000000000000001111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(10,6));
                        when "00000000000000000000000111111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(9,6));
                        when "00000000000000000000000011111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(8,6));
                        when "00000000000000000000000001111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(7,6));
                        when "00000000000000000000000000111111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(6,6));
                        when "00000000000000000000000000011111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(5,6));
                        when "00000000000000000000000000001111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(4,6));
                        when "00000000000000000000000000000111" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(3,6));
                        when "00000000000000000000000000000011" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(2,6));
                        when "00000000000000000000000000000001" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(1,6));
                        when "00000000000000000000000000000000" =>
                            an_trig_delay <= std_logic_vector(to_unsigned(0,6));
                        when others => Null;
					end case;
					triggered_led <= '1'; -- signal IS TRIGGERED indicator
					GetSampleState <= ADC_E;
						
				-- Mode: Normal OR Auto OR Single (Not Immediate) AND Source: not Digital
				-- Slope "rising" 
				elsif ets_on_d = '0' AND trigger_source_d /= "100" AND trigger_mode_d /= "11"
                    AND (trigger_slope_d = "00" AND trig_signal < trig_level_d AND trig_signal_d >= trig_level_d) then
                        triggered_led <= '0'; -- signal IS NOT TRIGGERED indicator
                        GetSampleState <= ADC_D;
				-- Slope "falling" 
                elsif ets_on_d = '0' AND trigger_source_d /= "100" AND trigger_mode_d /= "11"
					AND (trigger_slope_d = "01" AND trig_signal >= trig_level_d AND trig_signal_d < trig_level_d) then
                        triggered_led <= '0'; -- signal IS NOT TRIGGERED indicator
                        GetSampleState <= ADC_D;
				-- Slope "both"	   
                elsif ets_on_d = '0' AND trigger_source_d /= "100" AND trigger_mode_d /= "11"
					AND (trigger_slope_d = "10" AND ((trig_signal <  trig_level_d AND trig_signal_d >= trig_level_d)
					                            OR   (trig_signal >= trig_level_d AND trig_signal_d < trig_level_d ))) then
                        triggered_led <= '0'; -- signal IS NOT TRIGGERED indicator
                        GetSampleState <= ADC_D;
				
				-- IF AUTO:
				elsif	ets_on_d = '0' AND ( trigger_mode_d = "00" AND (auto_trigger = '1') ) then
					triggered_led <= '0'; -- signal IS NOT TRIGGERED indicator
					GetSampleState <= ADC_E;
				
			   -- External Digital Inputs trigger
				elsif (ets_on_d = '0' AND trigger_source_d = "100") then
                    --arm digital trigger
                    GetSampleState <= ADC_D;
                    dt_enable <= '1';
                    
				else
				
					GetSampleState <= ADC_C;
					
				end if;
				DebugADCState <= 2;

						
			when ADC_D =>		-- "CONTINUE SAVE SAMPLES TO FRAME BUFFER: WAIT FOR TRIGGER FIRE"

				PreTrigSaving <= '1';
				PreTrigWriteEn <= '1';
				triggered <= '0';
				
				if auto_trigger_cnt = auto_trigger_maxcnt then
                    auto_trigger_d <= '1';
                else
                    auto_trigger_cnt <= auto_trigger_cnt + 1;
                end if;

				if ( clearflags_d = '1' ) then
					GetSampleState <= ADC_A;
					
                -- define transition to POST-TRIGGER samples capture
                
				-- immediate trigger
                elsif trigger_mode_d = "11" then
                    GetSampleState <= ADC_E;
				
				-- AUTO		
				elsif	( trigger_mode_d = "00" AND auto_trigger_d = '1') then
					triggered_led <= '0';
					GetSampleState <= ADC_E;

				-- Mode: Normal OR Auto OR Single (Not Immediate) AND Source: not Digital
				-- Slope "rising"  
				elsif  trigger_source_d /= "100" AND trigger_mode_d /= "11" AND trigger_slope_d = "00"
					AND trig_signal_d >= trig_level_r_dd then
                        triggered_led <= '1';
                        GetSampleState <= ADC_E;
                --Slope "falling"
				elsif  trigger_source_d /= "100" AND trigger_mode_d /= "11" AND trigger_slope_d = "01"
					AND trig_signal_d < trig_level_f_dd then
                        triggered_led <= '1';
                        GetSampleState <= ADC_E;
                --Slope "both"
				elsif  trigger_source_d /= "100" AND trigger_mode_d /= "11" AND trigger_slope_d = "10"
--                    AND ( trig_signal_d >= (trig_level_d + trig_hysteresis_d)
--                      OR  trig_signal_d <  (trig_level_d - trig_hysteresis_d) ) then
					AND ( abs(trig_signal_d) >= trig_level_r_dd ) then
                        triggered_led <= '1';
                        GetSampleState <= ADC_E;

			   -- External Digital Inputs trigger
				elsif (ets_on_d = '0' AND trigger_source_d = "100") then
                    if dt_triggered = '1' then
                        GetSampleState <= ADC_E;
                    else
                        GetSampleState <= ADC_D;
                    end if;
                    
    			else

					GetSampleState <= ADC_D;
					
				end if;
				DebugADCState <= 3;
				
			when ADC_E =>		-- "CONTINUE AND END SAVE SAMPLES TO FRAME BUFFER: POST-TRIGGER"
			
				-- make sure that triggered rising edge and frame_start_pointer are properly captured at sending side
--				if cnt_rst_triggered = 0 then
--					cnt_rst_triggered <= cnt_rst_triggered + 1;
--					t_start <= '1'; --start holdoff timer
--					triggered <= '1';
					-- calculate frame start address ( TODO: pre-trigger ) 
--					if ( pre_trigger_d = 0 ) then
--						frame_start_pointer <= std_logic_vector(unsigned(addra)); 
--					elsif ( pre_trigger_d > 0 ) AND ( pre_trigger_d > unsigned(addra)) then
--						frame_start_pointer <= std_logic_vector(post_trigger + unsigned(addra));
--					elsif ( pre_trigger_d > 0 ) AND ( pre_trigger_d <= unsigned(addra) ) then
--						frame_start_pointer <= std_logic_vector(unsigned(addra) - pre_trigger_d);
--					end if;
--				elsif cnt_rst_triggered = 3 then
--					triggered <= '0';
--				else
--					triggered <= '1';
--					cnt_rst_triggered <= cnt_rst_triggered + 1;
--				end if;

                PreTrigSaving <= '0';
			    PreTrigWriteEn <= '0';
			    dt_enable <= '0';
			    
				if ( clearflags_d = '1' ) then
					t_start <= '0'; --reset holdoff timer start bit
					DataWriteEn <= '0';    --enable signal for DDR write
					triggered <= '0';
					cnt_rst_triggered <= 0;
					GetSampleState <= ADC_A;
				-- if frame is full
				elsif ( saved_sample_cnt_d = unsigned(framesize_d) ) then	
					-- start holdoff timer & reset trigger indicator
					t_start <= '1';
					triggered <= '0';
					cnt_rst_triggered <= 0;
					DataWriteEn <= '0';
					roll <= '0';
					GetSampleState <= ADC_F;
				else
				    t_start <= '0';
                    -- DDR test data
				    DataWriteEn <= '1';
				    triggered <= '1';
					GetSampleState <= ADC_E;
				end if;
				saved_sample_cnt <= saved_sample_cnt + 1;
				saved_sample_cnt_d <= saved_sample_cnt;
				DebugADCState <= 4;
				
			when ADC_F =>
				
                PreTrigSaving <= '0';
				PreTrigWriteEn <= '0';
				t_start <= '0'; --reset holdoff timer start bit	
				if ( clearflags_d = '1' OR o_end = '1') then
					GetSampleState <= ADC_A;
				else
					--wait for holdoff timer
					GetSampleState <= ADC_F;
				end if;
				DebugADCState <= 5;
					
			when others =>
				GetSampleState <= ADC_A;
				DebugADCState <= 6;

			end case;
		      
		end if; --//sampling_ce
		
	end if; --//rising_edge
	
end process;



FX3_interface: process(ifclk)

begin
	
	if (rising_edge(ifclk)) then
		     
        device_temp_d <= device_temp;
        device_temp_dd <= device_temp_d;
        
        getnewframe_d <= getnewframe;
        getnewframe_dd <= getnewframe_d;
        if getnewframe_dd = '0' and getnewframe_d = '1' then
            newFrameRequestRevcd <= '1';
        end if;
        
        init_calib_complete_d <= init_calib_complete;
        if init_calib_complete_d = '0' and init_calib_complete = '1' then
            calib_done <= '1';
        elsif init_calib_complete_d = '1' and init_calib_complete = '0' then
            calib_done <= '0';
        end if; 
        
        -- procedure to reset PLL in case it looses lock
        if calib_done = '1' then
            if pll_locked = '0' then
                if assert_pll_counter = 0 then
                    pll_reset <= '1';
                else
                    pll_reset <= '0';
                end if;
                assert_pll_counter <= assert_pll_counter + 1;
            else
                pll_reset <= '0';
                assert_pll_counter <= 0;
            end if;
        else
            pll_reset <= '0';
            assert_pll_counter <= 0;
        end if;
        
        flaga_d <= flaga;
        flagb_d <= flagb;
        flagb_dd <= flagb_d;
        flagb_ddd <= flagb_dd;
        flagd_d <= flagd;
        flagd_dd <= flagd_d;
        -- monitor flagd: if flagd is rising then we can begin write data to FX3
        if (flagd_dd = '0' and flagd_d = '1') then
            slwr_assert <= '1';
        end if;
        
        -- here we create EP6 ready flag using flagd
        -- flagd         (EP6 partially full flag, watermark level: 9)
        -- flagd_d       (EP6 partially full flag, delayed)
        -- flag_ep6_full (EP6 full flag, asserted low)
--        if flagd_d = '1' then
--            if cnt_after_flagd = 7 then
--                flag_ep6_ready <= '1'; -- EP6 fifo IS empty
--            else
--                cnt_after_flagd <= cnt_after_flagd + 1;
--                flag_ep6_ready <= '0'; -- EP6 fifo _could be_ empty_
--            end if;
--        else
--            flag_ep6_ready <= '1';     -- EP6 fifo is _not empty_
--            cnt_after_flagd <= 0;
--        end if;
        
		DebugADCState_d <= DebugADCState;		
		
		lut_reg_out_tmp1_d <= lut_reg_out_tmp1;
		lut_reg_out_tmp0_d <= lut_reg_out_tmp0;
		
		timebase_dd <= timebase_d;
		timebase_ddd <= timebase_dd;
		
		an_trig_delay_d <= an_trig_delay;
		an_trig_delay_dd <= unsigned(an_trig_delay_d);
		
		if an_trig_delay_dd >= an_trig_delay_max then
            an_trig_delay_max <= an_trig_delay_dd;
        elsif an_trig_delay_dd /= 0 and (an_trig_delay_dd <= an_trig_delay_min) then
            an_trig_delay_min <= an_trig_delay_dd;
        end if;
		
--      digital_Direction_d <= digital_Direction;
--		digital_Direction_dd <= digital_Direction_d;
		
		--========================================--
		-- Generate frame save/send flags         --
		--========================================--
		
		-- monitor triggered rising flag (so we can start sending samples to PC)
		-- give some delay (_dddd), so that frame_start_pointer_dd is properly read
		triggered_d <= triggered;
		triggered_dd <= triggered_d;
		triggered_ddd <= triggered_dd;
		triggered_dddd <= triggered_ddd;
		-- if frame saving has started, assert frame_ready_to_send flag
		if ( triggered_dddd = '0' AND triggered_ddd = '1' ) then
		   frame_ready_to_send <= '1';
		end if;
		
		-- READ ASYNC SIGNALS
		frame_start_pointer_d <= frame_start_pointer;
		frame_start_pointer_dd <= frame_start_pointer_d;
		--new_frame_ready_flag_d <= new_frame_ready_flag;
--		saving_progress_d <= saving_progress;
--		saving_progress_dd <= saving_progress_d;
--		--compare two sequential samples to prevent incorect progress sampling
--		--due to clock domains crossing signals
--		if saving_progress_d = saving_progress_dd then
--			saving_progress_ddd <= saving_progress_dd;
--		end if;
			
		triggered_led_d <= triggered_led; -- indicator that signal is triggered
		roll_d <= roll;
		
		--===========================================================
		-- Transfer samples from buffer to FX3
		--===========================================================
		
		case MasterState(3 downto 0) is
     
		when A =>           			-- "IDLE STATE"                
			faddr_i <= "00";        
			slrd_i  <= '1';
			slwr_i  <= '1';
            -- wait for IDELAYCTRL ready
            -- IDELAYCTRL start-up Time = 3.67us
            -- from Artix_7_Data_Sheet, Table  25: Input/Output Delay Switching Characteristics
			-- check flaga for rising edge
            if ( flaga_d = '1' ) then
                if Timer_cnt = 50000 then
                    ConfigureVdac <= '0';   -- de-assert ADC & DAC SPI write
                    ConfigureADC <= '0';
                    sig_out_enable <= '1';  -- enable signal for Signal Generator
                    MasterState <= B;	    -- goto Dispatcher
                    Timer_cnt <= 0;
                elsif Timer_cnt = 40000 then
                    dac_cfg_reg <= "0110" & "000000000000"; -- enable +/-Va supply (UPO bit on MAX5501 DAC goes HIGH)
                    --dac_cfg_reg <= "0010" & "000000000000"; -- DISABLE +/-Va supply (for debug only)
                    ConfigureVdac <= '1';
                    adc_spi_data <= X"00C0" & X"00"; -- configure ADC to DISABLE TEST pattern
                    ConfigureADC <= '1';
                    MasterState <= A;
                    Timer_cnt <= Timer_cnt + 1;
                elsif Timer_cnt = 30000 or Timer_cnt = 30001 then
                    read_calib_start <= '1';    -- start IDELAY calibration for ADC interface
                    read_calib_source <= '1';   -- select to calibrate CH1
                    MasterState <= A;
                    Timer_cnt <= Timer_cnt + 1;
                elsif Timer_cnt = 20000 or Timer_cnt = 20001 then
                    read_calib_start <= '1';    -- start IDELAY calibration for ADC interface
                    read_calib_source <= '0';   -- select to calibrate CH1
                    MasterState <= A;
                    Timer_cnt <= Timer_cnt + 1;
                elsif Timer_cnt = 2000 then
                    adc_spi_data <= X"00C0" & X"44"; -- configure ADC to send TEST pattern (CHECKERBOARD)
                    ConfigureADC <= '1';
                    -- set POT:1 to tap value 152 (29763 Ohms)- the tap value should match digital[voltageCoeficient] 
                    dpot_spi_WiperCode <= "00010000" & X"98";
                    dpot_spi_write_trig <= '1';
                    ConfigureVdac <= '0';
                    MasterState <= A;
                    Timer_cnt <= Timer_cnt + 1;
                else
                    read_calib_start <= '0';
                    ConfigureADC <= '0';        -- de-assert ADC write trigger
                    ConfigureVdac <= '0';       -- de-assert control DAC write trigger
                    dpot_spi_write_trig <= '0'; -- de-assert digital POT write trigger
                    sig_out_enable <= '0';
                    MasterState <= A;
                    Timer_cnt <= Timer_cnt + 1;
                end if;
            -- check flagb for rising edge
            elsif ( flagb_d = '1' ) then
                ConfigureADC <= '0';
                ConfigureVdac <= '0';
                read_calib_start <= '0';
                sig_out_enable <= '0';
                MasterState <= B;
            else
                Timer_cnt <= 0;
                read_calib_start <= '0';
                ConfigureVdac <= '0';
                ConfigureADC <= '0';
                sig_out_enable <= '0';
                MasterState <= A;
            end if;
			fdata <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"; -- place data bus in HI-Z state
			clearflags <= '1'; -- send reset to ADC sample saving process
			DebugMState <= 0;
			
		when B =>						-- "READ from FIFO state" / dispatcher
			slwr_i <= '1';
			slrd_i <= '1';
			dpot_spi_write_trig <= '0';
			-- if new scope configuration data is waiting in EP2 or EP4 buffer
			if ( flaga_d = '1' or flagb_d = '1') then -- EP2 or EP4 not empty
				fdata <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"; -- place data bus in HI-Z state
				if flaga_d = '1' then -- if new scope config is waiting
					faddr_i <= "11"; -- select EP2 fifo buffer
					-- initialize Config RAM address pointer
					cfg_addrA <= std_logic_vector(to_unsigned(0,6));
					MasterState <= C;  -- goto "GET SCOPE CONFIG"
				else -- else: awg custom wave data is sent from host	
					faddr_i <= "10";	-- select EP4
					MasterState <= H; -- read AWG custom data
				end if;
			-- if new config was received during sending, then return back
			elsif ReturnToStreamingState = '1' then
				ReturnToStreamingState <= '0'; -- re-set return state flag
				Masterstate <= G; -- return to frame streaming
			-- if new config was received during frame request, then return back
            elsif ReturnToFrameRequest = '1' then
                ReturnToFrameRequest <= '0'; -- re-set return state flag
                Masterstate <= F; -- return to frame streaming
			--if scope settings have changed
			elsif DAC_pogramming_start = '1' then
				-- update DAC config registers
				dac_cfg_array(1) <= "1111" & VgainB;
				dac_cfg_array(2) <= "1011" & VgainA;
				-- Convert from Two's Complement to Offset Binary
				dac_cfg_array(3) <= "0011" & std_logic_vector(NOT(OffsetA(11))& OffsetA(10 downto 0));
				dac_cfg_array3_d <= "0011" & std_logic_vector(NOT(OffsetA(11))& OffsetA(10 downto 0));
				dac_cfg_array3_2d <= dac_cfg_array3_d;
				dac_cfg_array3_3d <= dac_cfg_array3_2d;
				dac_cfg_array3_4d <= dac_cfg_array3_3d;
				dac_cfg_array(4) <= "0111" & std_logic_vector(NOT(OffsetB(11))& OffsetB(10 downto 0));
				Masterstate <= E;
			--if ADC config has changed
			elsif (adc_cfg_data_d /= adc_cfg_data) then
				adc_spi_data <= adc_cfg_reg & adc_cfg_data;
				adc_cfg_reg_d <= adc_cfg_reg;
				adc_cfg_data_d <= adc_cfg_data;
--				ConfigureADC <= '1';     debug!
				Masterstate <= D;
			else
				-- if scope config has changed OR single trigger was re-armed
				if scopeConfigChanged = '1' then
					-- reset scopeConfigChanged flag
					scopeConfigChanged <= '0';
					-- stop&reset frame saving process
					--clearflags <= '1'; --debug! --  due to problems with reset 
					--frame_ready_to_send <= '0'; --??? (100% pre-trigger)
				end if;
--				requestFrame <= '1';
			   Masterstate <= F; -- else, go to "GET NEW ADC FRAME FROM SAMPLE BUFFER"
			end if;
			DebugMState <= 1;
		  
		when C =>						-- "GET SCOPE CONFIG"
			faddr_i <= "11"; -- selected FIFO endpoint is EP2 (config)
			slwr_i  <= '1';
			-- verify if any changes were made to configuration
            -- when writing to RAM, compare new and old config word
            cfg_data_in_d <= cfg_data_in;
            cfg_we_d <= cfg_we;
			case to_integer(unsigned(cfg_addrA_d)+1) is
				-- don't look for changes in generator config (word 10 to 15)
				when 1 to 9 | 16 to 20 =>
					if cfg_we_d = '1' AND cfg_data_in_d /= cfg_do_A then
						ScopeConfigChanged <= '1';
						DAC_pogramming_start <= '1';
--						LED_i(1) <= '1';
					end if;
				when others => null;
			end case;

			if faddr_rdy = '0' then
			    slrd_i <= '0';
                cfg_data_in <= fdata;
                cfg_addrA_d <= cfg_addrA;
			    -- FX3 has 3 cycle latency from FADDR to data
                -- and 2 cycle latency from SLRD to data
                if faddr_rdy_cnt_i = 3 then
                    faddr_rdy <= '1';
                    faddr_rdy_cnt_i <= 0;
                    cfg_we <= '1';
                else
                    cfg_we <= '0';
                    faddr_rdy <= '0';
                    faddr_rdy_cnt_i <= faddr_rdy_cnt_i + 1;
                end if;
                Masterstate <= C;
			-- if FX3 is ready for reading and EP2 is not empty 
			elsif ( flaga_d = '1' and cfg_we = '1') then
			    -- slrd has 2 cycle latency
		        if cfg_data_cnt < CONFIG_DATA_SIZE - 4 then
                    slrd_i  <= '0';
                else
                    slrd_i  <= '1';
                end if;
			    -- read oscilloscope configuration and save to RAM
                cfg_data_in <= fdata;
                -- increment RAM address pointer
				if cfg_data_cnt = CONFIG_DATA_SIZE - 1 then
				    cfg_we <= '0';
				    cfg_data_cnt <= 0;
				    cfg_addrA <= std_logic_vector(to_unsigned(0,6));
				else
				    cfg_we <= '1';
				    cfg_data_cnt <= cfg_data_cnt + 1;
				    cfg_addrA <= std_logic_vector(unsigned(cfg_addrA) + 1);
				end if;
				cfg_addrA_d <= cfg_addrA;          
				-- stay in this state util EP2 is not empty
				Masterstate <= C;
			else
			    fdata <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"; -- place data bus in HI-Z state       
				slrd_i  <= '1';
				cfg_we <= '0';
				if to_integer(unsigned(cfg_addrA)) = CONFIG_DATA_SIZE - 1 then
					-- return to dispatcher state if memory read is finished
					cfg_addrA_d <= "000000";
					cfg_addrA <= "000000";
					cfg_data_cnt <= 0;
					faddr_rdy_cnt_i <= 0;
					faddr_rdy <= '0';
                    dpot_spi_write_trig <= '1';
					Masterstate <= B;
				else
				    cfg_addrA_d <= cfg_addrA;
					-- increment memory address pointer
					cfg_addrA <= std_logic_vector(unsigned(cfg_addrA) + 1);
					dpot_spi_write_trig <= '0';
					Masterstate <= C;
				end if;
 				
    			--copy scope config to memory
				case to_integer(unsigned(cfg_addrA_d) + 1) is 
					when 1 =>
						adc_cfg_reg <= cfg_do_A(31 downto 16);
						adc_cfg_reg_d <= adc_cfg_reg;
						adc_cfg_data <= cfg_do_A(7 downto 0);
						adc_cfg_data_d <= adc_cfg_data;
					when 2 =>
						VgainA <= cfg_do_A(27 downto 16);
						--VgainA_d <= VgainA; 
						VgainB <= cfg_do_A(11 downto 0);
                        --VgainB_d <= VgainB;
					when 3 =>
						OffsetA <= cfg_do_A(27 downto 16);
                        OffsetA_d <= OffsetA;
                        OffsetA_2d <= OffsetA_d;
                        OffsetA_3d <= OffsetA_2d;
                        OffsetA_4d <= OffsetA_3d;
                        OffsetA_5d <= OffsetA_4d;
                        OffsetA_6d <= OffsetA_5d;
                        OffsetA_7d <= OffsetA_6d;
						OffsetB <= cfg_do_A(11 downto 0);
                        OffsetB_d <= OffsetB;
					when 4 =>
						ch1_dc_i <= cfg_do_A(21);
                        ch2_dc_i <= cfg_do_A(20);
                        ch1_gnd_i <= NOT(cfg_do_A(19));
                        ch2_gnd_i <= NOT(cfg_do_A(18));
                        ch1_k_i <= cfg_do_A(17);
                        ch2_k_i <= cfg_do_A(16);
						s_trigger_mode <= cfg_do_A(1 downto 0);
                        s_trigger_rearm <= cfg_do_A(2);
					when 10 =>
						generator1Type <= cfg_do_A(19 downto 16);
						generator1Voltage <= sfixed(cfg_do_A(11 downto 0));
				    when 11 =>
						generator1Offset <= signed(cfg_do_A(27 downto 16));
						generator1Delta_H <= cfg_do_A(15 downto 0);
					when 12 =>
						generator1Delta_L <= cfg_do_A(31 downto 16);
						generator1Duty <= signed(cfg_do_A(11 downto 0));
				    when 13 =>
				        generator1Delta <= generator1Delta_H & generator1Delta_L;
						generator2Type <= cfg_do_A(19 downto 16);
						generator2Voltage <= sfixed(cfg_do_A(11 downto 0));
					when 14 =>						
						generator2Offset <= signed(cfg_do_A(27 downto 16));
						generator2Delta_H <= cfg_do_A(15 downto 0);
					when 15 =>
					    generator2Delta_L <= cfg_do_A(31 downto 16);
						generator2Duty <= signed(cfg_do_A(11 downto 0));
					when 16 =>
					    generator2Delta <= generator2Delta_H & generator2Delta_L;
					when 24 =>
					   dpot_spi_WiperCode <= "00000000" & cfg_do_A (7 downto 0); -- write data to POT:0
					when others => null;
				end case;
			end if;
			DebugMState <= 2;
      
		when D =>			          -- "CONFIGURE ADC"
			-- reset ADC register write command
			if ConfigureADC = '1' OR adcA_spi_busy = '1' OR adcB_spi_busy = '1' then
                adc_spi_data <= adc_cfg_reg & adc_cfg_data;
                ConfigureADC <= '0';
                Masterstate <= D;
			else
            -- return to dispatcher state
                Masterstate <= B;
			end if;
			DebugMState <= 3;
		
		when E =>						-- "CONFIGURE ANALOG INPUTS (Gain/Offset)

			--===========================================================
			-- Update DAC outputs (analog channel Offser/Gain control)
			--===========================================================	

			if DAC_programming_finished = '1' then
				if cnt_dac_out_stable = 16383 then
					DAC_programming_finished <= '0'; --reset programming flag
					cnt_dac_out_stable <= 0;
					Masterstate <= B;
				else
					DAC_programming_finished <= '1';
					cnt_dac_out_stable <= cnt_dac_out_stable + 1;
					Masterstate <= E;
				end if;										
			else
				Masterstate <= E;
				case DAC_state (2 downto 0) is
					
					when DAC_A => -- "IDLE"
						
						if DAC_pogramming_start = '1' and dac_spi_busy = '0' then
							DAC_pogramming_start <= '0';
							DAC_state <= DAC_B; -- start programming
						else
							DAC_state <= DAC_A; -- WAIT
						end if;
					
					when DAC_B => -- "LOAD DAC REGISTER AND START PROGRAMMING"
					
						dac_cfg_reg <= dac_cfg_array(dac_array_count);						
						if dac_spi_busy = '0' then
						    ConfigureVdac <= '1'; --s DAC programming
						    DAC_state <= DAC_C;   --goto WAIT
						else
						    ConfigureVdac <= '0';
                            DAC_state <= DAC_B;
                        end if;
								
					when DAC_C => -- "WAIT UNTIL PROGRAMMING FINISHED"
						ConfigureVdac <= '0';
						if dac_spi_busy = '1' OR ConfigureVdac = '1' then
							-- wait if SPI interface is busy
							DAC_state <= DAC_C;
						else
							if ( dac_array_count = 4 ) then
								DAC_programming_finished <= '1';
								dac_array_count <= 1;
								DAC_state <= DAC_A;
							else
								DAC_state <= DAC_B;
								-- select next DAC register and goto LOAD
								dac_array_count <= dac_array_count + 1;
							end if;
						end if;

					when others =>
						DAC_state <= DAC_A;
				end case;
			end if;
			
			DebugMState <= 4;
			
		when F =>						-- "WAIT FOR NEW FRAME READY"
			clearflags <= '0';
			ReadingFrame <= '0';
--			requestFrame <= '0';
			-- start sending to FX3 when frame was triggered
			if ( frame_ready_to_send = '1' ) then
		        newFrameRequestRevcd <= '0';
		        framesize_dd <= framesize_d;  -- get current frame size
				frame_ready_to_send <= '0';
--				addrb <= std_logic_vector(unsigned(frame_start_pointer_dd));
				Masterstate <= G;					-- continue to STREAMING
			-- wait until frame is ready to send
			elsif ( flaga_d = '1' or flagb_d = '1') then
				Masterstate <= B;	-- we have to read new config immediately if it was received
			else
                if newFrameRequestRevcd = '0' then
                    if cnt_restart_framesave = 15 then
                        -- if single trigger is requested but armed, then don't request new frame
                        if s_trigger_mode = "10" AND s_trigger_rearm = '0' then
                            cnt_restart_framesave <= 15;
                            requestFrame <= '0';
                        -- request new frame
                        else
                            s_trigger_rearm <= '0';
                            cnt_restart_framesave <= 0;
                            requestFrame <= '1';
                    	end if;
                    else
                    	cnt_restart_framesave <= cnt_restart_framesave + 1;
                    	requestFrame <= '0';
                    end if;
                    Masterstate <= F;
                else
                    -- wait in this state until frame is ready to send
                    requestFrame <= '0';
                    cnt_restart_framesave <= 0;
                    Masterstate <= F;
                end if;
	     	end if;
			DebugMState <= 5;
			
		when G =>            		-- "STREAMING SAMPLE DATA"
			--sloe_i <= '1';
			slrd_i <= '1';
			faddr_i <= "00";  -- 00 -- select EP6
			ReadingFrame <= '1';
--			frame_ready_to_send <= '0'; 	-- reset frame_ready_to_send flag
			-- select flagd/flagb IN EP buffer
			
			-- flaga/flagb interrupt: read scope config if sent from host
			-- ONLY if there are no samples waiting to be read from RAM and if multiple of 4 samples were sent to FX3
			--if (flaga_d = '1' or flagb_d = '1') and slwr_assert = '0' then
			if (flaga_d = '1' OR flagb_d = '1') AND DataOutValid = '0' AND (dword_cnt_i = 0) then
			    -- disable reading samples from RAM
			    DataOutEnable <= '0';
			    slwr_i <= '1';
			    -- wait for 7 clk cycles to confirm there is no data waiting to be read from RAM 
			    if cnt_dw_stop = 7 then
                    cnt_dw_stop <= 0;
                    if unsigned(timebase_ddd) >= 12 then -- check if this is really needed???
                        SendingFrameSlow <= '1';
                    end if;
                    MasterState <= B;
                    ReturnToStreamingState <= '1'; -- set return state flag
                else
			        cnt_dw_stop <= cnt_dw_stop + 1;
			        MasterState <= G;
			    end if;
				
			-- send data to FX3 if EP6 is ready
			elsif slwr_assert = '1' AND (
			    -- if sending header
			    ( hword_cnt_i < FRAME_HEADER_SIZE ) OR
			    -- if data available from RAM
			    ( DataOutValid = '1' ) OR
			    -- if sending padding after frame end
			    ( send_sample_cnt = to_integer(unsigned(framesize_dd)) AND dword_cnt_i < FX3_DMA_BUFFER_SIZE/4 ) OR
				-- or if capturing slow timebase and scope config has changed
				( SendingFrameSlow = '1' and ScopeConfigChanged = '1' ) )
				then
				-- then start writing data to FX3
				slwr_i <= '0';
				cnt_dw_stop <= 0; -- reset flaga/flagb interrupt timer
				-- write samples in bursts of FX3_DMA_BUFFER_SIZE
				if slwr_assert_cnt = (FX3_DMA_BUFFER_SIZE/4)-1 then
				    slwr_assert <= '0';
				    slwr_assert_cnt <= 0;
				else
				    slwr_assert_cnt <= slwr_assert_cnt + 1;
				end if;
				-- Send HEADER first : HEADER size is 256 DWords = 1024 Bytes
				if hword_cnt_i < FRAME_HEADER_SIZE then
					DataOutEnable <= '0';
					--start sending frame HEADER
					hword_cnt_i <= hword_cnt_i + 1;
					case hword_cnt_i is
    			    --read back scope config
                        when 0  =>
                            fdata <= X"DDDDDDDD";
                            send_frame_cnt <= send_frame_cnt + 1;
                        when 1 =>
                            fdata <= X"0000" & X"0" & device_temp_dd;
                            --fdata <= X"00000" & device_temp_dd;
                        when 2 =>
                            fdata <= X"0000" & X"00" & "00" & std_logic_vector(an_trig_delay_dd);
                            --fdata <= X"00000" &  std_logic_vector(to_unsigned(send_frame_cnt,12));
                        when 3 =>
                            fdata <= X"0000" & X"00" & "00" & std_logic_vector(an_trig_delay_min);
                        when 4 =>
                            fdata <= X"0000" & X"00" & "00" & std_logic_vector(an_trig_delay_max);                          
                        when 63 =>
                            cfg_addrA <= std_logic_vector(to_unsigned(1,6));
                            fdata <= X"0000FFFF";
                        when 72 =>
                            fdata(26 downto 0) <= std_logic_vector(unsigned(framesize_dd)+1);
                        when 64 to 71 | 73 to 64+(CONFIG_DATA_SIZE-1) =>
                            if to_integer(unsigned(cfg_addrA)) = CONFIG_DATA_SIZE-1 then
                                cfg_addrA <= std_logic_vector(to_unsigned(0,6));
                            else
                                cfg_addrA <= std_logic_vector(unsigned(cfg_addrA) + 1);
                            end if;
                            fdata <= cfg_do_A;
                        when FRAME_HEADER_SIZE-1 =>
                            fdata  <= x"00000000"; -- CRC
                        when others =>
                            cfg_addrA <= std_logic_vector(to_unsigned(0,6));
                            fdata <= X"0000FFFF";
                    end case;					
--					case hword_cnt_i is
--						when 0 =>
--							fdata(15 downto 0) <= X"DDDD";
--						when 5 =>
--							fdata(15 downto 0) <= X"00" & "00" & an_trig_delay_dd;
----							fdata <= lut_reg_out_tmp2_d;
----						when 2 =>
----							fdata <= X"00" & "00" & an_trig_delay_dd;
----						when 3 =>
----							fdata <= lut_reg_out_tmp0_d; --frame start address
----						when 4 =>
----							fdata <= X"0" & "000" & triggered_led_d & X"0" & "000" & roll_d;
----						when 5 =>
----							fdata <= "00" & frame_start_pointer_d; --X"FFFF";
--                        when 1231 =>
--                            DataOutEnable <= '1';
--						when others =>
--							fdata(15 downto 0) <= X"FFFF";
--				      end case;
				else
				    -- control reading data from RAM with DataOutEnable
                    -- count how many 32-bit data words were sent to FX3 fifo
                    if dword_cnt_i = (FX3_DMA_BUFFER_SIZE/4)-1 then
                        dword_cnt_i <= 0;
                        DataOutEnable <= '0';
                    else
                        dword_cnt_i <= dword_cnt_i + 1;
                        -- data from RAM will still be valid 4 clk cycles after DataOutEnable is deasserted
                        -- so DataOutEnable must be deasserted 4 clk cycles before FX3 fifo is full
                        if dword_cnt_i < (FX3_DMA_BUFFER_SIZE/4)-5 then
                            DataOutEnable <= '1';
                        else
                            DataOutEnable <= '0';
                        end if;
                    end if;
					-- start sending frame DATA
					if ( send_sample_cnt = to_integer(unsigned(framesize_dd)) ) then
                        SendingFrameSlow <= '0';	-- reset flags
                        if dword_cnt_i = (FX3_DMA_BUFFER_SIZE/4)-1 then
                            hword_cnt_i <= 0; -- RESET Header couter
                            send_sample_cnt <= 0;
                            MasterState <= B; -- continue to dispatcher
						else
						    if DataOutValid = '1' then
                                fdata <= DataOut;
                            else
                                -- insert padding bytes to fill FX3 DMA BUFFER
                                -- we have to do this, if we don't want to use PKTEND#
						        fdata <= x"00000000";
						    end if;
						    Masterstate <= G; -- CONTINUE WITH PADDING
						end if;
					else
					    if ( SendingFrameSlow = '1' and ScopeConfigChanged = '1' ) then
                            fdata <= x"00000000";
                            clearflags <= '1';
                        else
                            fdata <= DataOut;
                            --fdata <= DataOut(31 downto 12) & "00" & DataOut(31 downto 22);
                            clearflags <= '0';
                        end if;
						send_sample_cnt <= send_sample_cnt + 1;
                        Masterstate <= G; -- CONTINUE STREAMING SAMPLE DATA
					end if;									
				end if;
			-- FX3 can accept data and samples still need to be sent and header was already sent
		    elsif slwr_assert = '1' and (send_sample_cnt < to_integer(unsigned(framesize_dd))) and hword_cnt_i = FRAME_HEADER_SIZE then
--		        if DataOutEnable_cnt = 15 then
--		            DataOutEnable_cnt <= 0;
		            DataOutEnable <= '1';
--		        else
--		            DataOutEnable_cnt <= DataOutEnable_cnt + 1;
--		            DataOutEnable <= '0';
--		        end if;
		        slwr_i  <= '1';
                Masterstate <= G;
			else	-- else, WAIT UNTIL FIFO IS EMPTY
			    DataOutEnable <= '0';
				slwr_i  <= '1';
				Masterstate <= G;
			end if;
			DebugMState <= 6;
	
		when H =>                 -- "Read data for AWG custom signal"

			faddr_i <= "10";	-- select EP4 (awg custom data)
			slwr_i  <= '1';
			if faddr_rdy = '0' then
                -- FX3 has 3 cycle latency from FADDR to data
                -- and 2 cycle latency from SLRD to data
                slrd_i <= '1';
                slrd_rdy_cnt <= 0;
                if faddr_rdy_cnt_i = 3 then
                    faddr_rdy <= '1';
                    faddr_rdy_cnt_i <= 0;
                else
                    faddr_rdy <= '0';
                    faddr_rdy_cnt_i <= faddr_rdy_cnt_i + 1;
                end if;
            elsif ( flagb_dd = '1' ) then

                if slrd_i = '0' then
                    if slrd_cnt = (FX3_DMA_BUFFER_SIZE/4) then
                        slrd_cnt <= 0;
                    else                      
                        slrd_cnt <= slrd_cnt + 1;
                    end if;
                end if;
                -- Select AWG buffer -> 0: AWG_1, 1: AWG_2, 2: Digital
                case BufferSel is
                    when "00" =>
                    
                        if accumulate_addra_awg = '1' and addra_awg < std_logic_vector(to_unsigned(AWG_MAX_SAMPLES-1,15)) then
                            addra_awg <= std_logic_vector(unsigned(addra_awg) + 1);
                        end if;
                        if slrd_rdy_cnt = 3 then
                            -- fdata bus is 32-bit wide, so we are reading 2 consecutive 12-bit words in one clock cycle
                            -- and asserting slrd_i every other clock cycle
                            dina_awg_tmp <= fdata(11 downto 0);
                            if slrd_i = '0' then             
                                slrd_i <= '1'; 
                                dina_awg <= fdata(27 downto 16);
                                wea_awg <= '1';
                                accumulate_addra_awg <= '1'; -- start address counters                      
                            else
                                if slrd_cnt < (FX3_DMA_BUFFER_SIZE/4) then
                                    dina_awg <= dina_awg_tmp;
                                    wea_awg <= '1';
                                    accumulate_addra_awg <= '1'; -- start address counters
                                    slrd_i <= '0';
                                else
                                    cnt_rd_last <= not(cnt_rd_last);
                                    if cnt_rd_last = '0' then
                                        dina_awg <= dina_awg_tmp;
                                    else
                                        dina_awg <= fdata(27 downto 16);
                                    end if;
                                    wea_awg <= flagb_d;
                                    accumulate_addra_awg <= flagb_d; -- start address counters
                                    slrd_i <= '1';
                                end if;
                            end if;
                        else
                            if slrd_i = '1' then
                                slrd_i <= '0';
                            else
                                slrd_i <= '1';
                            end if;
                            slrd_rdy_cnt <= slrd_rdy_cnt + 1;
                            accumulate_addra_awg <= '0';
                        end if;
                        -- stay in this state, util EP4 is not empty
                        Masterstate <= H;
                        
                    when "01" =>
                    
                        if accumulate_addra_awg = '1' and addra_awg2 < std_logic_vector(to_unsigned(AWG_MAX_SAMPLES-1,15)) then
                        addra_awg2 <= std_logic_vector(unsigned(addra_awg2) + 1);
                        end if;
                        if slrd_rdy_cnt = 3 then
                            -- fdata bus is 32-bit wide, so we are reading 2 consecutive 12-bit words in one clock cycle
                            -- and asserting slrd_i every other clock cycle
                            dina_awg2_tmp <= fdata(11 downto 0);
                            if slrd_i = '0' then             
                                slrd_i <= '1'; 
                                dina_awg2 <= fdata(27 downto 16);
                                wea_awg2 <= '1';
                                accumulate_addra_awg <= '1'; -- start address counters                      
                            else
                                if slrd_cnt < (FX3_DMA_BUFFER_SIZE/4) then
                                    dina_awg2 <= dina_awg2_tmp;
                                    wea_awg2 <= '1';
                                    accumulate_addra_awg <= '1'; -- start address counters
                                    slrd_i <= '0';
                                else
                                    cnt_rd_last <= not(cnt_rd_last);
                                    if cnt_rd_last = '0' then
                                        dina_awg2 <= dina_awg2_tmp;
                                    else
                                        dina_awg2 <= fdata(27 downto 16);
                                    end if;
                                    wea_awg2 <= flagb_d;
                                    accumulate_addra_awg <= flagb_d; -- start address counters
                                    slrd_i <= '1';
                                end if;
                            end if;
                        else
                            if slrd_i = '1' then
                                slrd_i <= '0';
                            else
                                slrd_i <= '1';
                            end if;
                            slrd_rdy_cnt <= slrd_rdy_cnt + 1;
                            accumulate_addra_awg <= '0';
                        end if;
                        -- stay in this state, util EP4 is not empty
                        Masterstate <= H;
                    
                    when "10" =>
                    
                        if accumulate_addra_awg = '1' and addra_dig < std_logic_vector(to_unsigned(AWG_MAX_SAMPLES-1,15)) then
                            addra_dig <= std_logic_vector(unsigned(addra_dig) + 1);
                        end if;
                        if slrd_rdy_cnt = 3 then
                            -- fdata bus is 32-bit wide, so we are reading 2 consecutive 12-bit words in one clock cycle
                            -- and asserting slrd_i every other clock cycle
                            dina_dig_tmp <= fdata(11 downto 0);
                            if slrd_i = '0' then             
                                slrd_i <= '1'; 
                                dina_dig <= fdata(27 downto 16);
                                wea_dig <= '1';
                                accumulate_addra_awg <= '1'; -- start address counters                      
                            else
                                if slrd_cnt < (FX3_DMA_BUFFER_SIZE/4) then
                                    dina_dig <= dina_dig_tmp;
                                    wea_dig <= '1';
                                    accumulate_addra_awg <= '1'; -- start address counters
                                    slrd_i <= '0';
                                else
                                    cnt_rd_last <= not(cnt_rd_last);
                                    if cnt_rd_last = '0' then
                                        dina_dig <= dina_dig_tmp;
                                    else
                                        dina_dig <= fdata(27 downto 16);
                                    end if;
                                    wea_dig <= flagb_d;
                                    accumulate_addra_awg <= flagb_d; -- start address counters
                                    slrd_i <= '1';
                                end if;
                            end if;
                        else
                            if slrd_i = '1' then
                                slrd_i <= '0';
                            else
                                slrd_i <= '1';
                            end if;
                            slrd_rdy_cnt <= slrd_rdy_cnt + 1;
                            accumulate_addra_awg <= '0';
                        end if;
                        -- stay in this state, util EP4 is not empty
                        Masterstate <= H;
                
                    when others => null;
                end case;
            else
                slrd_cnt <= 0;
                slrd_rdy_cnt <= 0;
                cnt_rd_last <= '0';
                slrd_i <= '1';
                wea_dig <= '0';
                wea_awg <= '0';
                wea_awg2 <= '0';
                accumulate_addra_awg <= '0'; -- re-set counter flag
                -- if awg buffer is full
                if addra_awg = std_logic_vector(to_unsigned(AWG_MAX_SAMPLES-1,15)) then
                    addra_awg <= std_logic_vector(to_unsigned(0,15));
                    BufferSel <= "01"; -- switch to AWG_2 buffer
                    Masterstate <= B;
                elsif addra_awg2 = std_logic_vector(to_unsigned(AWG_MAX_SAMPLES-1,15)) then
                    addra_awg2 <= std_logic_vector(to_unsigned(0,15));
                    BufferSel <= "10"; -- switch to dig. pattern buffer
                    Masterstate <= B;
                elsif addra_dig = std_logic_vector(to_unsigned(AWG_MAX_SAMPLES-1,15)) then
                    addra_dig <= std_logic_vector(to_unsigned(0,15));
                    BufferSel <= "00"; -- reset buffer select
                    faddr_rdy <= '0';
                    Masterstate <= B; -- back to dispatcher
                else
                   -- halt on error
                    MasterState <= B; -- halt in curent state
                end if;
            end if;
			DebugMState <= 7;
		
		when others =>					-- if in undefined state, move to IDLE
			faddr_i <= "00";
			slwr_i  <= '1'; 
			MasterState <= A;
			
		end case;
	end if;

end process;

end rtl;