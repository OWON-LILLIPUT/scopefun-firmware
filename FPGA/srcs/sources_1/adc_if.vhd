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
library UNISIM;
use UNISIM.VComponents.all;

entity adc_if is
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
        o_data_2 : out STD_LOGIC_VECTOR (9 downto 0)
        );
end adc_if;

architecture Behavioral of adc_if is

CONSTANT TEST_MODE : boolean := False;

CONSTANT ADC_CLK_DELAY  : integer := 0;  -- delay tap setting (0-31)
CONSTANT ADC_DATA1_DELAY : integer := 23; -- Average Tap Delay at 200 MHz = 78 ps (78 * 31 = 2.5 ns max-delay)
CONSTANT ADC_DATA2_DELAY : integer := 2;

CONSTANT dly_calib_idle: std_logic_vector(1 downto 0) := "00";
CONSTANT dly_calib_run: std_logic_vector(1 downto 0) := "01";

signal dlyCalibState: std_logic_vector(1 downto 0);
signal read_calib_start: std_logic := '0';
signal read_calib_start_d: std_logic := '0';
signal read_calib_source: std_logic := '0';
signal cal_src: integer range 0 to 1 := 0;

type cnt_tap_value_mem is array(0 to 1) of integer range 0 to 64;
signal cnt_tap_value : cnt_tap_value_mem := (0,0);

signal cnt_read_data: integer range 0 to 127 := 0;
signal cnt_read_ok: integer range 0 to 127 := 0;
signal max_tap_value: integer range 0 to 63 := 0;
signal min_tap_value: integer range 0 to 63 := 0;
signal selected_tap_value: integer range 0 to 63 := 0;
signal min_tap_value_set: std_logic := '0';
signal load_cnt_tap_value : std_logic := '0';

signal i_clk_buff : std_logic;
signal i_data_1_buff : std_logic_vector(4 downto 0);
signal i_data_2_buff : std_logic_vector(4 downto 0);

signal i_clk_buff_delayed : std_logic;
signal clk_iddr : std_logic;
signal o_clk_i : std_logic;
signal i_data_1_delayed : std_logic_vector(4 downto 0);
signal i_data_2_delayed : std_logic_vector(4 downto 0);

signal o_data_1_Q1 : std_logic_vector(4 downto 0);
signal o_data_1_Q2 : std_logic_vector(4 downto 0);
signal o_data_2_Q1 : std_logic_vector(4 downto 0);
signal o_data_2_Q2 : std_logic_vector(4 downto 0);

signal tmp_data_1 : std_logic_vector(9 downto 0);
signal tmp_data_2 : std_logic_vector(9 downto 0);
signal tmp_data_1_d : std_logic_vector(9 downto 0);
signal tmp_data_1_ds : std_logic_vector(9 downto 0);
signal tmp_data_1_dd : std_logic_vector(9 downto 0);
signal tmp_data_2_d : std_logic_vector(9 downto 0);
signal tmp_data_2_dd : std_logic_vector(9 downto 0);

signal idelay_rdy : std_logic;
signal idelay_reset : std_logic := '1';
signal i_reset_n_d : std_logic := '0';
signal start_idelay_rst_counter : std_logic := '0';
signal idelay_rst_cnt : integer range 0 to 63 := 0;

signal cnt_test : integer range -512 to 511;

    component fifo_16x20b is
    port (
        clk_wr : in std_logic;
        clk_rd : in std_logic;
        we   : in std_logic;
        di  : in std_logic_vector(19 downto 0);
        do  : out std_logic_vector(19 downto 0));
    end component;


--  Specifies group name for associated IDELAYs/ODELAYs and IDELAYCTRL
--attribute IODELAY_GROUP : STRING;
--attribute IODELAY_GROUP of data_delay: label is "IODELAY_ADC_IF";
--attribute IODELAY_GROUP of IDELAYCTRL_inst: label is "IODELAY_ADC_IF";

