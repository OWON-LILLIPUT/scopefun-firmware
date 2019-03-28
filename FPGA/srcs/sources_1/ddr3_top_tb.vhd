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

-- ddr3 test top module

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;
library user_lib;
use user_lib.TextUtil.all;

entity example_top is
  generic (
   --***************************************************************************
   -- Traffic Gen related parameters
   --***************************************************************************
   BL_WIDTH              : integer := 10;
   PORT_MODE             : string  := "BI_MODE";
   DATA_MODE             : std_logic_vector(3 downto 0) := "0010";
   TST_MEM_INSTR_MODE    : string  := "R_W_INSTR_MODE";
   EYE_TEST              : string  := "FALSE";
                                     -- set EYE_TEST = "TRUE" to probe memory
                                     -- signals. Traffic Generator will only
                                     -- write to one single location and no
                                     -- read transactions will be generated.
   DATA_PATTERN          : string  := "DGEN_ALL";
                                      -- For small devices, choose one only.
                                      -- For large device, choose "DGEN_ALL"
                                      -- "DGEN_HAMMER", "DGEN_WALKING1",
                                      -- "DGEN_WALKING0","DGEN_ADDR","
                                      -- "DGEN_NEIGHBOR","DGEN_PRBS","DGEN_ALL"
   CMD_PATTERN           : string  := "CGEN_ALL";
                                      -- "CGEN_PRBS","CGEN_FIXED","CGEN_BRAM",
                                      -- "CGEN_SEQUENTIAL", "CGEN_ALL"
   BEGIN_ADDRESS         : std_logic_vector(31 downto 0) := X"00000000";
   END_ADDRESS           : std_logic_vector(31 downto 0) := X"00ffffff";
   PRBS_EADDR_MASK_POS   : std_logic_vector(31 downto 0) := X"ff000000";
   CMD_WDT               : std_logic_vector(31 downto 0) := X"000003ff";
   WR_WDT                : std_logic_vector(31 downto 0) := X"00001fff";
   RD_WDT                : std_logic_vector(31 downto 0) := X"000003ff";
   --***************************************************************************
   -- The following parameters refer to width of various ports
   --***************************************************************************
   COL_WIDTH             : integer := 10;
                                     -- # of memory Column Address bits.
   CS_WIDTH              : integer := 1;
                                     -- # of unique CS outputs to memory.
   DQ_WIDTH              : integer := 16;
                                     -- # of DQ (data)
   DQS_CNT_WIDTH         : integer := 1;
                                     -- = ceil(log2(DQS_WIDTH))
   DRAM_WIDTH            : integer := 8;
                                     -- # of DQ per DQS
   ECC_TEST              : string  := "OFF";
   RANKS                 : integer := 1;
                                     -- # of Ranks.
   ROW_WIDTH             : integer := 15;
                                     -- # of memory Row Address bits.
   ADDR_WIDTH            : integer := 29;
                                     -- # = RANK_WIDTH + BANK_WIDTH
                                     --     + ROW_WIDTH + COL_WIDTH;
                                     -- Chip Select is always tied to low for
                                     -- single rank devices
   --***************************************************************************
   -- The following parameters are mode register settings
   --***************************************************************************
   BURST_MODE            : string  := "8";
                                     -- DDR3 SDRAM:
                                     -- Burst Length (Mode Register 0).
                                     -- # = "8", "4", "OTF".
                                     -- DDR2 SDRAM:
                                     -- Burst Length (Mode Register).
                                     -- # = "8", "4".
   
   --***************************************************************************
   -- Simulation parameters
   --***************************************************************************
   SIMULATION            : string  := "FALSE";
                                     -- Should be TRUE during design simulations and
                                     -- FALSE during implementations

   --***************************************************************************
   -- IODELAY and PHY related parameters
   --***************************************************************************
   TCQ                   : integer := 100;
   
   DRAM_TYPE             : string  := "DDR3";

   
   --***************************************************************************
   -- System clock frequency parameters
   --***************************************************************************
   nCK_PER_CLK           : integer := 4;
                                     -- # of memory CKs per fabric CLK

   --***************************************************************************
   -- Debug parameters
   --***************************************************************************
   DEBUG_PORT            : string  := "OFF";
                                     -- # = "ON" Enable debug signals/controls.
                                     --   = "OFF" Disable debug signals/controls.

   --***************************************************************************
   -- Temparature monitor parameter
   --***************************************************************************
   TEMP_MON_CONTROL         : string  := "INTERNAL";
                                     -- # = "INTERNAL", "EXTERNAL"
      
   RST_ACT_LOW           : integer := 0
                                     -- =1 for active low reset,
                                     -- =0 for active high.
   );
  port (

   -- Inouts
   ddr3_dq                        : inout std_logic_vector(15 downto 0);
   ddr3_dqs_p                     : inout std_logic_vector(1 downto 0);
   ddr3_dqs_n                     : inout std_logic_vector(1 downto 0);

   -- Outputs
   ddr3_addr                      : out   std_logic_vector(14 downto 0);
   ddr3_ba                        : out   std_logic_vector(2 downto 0);
   ddr3_ras_n                     : out   std_logic;
   ddr3_cas_n                     : out   std_logic;
   ddr3_we_n                      : out   std_logic;
   ddr3_reset_n                   : out   std_logic;
   ddr3_ck_p                      : out   std_logic_vector(0 downto 0);
   ddr3_ck_n                      : out   std_logic_vector(0 downto 0);
   ddr3_cke                       : out   std_logic_vector(0 downto 0);
   ddr3_odt                       : out   std_logic_vector(0 downto 0);

   -- Inputs
   -- Single-ended system clock
   sys_clk_i                      : in    std_logic;
   -- Single-ended iodelayctrl clk (reference clock)
   clk_ref_i                                : in    std_logic;
   
   tg_compare_error              : out std_logic;
   init_calib_complete           : out std_logic;
   
   -- System reset - Default polarity of sys_rst pin is Active Low.
   -- System reset polarity will change based on the option 
   -- selected in GUI.
      sys_rst                     : in    std_logic
   );

