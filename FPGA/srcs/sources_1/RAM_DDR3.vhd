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
-- Scopefun firmware: DDR3 RAM top level
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity RAM_DDR3 is
Port (
    -- TOP level signals
    sys_clk_i : in std_logic;   -- System clock 250 Mhz
    clk_ref_i : in std_logic;   -- Reference clock 200 Mhz
    ui_clk : out std_logic; -- Output clock for user logic (100 Mhz)
    rst : in STD_LOGIC; 
    FrameSize : in std_logic_vector(26 downto 0);
    DataIn : in STD_LOGIC_VECTOR (31 downto 0);
    PreTrigSaving : in std_logic; -- assrted (de-asserted) at start (end) of pre-trigger
    PreTrigWriteEn : in STD_LOGIC; -- pre-trigger write enable
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
end RAM_DDR3;

architecture Behavioral of RAM_DDR3 is

    CONSTANT DDR3_MAX_SAMPLES : integer := 2**27; -- 2^27 = 128M samples
   
    -- RAM state machine signals
    CONSTANT A: STD_LOGIC_VECTOR (2 DownTo 0) := "000";
    CONSTANT B: STD_LOGIC_VECTOR (2 DownTo 0) := "001";
    CONSTANT C: STD_LOGIC_VECTOR (2 DownTo 0) := "010";
    CONSTANT D: STD_LOGIC_VECTOR (2 DownTo 0) := "011";
    CONSTANT E: STD_LOGIC_VECTOR (2 DownTo 0) := "100";
    CONSTANT F: STD_LOGIC_VECTOR (2 DownTo 0) := "101";
    signal RAMstate : std_logic_vector (2 downto 0):=A;

--Write FIFO:
    
    component fifo_32_to_128
		port (
		  clk_wr  : in  STD_LOGIC;
		  clk_rd  : in std_logic;
          rst     : in  STD_LOGIC;
          WriteEn : in  STD_LOGIC;
          DataIn  : in  STD_LOGIC_VECTOR (31 downto 0);
          ReadEn  : in  STD_LOGIC;
          DataOut     : out STD_LOGIC_VECTOR (127 downto 0);
          Empty       : out STD_LOGIC;
          AlmostEmpty : out STD_LOGIC;
          Full        : out STD_LOGIC;
          AlmostFull  : out STD_LOGIC
		);
	end component;

--Read FIFO:

    component fifo_128_to_32
        port (
          clk     : in  STD_LOGIC;
          rst     : in  STD_LOGIC;
          WriteEn : in  STD_LOGIC;
          DataIn  : in  STD_LOGIC_VECTOR (127 downto 0);
          ReadEn  : in  STD_LOGIC;
          DataOut     : out STD_LOGIC_VECTOR (31 downto 0);
          DataOutValid : out STD_LOGIC;
          Empty       : out STD_LOGIC;
          AlmostEmpty : out STD_LOGIC;
          Full        : out STD_LOGIC;
          AlmostFull  : out STD_LOGIC
        );
    end component;

--DDR3 interface top level:

    component ddr3_simple_ui is
    Port (  
        -- DDR3 simple user interface
        sys_clk_i : in std_logic;
        clk_ref_i : in std_logic;
--        clk_n : in std_logic;
        ui_clk : out std_logic; -- output clock to user logic
        ui_rd_data : out std_logic_vector (127 downto 0);
        ui_wr_data : in std_logic_vector (127 downto 0);
        ui_reset : in std_logic;
        ui_wr_framesize : in std_logic_vector (26 downto 0);    -- length of frame
        ui_wr_pretriglenth : in std_logic_vector (26 downto 0); -- pre-trigger length
        ui_PreTrigSavingCntRecvd : in std_logic;
        ui_wr_preTrigSavingCnt : in std_logic_vector (26 downto 0); -- number of saved samples before trigger
        ui_wr_rdy : out std_logic;         -- ready to receive write requests
        ui_wr_data_waiting : in std_logic; -- flag: data is waiting to be written in RAM
        ui_frameStart : in std_logic;      -- new frame has started saving into write fifo
        ui_rd_ready : in std_logic;        -- read data from RAM
        ui_rd_data_valid : out std_logic;
        ui_rd_data_available : out std_logic; -- asserted if write counter is higher than read counter
        init_calib_complete : out std_logic;
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
    
	--Inputs
    signal fwr_rst        : std_logic := '0';
    signal fwr_DataIn    : std_logic_vector(31 downto 0) := (others => '0');
    signal fwr_ReadEn    : std_logic := '0';
    signal fwr_WriteEn    : std_logic := '0';
    --Outputs
    signal fwr_DataOut    : std_logic_vector(127 downto 0);
    signal fwr_Empty    : std_logic;
    signal fwr_Empty_d    : std_logic;
    signal fwr_Empty_dd    : std_logic;
    signal fwr_Full        : std_logic;
    signal fwr_AlmostEmpty    : std_logic;
    signal fwr_AlmostFull   : std_logic;
    
    -- internal
    signal fwr_AlmostFull_d : std_logic := '0';
    signal fwr_AlmostFull_dd : std_logic;
    signal fwr_AlmostEmpty_d : std_logic := '0';
    signal fwr_AlmostEmpty_dd : std_logic;
    signal fwr_AlmostEmpty_ddd : std_logic;
                    
	--Inputs
    signal frd_rst       : std_logic := '0';
    signal frd_DataIn    : std_logic_vector(127 downto 0) := (others => '0');
    signal frd_ReadEn    : std_logic := '0';
    signal frd_ReadEn_d  : std_logic := '0';
    signal frd_ReadEn_dd  : std_logic := '0';
    signal frd_ReadEn_ddd  : std_logic := '0';
    signal frd_ReadEn_dddd  : std_logic := '0';
    signal frd_WriteEn   : std_logic := '0';
    --Outputs
    signal frd_DataOut  : std_logic_vector(31 downto 0);
    signal frd_DataOutValid : std_logic;
    signal frd_Empty    : std_logic;
    signal frd_Full        : std_logic;
    signal frd_AlmostEmpty : std_logic;
    signal frd_AlmostFull  : std_logic;
    -- internal
    signal frd_AlmostEmpty_d : std_logic := '0';
    signal frd_AlmostFull_d : std_logic := '0';
    signal fwr_ReadEn_i : std_logic := '0';
    signal frd_Empty_asserted : std_logic := '0';
    
	signal ui_clk_i : std_logic;
	signal ui_wr_data : std_logic_vector (127 downto 0) := std_logic_vector(to_unsigned(0,128));
	-- max sample count 2^27 = 134 Mega samples
	signal ui_wr_pretriglenth : std_logic_vector (26 downto 0) := std_logic_vector(to_unsigned(0,27));
	signal ui_rd_ready : std_logic :='0'; -- start reading samples
	signal ui_wr_data_waiting : std_logic := '0';
    signal ui_wr_data_waiting_i : std_logic := '0';
	signal ui_rd_data : std_logic_vector (127 downto 0);
	signal ui_rd_data_available : std_logic := '0';
	signal ui_wr_rdy : std_logic;  -- ready to save samples
	signal ui_rd_data_valid : std_logic;
    signal ui_rd_data_valid_i : std_logic;
    signal ui_rd_last_sample : std_logic;
    signal init_calib_complete_i : std_logic;
    signal fwr_cnt : integer range 0 to 1023 := 0;
    signal rd_data_waiting : std_logic := '0';
    signal RamWriteOnly : std_logic := '0';
    signal PreTrigSaving_d : std_logic := '0';
    signal PreTrigSaving_dd : std_logic := '0';
    signal PreTrigSaving_ddd : std_logic := '0';    
    signal PreTrigSaving_i : std_logic := '0';
    signal ui_frameStart : std_logic := '0';
    signal ram_rdy_i : std_logic := '0';
    signal DebugRAMState : integer range 0 to 3;

    signal PreTrigSavingCnt : integer range 0 to DDR3_MAX_SAMPLES-1 := 0;
    signal PreTrigSavingCnt_d : std_logic_vector (26 downto 0);
    signal PreTrigSavingCnt_dd : std_logic_vector (26 downto 0);   
    signal PreTrigSavingCntMod : integer range 0 to 3;
    signal PreTrigSavingCntMod_d : integer range 0 to 3;    
    signal PreTrigSavingCntRecvd : std_logic := '0';
    signal PreTrigSavingCntRecvd_d : std_logic := '0';
    signal PreTrigSavingCntRecvd_dd : std_logic := '0';    
    signal PreTrigSavingCntReset : std_logic := '0';
    signal ui_PreTrigSavingCntRecvd : std_logic := '0';
    signal FrameSaveEnd_d : std_logic := '0';   
    signal FrameSaveEnd_dd : std_logic := '0';
    signal wr_FifoFill : std_logic := '0';
    signal wr_FifoFill_d : std_logic := '0';
    signal FillFifoCnt : integer range 0 to 3 := 0;
    signal PostFrameSave : std_logic := '0';
    signal rst_d : std_logic := '0';
    signal frd_data_cnt : unsigned(26 downto 0);
    
-- attribute strings
attribute KEEP: boolean;
attribute ASYNC_REG: boolean;

-- CDC registers (clock domain crossing signals)
attribute KEEP of PreTrigWriteEn: signal is true;
attribute ASYNC_REG of PreTrigWriteEn: signal is true;
attribute KEEP of PreTrigSaving_d: signal is true;
attribute ASYNC_REG of PreTrigSaving_d: signal is true;
attribute KEEP of PreTrigSavingCnt: signal is true;
attribute KEEP of PreTrigSavingCnt_d: signal is true;
attribute ASYNC_REG of PreTrigSavingCnt_d: signal is true;
attribute KEEP of PreTrigSavingCntRecvd: signal is true;
attribute KEEP of PreTrigSavingCntRecvd_d: signal is true;
attribute ASYNC_REG of PreTrigSavingCntRecvd_d: signal is true;
attribute KEEP of PreTrigSavingCntRecvd_dd: signal is true;
attribute ASYNC_REG of PreTrigSavingCntRecvd_dd: signal is true;

attribute KEEP of fwr_AlmostFull_d: signal is true;
attribute KEEP of fwr_AlmostFull_dd: signal is true;
attribute ASYNC_REG of fwr_AlmostFull_d: signal is true;
attribute ASYNC_REG of fwr_AlmostFull_dd: signal is true;

attribute KEEP of fwr_AlmostEmpty_d: signal is true;
attribute KEEP of fwr_AlmostEmpty_dd: signal is true;
attribute ASYNC_REG of fwr_AlmostEmpty_d: signal is true;
attribute ASYNC_REG of fwr_AlmostEmpty_dd: signal is true;

attribute KEEP of fwr_Empty_d: signal is true;
attribute KEEP of FrameSaveEnd_d: signal is true;
attribute ASYNC_REG of fwr_Empty_d: signal is true;
attribute ASYNC_REG of FrameSaveEnd_d: signal is true;
attribute KEEP of rst_d: signal is true;
attribute ASYNC_REG of rst_d: signal is true;
attribute KEEP of ram_rdy: signal is true;
attribute ASYNC_REG of ram_rdy: signal is true;

attribute mark_debug: boolean;
attribute mark_debug of DebugRAMState : signal is true;
attribute mark_debug of fwr_WriteEn : signal is true;
attribute mark_debug of fwr_ReadEn : signal is true;
attribute mark_debug of fwr_Full : signal is true;
attribute mark_debug of fwr_Empty : signal is true;
attribute mark_debug of frd_WriteEn : signal is true;
attribute mark_debug of frd_ReadEn : signal is true;
attribute mark_debug of frd_Full : signal is true;
attribute mark_debug of frd_Empty : signal is true;
attribute mark_debug of ui_rd_data_available : signal is true;
attribute mark_debug of frd_DataOut : signal is true;

attribute keep of ui_frameStart: signal is true;
attribute mark_debug of ui_frameStart : signal is true;
attribute mark_debug of PreTrigSaving_d: signal is true;
attribute mark_debug of ui_rd_ready: signal is true;
attribute mark_debug of ui_wr_data_waiting_i: signal is true;
attribute mark_debug of PreTrigSavingCnt_d: signal is true;

attribute mark_debug of PreTrigSavingCnt      : signal is true;
attribute mark_debug of PreTrigSavingCntReset : signal is true;
attribute mark_debug of FrameSaveEnd_d        : signal is true;
attribute mark_debug of wr_FifoFill           : signal is true;
attribute mark_debug of PreTrigSavingCntMod   : signal is true;
attribute mark_debug of FillFifoCnt           : signal is true;
attribute mark_debug of PostFrameSave         : signal is true;
attribute mark_debug of PreTrigSavingCntMod_d : signal is true;

attribute keep of frd_data_cnt : signal is true;
attribute mark_debug of frd_data_cnt : signal is true;

begin

RAM_WRITE_FIFO: fifo_32_to_128 PORT MAP (
	clk_wr		 => sys_clk_i,
	clk_rd       => ui_clk_i,
	RST		     => rst_d,
	DataIn	     => fwr_DataIn,
	WriteEn	     => fwr_WriteEn,
	ReadEn	     => fwr_ReadEn,
	DataOut	     => fwr_DataOut,
	Full	     => fwr_Full,
	Empty	     => fwr_Empty,
	AlmostEmpty  => fwr_AlmostEmpty,
	AlmostFull   => fwr_AlmostFull
	);
	
RAM_READ_FIFO: fifo_128_to_32 PORT MAP (
    CLK          => ui_clk_i,
    RST          => rst,
    DataIn       => frd_DataIn,
    WriteEn      => frd_WriteEn,
    ReadEn       => frd_ReadEn,
    DataOut      => frd_DataOut,
    DataOutValid => frd_DataOutValid,
    Full         => frd_Full,
    Empty        => frd_Empty,
    AlmostEmpty  => frd_AlmostEmpty,
    AlmostFull   => frd_AlmostFull
    );
			
RAM: ddr3_simple_ui PORT MAP (
	-- DDR3 simple user interface
	sys_clk_i  => sys_clk_i,
	clk_ref_i  => clk_ref_i,       
	ui_clk     => ui_clk_i,         
	ui_rd_data          => ui_rd_data,
	ui_wr_data          => ui_wr_data,
	ui_reset            => rst,
	ui_wr_framesize     => FrameSize,
	ui_frameStart       => ui_frameStart,
	ui_wr_pretriglenth  => PreTrigLen,
	ui_PreTrigSavingCntRecvd => PreTrigSavingCntRecvd,
	ui_wr_preTrigSavingCnt => PreTrigSavingCnt_dd,
	ui_wr_rdy           => ui_wr_rdy,
	ui_wr_data_waiting  => ui_wr_data_waiting,
	ui_rd_ready         => ui_rd_ready,
	ui_rd_data_valid    => ui_rd_data_valid_i,
	ui_rd_data_available   => ui_rd_data_available,
	init_calib_complete => init_calib_complete_i,
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

ui_clk <= ui_clk_i;
init_calib_complete <= init_calib_complete_i;

-- connect write fifo signals (write cache)
fwr_WriteEn <= DataWriteEn OR PreTrigWriteEn OR PostFrameSave;
fwr_DataIn <= DataIn;
fwr_ReadEn <= ui_wr_rdy; --and not(fwr_Empty); --and ui_wr_data_waiting;
ui_wr_data <= fwr_DataOut;
ui_wr_data_waiting <= ui_wr_data_waiting_i;

-- connect read fifo signals (read cache)
frd_Datain <= ui_rd_data;
frd_WriteEn <= ui_rd_data_valid_i;
--frd_ReadEn <= DataOutEnable and NOT(frd_Empty);

WR_FIFO_proc: process (sys_clk_i)
begin

    if rising_edge (sys_clk_i) then
            
        rst_d <= rst;
        ram_rdy <= ram_rdy_i; 
        
        if rst_d = '1' then
            PreTrigSavingCntReset <= '0';
            PreTrigSavingCnt <= 0;
            PreTrigSavingCntMod <= 0;
            wr_FifoFill <= '0';
            PostFrameSave <= '0';
            FillFifoCnt <= 0;
        else
            PreTrigSavingCntRecvd_d <= PreTrigSavingCntRecvd;
            PreTrigSavingCntRecvd_dd <= PreTrigSavingCntRecvd_d;
            if PreTrigSavingCntRecvd_dd = '0' and PreTrigSavingCntRecvd_d = '1' then
                PreTrigSavingCntReset <= '1';
            else
                PreTrigSavingCntReset <= '0';
            end if;
            
            -- if start of pre-trigger saving
            -- asserted every time a pre-trigger sample is saved in write fifo
            if PreTrigWriteEn = '1' then
                -- count number of pre-trigger samples
                PreTrigSavingCnt <= PreTrigSavingCnt + 1;
            -- if end of pre-trigger saving
            -- determine first sample position (offset: 0 to 3) within the first RAM address (single RAM location holds 4 samples)
            elsif PreTrigSavingCntReset = '1' then
                PreTrigSavingCnt <= 0;
                PreTrigSavingCntMod <= PreTrigSavingCnt mod 4;
            end if;
            -- if end of frame saving
            FrameSaveEnd_d <= FrameSaveEnd;
            FrameSaveEnd_dd <= FrameSaveEnd_d;
            if FrameSaveEnd_dd = '0' and FrameSaveEnd_d = '1' then
                wr_FifoFill <= '1';
            end if;
            -- continue saving to write fifo if number of saved samples are not multiple of 4
            if wr_FifoFill = '1' and PreTrigSavingCntMod /= 0 then
                if FillFifoCnt = 4 - PreTrigSavingCntMod then
                    wr_FifoFill <= '0';
                    FillFifoCnt <= 0;
                    PostFrameSave <= '0';
                 else
                    wr_FifoFill <= '1';
                    FillFifoCnt <= FillFifoCnt + 1;
                    PostFrameSave <= '1';
                 end if;
            elsif wr_FifoFill = '1' and PreTrigSavingCntMod = 0 then
                wr_FifoFill <= '0';
            end if; 
        end if; --rst
    end if;
    
end process;


RAM_DDR3_proc: process (ui_clk_i)
begin

    if rising_edge (ui_clk_i) then
              
        DataOut <= frd_DataOut;
        if ui_rd_data_valid_i = '1' then
            --count how many samples were transfered to rd_fifo
            frd_data_cnt <= frd_data_cnt + 1;
        end if;
        
        -- enable reading samples from RAM
        -- assert data valid according to the fisrt sample location within RAM address 
        if frd_DataOutValid = '1' then
            if PreTrigSavingCntMod_d = 0 then
                DataOutValid <= frd_DataOutValid;
            else
                DataOutValid <= '0';     
                PreTrigSavingCntMod_d <= PreTrigSavingCntMod_d - 1;
            end if;
        else
            DataOutValid <= frd_DataOutValid;
        end if;
         --end of frame
        
        if init_calib_complete_i = '1' then
            
            PreTrigSaving_d <= PreTrigSaving;
            PreTrigSaving_dd <= PreTrigSaving_d;
            PreTrigSaving_ddd <= PreTrigSaving_dd;
            if PreTrigSaving_dd = '0' and PreTrigSaving_d = '1' then
                ui_frameStart <= '1';
                -- reset rd_fifo write counter before starting new frame save
                frd_data_cnt <= to_unsigned(0,27);
                -- reset rd_fifo
            else
                ui_frameStart <= '0';
            end if;
            
            PreTrigSavingCnt_d <= std_logic_vector(to_unsigned(PreTrigSavingCnt,PreTrigSavingCnt_d'length));
            if PreTrigSaving_ddd = '1' and PreTrigSaving_dd = '0' then
                PreTrigSavingCnt_dd <= PreTrigSavingCnt_d;
                PreTrigSavingCntMod_d <= to_integer(unsigned(PreTrigSavingCnt_d)) mod 4;
                PreTrigSavingCntRecvd <= '1';
            else
                PreTrigSavingCntRecvd <= '0';
            end if;
            
            fwr_AlmostFull_d <= fwr_AlmostFull;
            fwr_AlmostFull_dd <= fwr_AlmostFull_d;
            fwr_AlmostEmpty_d <= fwr_AlmostEmpty;
            fwr_AlmostEmpty_dd <= fwr_AlmostEmpty_d;
            fwr_AlmostEmpty_ddd <= fwr_AlmostEmpty_dd;
            fwr_Empty_d <= fwr_Empty;
            
            frd_AlmostFull_d <= frd_AlmostFull;
            
            frd_AlmostEmpty_d <= frd_AlmostEmpty;
                       
            -- if read data is requested assert read fifo ReadEn
            if DataOutEnable = '1' then
                -- if read fifo is almost full, start reading data from it
                if frd_AlmostFull_d = '1' then
                    frd_ReadEn <= '1';
                -- if read fifo is empty, stop reading data from it
                elsif frd_Empty = '1' then
                    frd_ReadEn <= '0';
                -- if all samples have been read out of RAM
                elsif frd_data_cnt >= unsigned(FrameSize)/4 then
                    -- keep frd_ReadEn asserted to empty out read fifo
                    frd_ReadEn <= '1';
                end if;
            else
                -- read is not requested and complete frame was transfered
                -- but read fifo is still not empty
                -- this can happen if more samples were saved in RAM than framesize
                --if DataOutEnable = '0' and ReadingFrame = '0' and frd_Empty = '0' then
                if ReadingFrame = '0' and frd_data_cnt >= unsigned(FrameSize)/4 and frd_Empty = '0'then
                    -- assert read enable to read redundant samples from read fifo
                    frd_ReadEn <= '1';
                else
                    frd_ReadEn <= '0';
                end if;
            end if;
            
            
--            if DataOutEnable = '1' and frd_Empty = '0' then
--                frd_ReadEn <= '1';
--            else
--                -- if complete frame was sent to FX3, but read fifo is still not empty
--                if ReadingFrame = '0' and DataOutEnable = '0' and frd_Empty = '0' then
--                    -- assert read enable to read redundant samples from read fifo
--                    frd_ReadEn <= '1';
--                else
--                    frd_ReadEn <= '0';
--                end if;
--            end if;
            
            -- if frame reading is finished and read fifo is empty
            if ReadingFrame = '0' and frd_Empty = '1' then
                -- assert ram_rdy signal to allow start of new frame saving
                ram_rdy_i <= '1';
            else
                ram_rdy_i <= '0';
            end if;
            
            case RAMstate(2 downto 0) is
            
                when A =>
                
                    -- if there is incoming data 
                    if fwr_Empty_d = '0' then
                        RAMstate <= B;
                    elsif ui_rd_data_available = '1' then
                        RAMstate <= D;
                    else
                        RAMstate <= A;
                    end if;
                    fwr_cnt <= 0;
                    DebugRAMState <= 0;
                
                when B =>  -- WRITING to RAM (PRE-TRIGGER))
                
                    if rst = '1' then
                        RAMstate <= A;
                        ui_wr_data_waiting_i <= '0';
                    else
                        if PreTrigSaving_ddd = '1' then
                            -- if write fifo is almost empty
                            if fwr_AlmostFull_dd = '1' then
                                ui_wr_data_waiting_i <= '1';
                            elsif fwr_AlmostEmpty_dd = '1' then
                                -- transfer data from write fifo into RAM
                                ui_wr_data_waiting_i <= '0';
                            end if;
                            RAMstate <= B;
                        else
                            ui_wr_data_waiting_i <= '0';
                            RAMstate <= C;
                        end if;
                    end if;
                    DebugRAMState <= 1;

                when C =>  -- WRITING to RAM (TRIGGER)

                    if rst = '1' then
                        RAMstate <= A;
                        ui_wr_data_waiting_i <= '0';
                    else
                        -- if write fifo is almost empty
                        if fwr_AlmostEmpty_d = '1' then
                            ui_wr_data_waiting_i <= '0';
                            RAMstate <= D;
                        else
                            -- transfer data from write fifo into RAM
                            ui_wr_data_waiting_i <= '1';
                            RAMstate <= C;
                        end if;
                    end if;
                    DebugRAMState <= 2;
                    
                when D => -- READING from RAM
                    
                    if rst = '1' then
                        ui_rd_ready <= '0';
                        ui_wr_data_waiting_i <= '0';
                        fwr_cnt <= 0;
                        RAMstate <= A;
                    else
                        -- if read fifo is NOT AlmostFull
                        if fwr_AlmostFull_dd = '0' then
                            -- we can now start reading data from RAM
                            -- if read fifo is not full and there is some data in RAM
                            if ui_rd_data_available = '1' then
                                -- transfering data from RAM into read fifo
                                -- read fifo write enable
                                ui_rd_ready <= NOT(frd_AlmostFull_d);
                                RAMstate <= D;
                            -- else: no more data is saved in RAM
                            else
                                ui_rd_ready <= '0';
                                -- if write fifo has some data (when write fifo is NOT AlmostFull)
                                -- then transfer one word at a time from write fifo to RAM
                                if fwr_Empty = '0' then
                                    if fwr_cnt = 7 then
                                        fwr_cnt <= 0;
                                        ui_wr_data_waiting_i <= '0';
                                    elsif fwr_cnt = 0 then
                                        -- asserts read flag for 1 clk cycle
                                        ui_wr_data_waiting_i <= '1';
                                        fwr_cnt <= fwr_cnt + 1;
                                    else
                                        -- de-assert write flag
                                        fwr_cnt <= fwr_cnt + 1;
                                        ui_wr_data_waiting_i <= '0';
                                    end if;
                                    RAMstate <= C;
                                --elsif there is some data waiting to be read from RAM
                                elsif ui_rd_data_available = '1' then
                                    RAMstate <= D;
                                else
                                    -- nothing to do (go idle)
                                    RAMstate <= A;
                                end if;
                            end if;
                        else
                            -- save some data first
                            ui_rd_ready <= '0';
                            RAMstate <= C;
                        end if;
                    end if;
                    DebugRAMState <= 3;
                
                when others => NULL;
                
                end case;
                
            end if;
                       
    end if;
end process;

end Behavioral;