attribute mark_debug: boolean;
attribute mark_debug of tmp_data_1_d : signal is true;
attribute mark_debug of tmp_data_2_d : signal is true;
attribute mark_debug of i_data_1_buff : signal is true;
attribute mark_debug of i_data_2_buff : signal is true;
attribute mark_debug of i_data_1_delayed : signal is true;
attribute mark_debug of i_data_2_delayed : signal is true;
attribute mark_debug of clk_iddr : signal is true; 
attribute mark_debug of cnt_read_data : signal is true; 
attribute mark_debug of min_tap_value : signal is true; 
attribute mark_debug of max_tap_value : signal is true; 
attribute mark_debug of cnt_tap_value : signal is true; 
attribute mark_debug of load_cnt_tap_value : signal is true; 
attribute mark_debug of cnt_read_ok : signal is true;
attribute mark_debug of dlyCalibState : signal is true;
attribute mark_debug of read_calib_start_d : signal is true;

-- attribute strings
attribute KEEP: boolean;
attribute ASYNC_REG: boolean;
attribute KEEP of read_calib_start: signal is true;
attribute ASYNC_REG of read_calib_start: signal is true;
attribute KEEP of read_calib_source: signal is true;
attribute ASYNC_REG of read_calib_source: signal is true;

begin

--ADC clock input buffer - diff to se
clk_buff_inst: IBUFDS
generic map (
   DIFF_TERM => FALSE,   -- Differential Termination 
   IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
   IOSTANDARD => "LVDS_25")
port map (
   O => i_clk_buff,
   I => i_clk_p,
   IB => i_clk_n
);

--data input buffers - diff to se
data_buff_inst: for i in 0 to 4 generate
    data1_buff_inst: IBUFDS
    generic map (
      DIFF_TERM => FALSE,   -- Differential Termination 
      IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
      IOSTANDARD => "LVDS_25")
    port map (
      O => i_data_1_buff(i),
      I => i_data_1_p(i),
      IB => i_data_1_n(i)
    );
    data2_buff_inst: IBUFDS
    generic map (
      DIFF_TERM => FALSE,   -- Differential Termination 
      IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
      IOSTANDARD => "LVDS_25")
    port map (
      O => i_data_2_buff(i),
      I => i_data_2_p(i),
      IB => i_data_2_n(i)
    );
end generate;

-- delay input clock 
IDELAYE2_clk_in_delay: IDELAYE2
    generic map (
        CINVCTRL_SEL => "FALSE",
        DELAY_SRC => "IDATAIN",
        HIGH_PERFORMANCE_MODE => "TRUE",   -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
        IDELAY_TYPE => "FIXED",
        IDELAY_VALUE => ADC_CLK_DELAY,     -- Input delay tap setting (0-31)
        PIPE_SEL => "FALSE",
        REFCLK_FREQUENCY => 200.0,
        SIGNAL_PATTERN => "CLOCK"
    )
    port map (
        --   CNTVALUEOUT => CNTVALUEOUT,
        DATAOUT => i_clk_buff_delayed,
        C => '0',
        CE => '0',
        CINVCTRL => '0',
        CNTVALUEIN => "00000",
        DATAIN => '0',
        IDATAIN => NOT(i_clk_buff),    -- INVERT clock signal (p/n pins are swapped on pcb)
        INC => '0',
        LD => '0',
        LDPIPEEN => '0',
        REGRST => '0'
    );
 
-- global clock output (ADC fifo read and global logic)
BUFG_inst: BUFG
   port map (
      O => o_clk_i,  -- 1-bit output: Clock output
      I => clk_iddr  -- 1-bit input: Clock input
   );

-- delayed clock buffer
BUFR_inst: BUFR
   generic map (
      BUFR_DIVIDE => "BYPASS",
      SIM_DEVICE => "7SERIES"
   )
   port map (
      O => clk_iddr,
      CE => '1',
      CLR => '0',
      I => i_clk_buff_delayed
   );

data_fifo_16x20b : fifo_16x20b
    port map (
        clk_wr => clk_iddr,
        clk_rd => o_clk_i,
        we => i_en_fifo,
        di => tmp_data_1_d & tmp_data_2_d,
        do(19 downto 10) => o_data_1,
        do(9 downto 0) => o_data_2
        );
        
o_clk <= o_clk_i;