end entity example_top;

architecture arch_example_top of example_top is


component RAM_DDR3 is
Port (
    -- TOP level signals
    sys_clk_i : in std_logic; -- System clock (200 Mhz)
    clk_ref_i : in std_logic;   -- Reference clock 200 Mhz
    ui_clk : out std_logic; -- output clock to user logic
    rst : in STD_LOGIC;
    ReadMode : in std_logic;  -- '1' - immediate / '0' - delay read until full frame is saved
    DataIn : in STD_LOGIC_VECTOR (31 downto 0);
    DataInEnable : in STD_LOGIC;
    DataOut : out STD_LOGIC_VECTOR (31 downto 0);
    DataOutEnable : in STD_LOGIC;
    DataOutValid : out STD_LOGIC;
    DataLength : in std_logic_vector (26 downto 0); -- sample count 2^27 = 128 Mega samples
    reset_complete : out std_logic;
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

    --constants
    constant TEST_STREAM_LENGTH  : integer := 448;   -- number of samples in a frame
    constant TEST_WR_SKIP_CNT : integer := 19;          -- how many samples skipped before writing next sample to RAM
    
    --Inputs
    signal sys_clk : std_logic;
	signal rst : std_logic:='0';
	signal ReadMode : std_logic:='0';
	signal DataIn : STD_LOGIC_VECTOR (31 downto 0);
	signal DataInEnable : std_logic := '0';
	signal DataLength : std_logic_vector (26 downto 0);
	signal reset_complete : std_logic := '0';
	
    --Outputs
	signal ui_clk : std_logic; -- output clock to user logic
	signal DataOut : std_logic_vector (31 downto 0);
	signal DataOutEnable : std_logic;
	signal DataOutValid : STD_LOGIC;
	signal device_temp : std_logic_vector (11 downto 0);
    
    -- tb process signals
    signal clk : std_logic;
    signal init_calib_complete_i : std_logic;
    signal device_temp_i : std_logic_vector (11 downto 0);
    signal DataOut_i : std_logic_vector (31 downto 0);
    signal DataOut_tmp : std_logic_vector (31 downto 0);
    signal CNT : integer range 0 to 1023 := 0;
    signal looping : std_logic := '0';
    signal ui_rd_data_i : std_logic_vector (127 downto 0);
    signal err_reading_data : std_logic := '0';
    signal err_reading_data_i : std_logic := '0';
    signal cnt_wr_all : integer range 0 to (TEST_STREAM_LENGTH)-1 := 0;
    signal cnt_wr_ok : integer range 0 to (TEST_STREAM_LENGTH)-1 := 0;
    signal cnt_wr_skipped : integer range 0 to (TEST_STREAM_LENGTH)-1 := 0;
    signal cnt_rd_all : integer range 0 to (TEST_STREAM_LENGTH)-1 := 0;
    signal cnt_rd_ok : integer range 0 to (TEST_STREAM_LENGTH)-1 := 0;
    signal cnt_rd_skipped : integer range 0 to (TEST_STREAM_LENGTH)-1 := 0;
    signal perf_wr_efficiency : real := 0.0;
    signal perf_rd_efficiency : real := 0.0;
    signal flagd : std_logic := '0';
    signal DataOutEnable_d : std_logic := '0';
    signal read_complete : std_logic := '0';
    
begin

--IBUFDS_inst: IBUFDS
--generic map (
--   DIFF_TERM => FALSE, -- Differential Termination 
--   IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--   IOSTANDARD => "DEFAULT")
--port map (
--   O => sys_clk,  -- Buffer output
--   I => sys_clk_p,  -- Diff_p buffer input (connect directly to top-level port)
--   IB => sys_clk_n  -- Diff_n buffer input (connect directly to top-level port)
--);

-- Instantiate the Unit Under Test (UUT)
uut: RAM_DDR3 PORT MAP (
    sys_clk_i       => sys_clk_i,
    clk_ref_i       => clk_ref_i,
    ui_clk          => clk,
    rst             => rst,
    ReadMode        => ReadMode,
    DataIn          => DataIn,
    DataInEnable    => DataInEnable,
    DataOut         => DataOut_tmp,
    DataOutEnable   => DataOutEnable,
    DataOutValid    => DataOutValid,
    DataLength   => DataLength,
	reset_complete      => reset_complete,
	init_calib_complete => init_calib_complete_i,
	device_temp   => device_temp_i,       
	ddr3_dq         => ddr3_dq,        
	ddr3_dqs_p      => ddr3_dqs_p,     
	ddr3_dqs_n      => ddr3_dqs_n,           
	ddr3_addr       => ddr3_addr,      
	ddr3_ba         => ddr3_ba,        
	ddr3_ras_n      => ddr3_ras_n,     
	ddr3_cas_n      => ddr3_cas_n,     
	ddr3_we_n       => ddr3_we_n,      
	ddr3_reset_n    => ddr3_reset_n,   
	ddr3_ck_p       => ddr3_ck_p,      
	ddr3_ck_n       => ddr3_ck_n,      
	ddr3_cke        => ddr3_cke,       
	ddr3_odt        => ddr3_odt       
);

ui_clk <= clk;
init_calib_complete <= init_calib_complete_i;
device_temp <= device_temp_i;
DataOut <= DataOut_tmp;

-- Reset process
rst_proc: process
begin

       wait until rising_edge(sys_clk_i);
       rst <= '0';
       for i in 1 to 1000 loop
            wait until rising_edge(sys_clk_i);
       end loop;
       rst <= '1';
       for i in 1 to 100 loop
            wait until rising_edge(sys_clk_i);
       end loop;
       rst <= '0';

--       -- test reset when writing to fifo
--       wait until init_calib_complete_i = '1';  
    
--       for i in 1 to 150 loop
--           wait until rising_edge(sys_clk);
--       end loop;
--       RST <= '1';
--       wait until rising_edge(sys_clk);
--       RST <= '0';
	
wait;
end process;


-- Read samples and write them to fifo process (data is sent to fifo)
write_samples: process
    variable counter : integer range 0 to TEST_STREAM_LENGTH := 1;
begin
    wait until init_calib_complete_i = '1';
    
    for i in 1 to 20 loop
        for i in 1 to 20 loop
            wait until rising_edge(sys_clk_i);     
        end loop;
        
        for i in 0 to TEST_STREAM_LENGTH-1 loop
            wait until rising_edge(sys_clk_i);
            DataInEnable <= '1';
            DataIn <= std_logic_vector(to_unsigned(counter,32));
            counter := counter + 1;
            --test interrupted sample write
            if TEST_WR_SKIP_CNT > 0 then
                for i in 0 to TEST_WR_SKIP_CNT loop
                    wait until rising_edge(sys_clk_i);
                    DataInEnable <= '0';
                end loop;
            end if;
        end loop;
        wait until rising_edge(sys_clk_i);
        DataInEnable <= '0';

        wait until rising_edge(read_complete);
--        for i in 0 to 8 * TEST_STREAM_LENGTH-1 loop
--            wait until rising_edge(sys_clk_i);
--        end loop;
        
    end loop;
    
    wait;
end process;

generate_flagd: process

    variable j : integer range 0 to 200 := 1;

begin    

    wait until init_calib_complete_i = '1';
    for i in 0 to 200 loop
        flagd <= '1';
        j := j + 1;
        for i in 0 to 255 loop
            wait until rising_edge(clk);
        end loop;
        flagd <= '0';
        for i in 0 to 50 loop
            wait until rising_edge(clk);
        end loop;
        for i in 0 to j loop
            wait until rising_edge(clk);
        end loop;
        for i in 0 to cnt loop
            wait until rising_edge(clk);
        end loop;
        cnt <= cnt + 1;
    end loop;
    
end process;

read_samples: process

begin
    
    wait until rising_edge(clk);
    DataLength <= std_logic_vector(to_unsigned(TEST_STREAM_LENGTH,DataLength'LENGTH));
    wait until init_calib_complete_i = '1';
    for i in 0 to 200 loop
        wait until rising_edge(clk);
    end loop;
    
    for i in 1 to 20 loop
    
        while to_integer(unsigned(DataOut_i)) < i*(TEST_STREAM_LENGTH+5) loop
            wait until rising_edge(clk);
            if flagd = '0' then
                DataOutEnable <= '0';
            else
                DataOutEnable <= '1';
                cnt_rd_skipped <= cnt_rd_skipped + 1;
            end if;
            DataOutEnable_d <= DataOutEnable;
            cnt_rd_OK <= cnt_rd_OK + 1;
            if (DataOutValid = '1') then
                DataOut_i <= DataOut_tmp;
            end if;
            if (DataOutValid = '1') and (unsigned(DataOut_i) + to_unsigned(1,DataOut_i'LENGTH)) /= unsigned(DataOut_tmp) then
                err_reading_data <= '1';
                --report "The value of 'a' is " & integer'image(a);
            else    
                err_reading_data <= '0';
            end if;
    --        if err_reading_data = '1' then
    --             assert false report "Error reading data!" severity failure;
    --        end if;
        end loop;
        wait until rising_edge(clk);
        DataOutEnable <= '0';

        -- PAUSE 10 clk cycles
        for i in 0 to 10 loop
            wait until rising_edge(clk);
        end loop;
        read_complete <= '1';
        for i in 0 to 10 loop
            wait until rising_edge(clk);
        end loop;
        read_complete <= '0';
        
    end loop;

--    for i in 0 to 353 loop
--        wait until rising_edge(clk);
--    end loop;
--    while to_integer(unsigned(DataOut_i)) < 2*(TEST_STREAM_LENGTH+5) loop
--        wait until rising_edge(clk);
--        if flagd = '0' then
--            DataOutEnable <= '0';
--        else
--            DataOutEnable <= '1';
--            cnt_rd_skipped <= cnt_rd_skipped + 1;
--        end if;
--        DataOutEnable_d <= DataOutEnable;
--        cnt_rd_OK <= cnt_rd_OK + 1;
--        if (DataOutValid = '1') then
--            DataOut_i <= DataOut_tmp;
--        end if;
--        if (DataOutValid = '1') and (unsigned(DataOut_i) + to_unsigned(1,DataOut_i'LENGTH)) /= unsigned(DataOut_tmp) then
--            err_reading_data <= '1';
--            --report "The value of 'a' is " & integer'image(a);
--        else    
--            err_reading_data <= '0';
--        end if;
----        if err_reading_data = '1' then
----             assert false report "Error reading data!" severity failure;
----        end if;
--    end loop;
--    wait until rising_edge(clk);
--    DataOutEnable <= '0';
      
--    perf_wr_efficiency <= Real(cnt_wr_ok)*Real(100)/Real(cnt_wr_all);
--    perf_rd_efficiency <= Real(cnt_rd_ok)*Real(100)/Real(cnt_rd_all);  
--    -- PAUSE 10 clk cycles
--    for i in 0 to 10 loop
--        wait until rising_edge(ui_clk);
--    end loop;

--    -- show results in console window
--    Print("---Stats----");
--    Print("Test stream length ( # of clocks ) " & integer'image(TEST_STREAM_LENGTH));
--    Print("The value of 'cnt_wr_all'     (TOTAL WRITE # CLKS) : " & integer'image(cnt_wr_all));
--    Print("The value of 'cnt_wr_ok'      (written pkts)       : " & integer'image(cnt_wr_ok));
--    Print("The value of 'cnt_wr_skipped' (skipped write clks) : " & integer'image(cnt_wr_skipped));
--    Print("The value of 'cnt_rd_all'     (TOTAL READ # CLKS)  : " & integer'image(cnt_rd_all));
--    Print("The value of 'cnt_rd_ok'      (read pkts)          : " & integer'image(cnt_rd_ok));
--    Print("The value of 'cnt_rd_skipped' (skipped read pkts)  : " & integer'image(cnt_rd_skipped));
--    Print("Efficiency: ");
--    Print("  Writes : " & real'image(perf_wr_efficiency) & " %");
--    Print("  Reads  : " & real'image(perf_rd_efficiency) & " %");

--    if err_reading_data = '1' then
--        Print("W/R FAILED: err_reading_data");
--    else
--        Print("W/R TEST PASSED");
--    end if;
--    Print("------------");
    
    -- stop simulation
    assert false report "simulation ended" severity failure;
    wait;

end process;

end architecture arch_example_top;