--delay data1 input 
data_delay: for i in 0 to 4 generate
    IDELAYE2_data1: IDELAYE2
    generic map (
        CINVCTRL_SEL => "FALSE",
        DELAY_SRC => "IDATAIN",
        HIGH_PERFORMANCE_MODE => "FALSE",
        IDELAY_TYPE => "VAR_LOAD",        -- VAR_LOAD
        IDELAY_VALUE => ADC_DATA1_DELAY,  -- fixed delay setting is ignored in VAL_LOAD mode 
        PIPE_SEL => "FALSE",
        REFCLK_FREQUENCY => 200.0,
        SIGNAL_PATTERN => "DATA"
    )
    port map (
        --   CNTVALUEOUT => CNTVALUEOUT,
        DATAOUT => i_data_1_delayed(i),
        C => clk_iddr,
        CE => '0',
        CINVCTRL => '0',
        CNTVALUEIN => std_logic_vector(to_unsigned(cnt_tap_value(0),5)), -- delay value
        DATAIN => '0',
        IDATAIN => i_data_1_buff(i),
        INC => '0',
        LD => load_cnt_tap_value,   -- Loads delay value CNTVALUEIN
        LDPIPEEN => '0',
        REGRST => '0'
    );
    IDELAYE2_data2: IDELAYE2
    generic map (
        CINVCTRL_SEL => "FALSE",
        DELAY_SRC => "IDATAIN",
        HIGH_PERFORMANCE_MODE => "FALSE",
        IDELAY_TYPE => "VAR_LOAD",
        IDELAY_VALUE => ADC_DATA2_DELAY,
        PIPE_SEL => "FALSE",
        REFCLK_FREQUENCY => 200.0,
        SIGNAL_PATTERN => "DATA"
    )
    port map (
        --   CNTVALUEOUT => CNTVALUEOUT,
        DATAOUT => i_data_2_delayed(i),
        C => clk_iddr,
        CE => '0',
        CINVCTRL => '0',
        CNTVALUEIN => std_logic_vector(to_unsigned(cnt_tap_value(1),5)),
        DATAIN => '0',
        IDATAIN => i_data_2_buff(i),
        INC => '0',
        LD => '0',
        LDPIPEEN => '0',
        REGRST => '0'
    );
end generate;

data_ddr_to_se: for i in 0 to 4 generate
   data1_ddr_to_se: IDDR 
   generic map (
      DDR_CLK_EDGE => "OPPOSITE_EDGE", -- "OPPOSITE_EDGE", "SAME_EDGE" 
                                       -- or "SAME_EDGE_PIPELINED" 
      INIT_Q1 => '0',   -- Initial value of Q1
      INIT_Q2 => '0',   -- Initial value of Q2
      SRTYPE => "SYNC") -- Set/Reset type: "SYNC" or "ASYNC" 
   port map (
      Q1 => o_data_1_Q1(i),  -- output for positive edge of clock 
      Q2 => o_data_1_Q2(i),  -- output for negative edge of clock
      C => clk_iddr,
      CE => '1',
      D => i_data_1_delayed(i),
      R => '0',
      S => '0'
      );
   data2_ddr_to_se: IDDR 
   generic map (
      DDR_CLK_EDGE => "OPPOSITE_EDGE",
      INIT_Q1 => '0',
      INIT_Q2 => '0',
      SRTYPE => "SYNC")
   port map (
      Q1 => o_data_2_Q1(i),
      Q2 => o_data_2_Q2(i),
      C => clk_iddr,
      CE => '1',
      D => i_data_2_delayed(i),
      R => '0',
      S => '0'
      );

end generate;

IDELAYCTRL_inst: IDELAYCTRL
   port map (
      RDY => idelay_rdy,    -- 1-bit output: Ready output
      REFCLK => i_clk_ref,    -- 1-bit input: Reference clock input
      RST => idelay_reset     -- 1-bit input: Active high reset input
   );


-- read samples from ADC
-- note that clock LVDS signal is inverted on pcb
-- and ADC channels are interleaved

sample_incoming_data_rising: process(clk_iddr)
begin
    if rising_edge(clk_iddr) then
         
         -- reset IDELAYCTRL
         i_reset_n_d <= i_reset_n;
         if i_reset_n_d = '0' and i_reset_n = '1' then
            start_idelay_rst_counter <= '1';
         elsif i_reset_n_d = '1' and i_reset_n = '0' then
            start_idelay_rst_counter <= '0';
            idelay_rst_cnt <= 0;
         end if;
         if start_idelay_rst_counter = '1' then
            if idelay_rst_cnt = 63 then
                --release IDELAY reset
                idelay_reset <= '0';
            else
                idelay_reset <= '1';
                idelay_rst_cnt <= idelay_rst_cnt + 1;
            end if;
         end if;         
        
        if idelay_rdy = '1' then
            if TEST_MODE = False then
                -- read CH1 EVEN bits from current sample
                tmp_data_1(9) <= o_data_1_Q1(4);
                tmp_data_1(7) <= o_data_1_Q1(3);
                tmp_data_1(5) <= o_data_1_Q1(2);
                tmp_data_1(3) <= o_data_1_Q1(1);
                tmp_data_1(1) <= o_data_1_Q1(0);
                -- read CH2 ODD bits
                tmp_data_2(9) <= o_data_2_Q1(4);
                tmp_data_2(7) <= o_data_2_Q1(3);
                tmp_data_2(5) <= o_data_2_Q1(2);
                tmp_data_2(3) <= o_data_2_Q1(1);
                tmp_data_2(1) <= o_data_2_Q1(0);
            else
                if cnt_test = 511 then
                    cnt_test <= -512;
                else
                    cnt_test <= cnt_test + 1;
                end if;
                tmp_data_1 <= std_logic_vector(to_unsigned(cnt_test,10));
                tmp_data_2 <= std_logic_vector(to_unsigned(cnt_test,10));
            end if;
            tmp_data_1_d <= tmp_data_1;
--            tmp_data_1_ds(8) <= tmp_data_1(8);
--            tmp_data_1_ds(6) <= tmp_data_1(6);
--            tmp_data_1_ds(4) <= tmp_data_1(4);
--            tmp_data_1_ds(2) <= tmp_data_1(2);
--            tmp_data_1_ds(0) <= tmp_data_1(0);
--            tmp_data_1_ds(9) <= tmp_data_1_d(9);
--            tmp_data_1_ds(7) <= tmp_data_1_d(7);
--            tmp_data_1_ds(5) <= tmp_data_1_d(5);
--            tmp_data_1_ds(3) <= tmp_data_1_d(3);
--            tmp_data_1_ds(1) <= tmp_data_1_d(1);
            -- invert tmp_data_2 bits ( D3/D2 LVDS pair pins are swapped on pcb)
            tmp_data_2_d <= tmp_data_2(9 downto 4) & NOT(tmp_data_2(3)) & NOT(tmp_data_2(2)) & tmp_data_2(1 downto 0);
        end if;
        
    end if;
end process;

sample_incoming_data_falling: process(clk_iddr)
begin
    if falling_edge(clk_iddr) then
        
        if idelay_rdy = '1' then
            if TEST_MODE = False then
                -- read CH1 ODD bits from current sample
                tmp_data_1(8) <= o_data_1_Q2(4);
                tmp_data_1(6) <= o_data_1_Q2(3);
                tmp_data_1(4) <= o_data_1_Q2(2);
                tmp_data_1(2) <= o_data_1_Q2(1);
                tmp_data_1(0) <= o_data_1_Q2(0);
                -- read CH2 EVEN bits from current sample 
                tmp_data_2(8) <= o_data_2_Q2(4);
                tmp_data_2(6) <= o_data_2_Q2(3);
                tmp_data_2(4) <= o_data_2_Q2(2);
                tmp_data_2(2) <= o_data_2_Q2(1);
                tmp_data_2(0) <= o_data_2_Q2(0);
            end if;
        end if;
    end if;
end process;

calibrate_idelay: process(clk_iddr)
begin
    
    if rising_edge(clk_iddr) then
    
        if idelay_rdy = '1' then        
        
            read_calib_start <= i_read_calib_start;
            read_calib_start_d <= read_calib_start;
            
            read_calib_source <= i_read_calib_source;
            
            -- implement dynamic calibration to find the center of a data eye for dataA/DataB inputs
            case dlyCalibState is
    
            when dly_calib_idle =>
            
                if read_calib_start_d = '1' then
                    cal_src <= to_integer(unsigned'('0' & read_calib_source));
                    cnt_tap_value(to_integer(unsigned'('0' & read_calib_source))) <= 0;    -- reset IDELAY tap selection
                    dlyCalibState <= dly_calib_run;
                else
                    dlyCalibState <= dly_calib_idle;
                end if;
            
                load_cnt_tap_value <= '0'; 
                cnt_read_data <= 0;        -- ADC samples read
                cnt_read_ok <= 0;          -- samples that were correctly read
                min_tap_value_set <= '0';  -- min tap value set flag
             
            when dly_calib_run =>
            
                if cnt_read_data = 33 then
                    -- if all samples were read correctly for the current tap value
                    if cnt_read_ok = 32 then
                        -- save min tap value
                        if min_tap_value_set = '0' then
                            min_tap_value_set <= '1';
                            min_tap_value <= cnt_tap_value(cal_src);
                            max_tap_value <= cnt_tap_value(cal_src);
                        -- if min tap value was already saved
                        else
                            -- update max tap value
                            max_tap_value <= cnt_tap_value(cal_src);
                        end if;
                        -- if all taps were checked
                        if cnt_tap_value(cal_src) = 31 then
                            cnt_tap_value(cal_src) <= (max_tap_value + min_tap_value)/2;
                            dlyCalibState <= dly_calib_idle;
                        else
                            cnt_tap_value(cal_src) <= cnt_tap_value(cal_src) + 1; -- increase IDELAY tap value
                            dlyCalibState <= dly_calib_run;
                        end if;
                    else
                    -- not all samples were read properly
                        -- if min tap value was already set
                        if min_tap_value_set = '1' then
                            cnt_tap_value(cal_src) <= (max_tap_value + min_tap_value)/2;
                            -- end calibration, because we have reached the end of eye
                            dlyCalibState <= dly_calib_idle;
                        -- countinue searching for min tap value
                        else
                            -- all taps were chcked and min tap value was not found
                            -- we should never get here (but we could if ADC did not send test data)
                            if cnt_tap_value(cal_src) = 31 then
                                cnt_tap_value(cal_src) <= 0;
                                dlyCalibState <= dly_calib_idle;
                            -- not all taps were checked
                            -- continue searching for min tap value
                            else
                                cnt_tap_value(cal_src) <= cnt_tap_value(cal_src) + 1; -- increase IDELAY tap value
                                dlyCalibState <= dly_calib_run;
                            end if;
                        end if;
                    end if;
                    -- reset counters
                    load_cnt_tap_value <= '1';
                    cnt_read_data <= 0;  -- how many samples were read
                    cnt_read_ok <= 0;    -- how many samples were read correctly
                else
                    load_cnt_tap_value <= '0';
                    -- read two consecutive samples and check if they were properly read
                    tmp_data_1_dd <= tmp_data_1_d;
                    tmp_data_2_dd <= tmp_data_2_d;
                    if read_calib_source = '0' then
                        if tmp_data_1_dd = "1010101010" and tmp_data_1_d = "0101010101" then
                            cnt_read_ok <= cnt_read_ok + 1;
                        elsif tmp_data_1_dd = "0101010101" and tmp_data_1_d = "1010101010" then
                            cnt_read_ok <= cnt_read_ok + 1;
                        end if;
                    else
                        if tmp_data_2_dd = "1010101010" and tmp_data_2_d = "0101010101" then
                            cnt_read_ok <= cnt_read_ok + 1;
                        elsif tmp_data_2_dd = "0101010101" and tmp_data_2_d = "1010101010" then
                            cnt_read_ok <= cnt_read_ok + 1;
                        end if;
                    end if;            
                    cnt_read_data <= cnt_read_data + 1;
                    dlyCalibState <= dly_calib_run;
                    
                end if;
            
            when others =>
                dlyCalibState <= dly_calib_idle;
             
            end case;
             
        end if; --rising_edge(clk_iddr)
    end if; --idelay_rdy = '1' 
 
end process;

end Behavioral;