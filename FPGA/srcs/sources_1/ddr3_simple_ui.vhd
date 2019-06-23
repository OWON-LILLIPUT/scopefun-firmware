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
-- Scopefun firmware: DDR3 interface
--


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ddr3_simple_ui is
    Port (  
            -- DDR3 simple user interface
            sys_clk_i : in std_logic;
            clk_ref_i : in std_logic;
--            clk_n : in std_logic;
            ui_clk : out std_logic; -- output clock to user logic
            ui_rd_data : out std_logic_vector (127 downto 0);
            ui_wr_data : in std_logic_vector (127 downto 0);
            ui_reset : in std_logic;
            ui_wr_framesize : in std_logic_vector (26 downto 0);
            ui_wr_pretriglenth : in std_logic_vector (26 downto 0); -- pre-trigger length
            ui_PreTrigSavingCntRecvd : in std_logic;
            ui_wr_preTrigSavingCnt : in std_logic_vector (26 downto 0); -- number of saved samples before trigger
            ui_wr_data_waiting : in std_logic; -- there is data waiting to be written
            ui_wr_rdy : out std_logic;         -- ready to receive write requests
            ui_frameStart : in std_logic;      -- new frame has started saving into write fifo
            ui_rd_ready : in std_logic;        -- start reading samples
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
end ddr3_simple_ui;

architecture Behavioral of ddr3_simple_ui is

component mig_ddr3
  port (
      ddr3_dq       : inout std_logic_vector(15 downto 0);
      ddr3_dqs_p    : inout std_logic_vector(1 downto 0);
      ddr3_dqs_n    : inout std_logic_vector(1 downto 0);
      ddr3_addr     : out   std_logic_vector(14 downto 0);
      ddr3_ba       : out   std_logic_vector(2 downto 0);
      ddr3_ras_n    : out   std_logic;
      ddr3_cas_n    : out   std_logic;
      ddr3_we_n     : out   std_logic;
      ddr3_reset_n  : out   std_logic;
      ddr3_ck_p     : out   std_logic_vector(0 downto 0);
      ddr3_ck_n     : out   std_logic_vector(0 downto 0);
      ddr3_cke      : out   std_logic_vector(0 downto 0);
      ddr3_odt      : out   std_logic_vector(0 downto 0);
      app_addr                  : in    std_logic_vector(28 downto 0);
      app_cmd                   : in    std_logic_vector(2 downto 0);
      app_en                    : in    std_logic;
      app_wdf_data              : in    std_logic_vector(127 downto 0);
      app_wdf_end               : in    std_logic;
      app_wdf_wren              : in    std_logic;
      app_rd_data               : out   std_logic_vector(127 downto 0);
      app_rd_data_end           : out   std_logic;
      app_rd_data_valid         : out   std_logic;
      app_rdy                   : out   std_logic;
      app_wdf_rdy               : out   std_logic;
      app_sr_req                : in    std_logic;
      app_ref_req               : in    std_logic;
      app_zq_req                : in    std_logic;
      app_sr_active             : out   std_logic;
      app_ref_ack               : out   std_logic;
      app_zq_ack                : out   std_logic;
      ui_clk                    : out   std_logic;
      ui_clk_sync_rst           : out   std_logic;
      init_calib_complete       : out   std_logic;
      -- System Clock Ports
      sys_clk_i                  : in   std_logic;
      -- Reference Clock Ports
      clk_ref_i                  : in   std_logic;
      device_temp              : out  std_logic_vector(11 downto 0);
      sys_rst                    : in   std_logic
  );
end component mig_ddr3;
    
CONSTANT RAM_SIZE : integer := 2**27; -- available space in RAM (number of 32-bit samples)

-- RAM state machine signals
CONSTANT A: STD_LOGIC_VECTOR (2 DownTo 0) := "000";
CONSTANT B: STD_LOGIC_VECTOR (2 DownTo 0) := "001";
CONSTANT C: STD_LOGIC_VECTOR (2 DownTo 0) := "010";
CONSTANT D: STD_LOGIC_VECTOR (2 DownTo 0) := "011";
CONSTANT E: STD_LOGIC_VECTOR (2 DownTo 0) := "100";
CONSTANT F: STD_LOGIC_VECTOR (2 DownTo 0) := "101";
signal RAMstate : std_logic_vector (2 downto 0):=A;

-- MIG generated
signal app_addr               : std_logic_vector(28 downto 0) := std_logic_vector(to_unsigned(0,29));
signal app_cmd                : std_logic_vector(2 downto 0) := "000";
signal app_en                 : std_logic := '0';
signal app_rdy                : std_logic;
signal app_rd_data            : std_logic_vector(127 downto 0);
signal app_rd_data_end        : std_logic;
signal app_rd_data_valid      : std_logic;
signal app_rd_data_valid_i    : std_logic;
signal app_wdf_data           : std_logic_vector(127 downto 0);
signal app_wdf_end            : std_logic := '0';
signal app_wdf_wren           : std_logic := '0';
signal app_wdf_wren_i         : std_logic := '0';    
signal app_wdf_wren_ii        : std_logic := '0'; 
signal app_wdf_end_i          : std_logic := '0';
signal app_wdf_end_ii         : std_logic := '0';
signal app_wdf_rdy            : std_logic;
signal app_wdf_rdy_d          : std_logic;
signal app_sr_active          : std_logic;
signal app_ref_ack            : std_logic;
signal app_zq_ack             : std_logic;

-- System Clock Ports (250 Mhz input clock)
signal sys_clk_p : std_logic;
signal sys_clk_n : std_logic;
-- User logic clock
signal ui_clk_i : std_logic;
signal ui_clk_sync_rst : std_logic;
-- Reference Clock Ports (200 Mhz ref. clkj)
--signal clk_ref_i : std_logic;
--signal sys_rst : std_logic;

signal app_addr_i_wr : unsigned(27 downto 0):= to_unsigned(0,28); -- range 0 to (2**28)-1 := 0; --> 16 bit * 2**28 = 4 Gbit
signal app_addr_i_rd : unsigned(27 downto 0):= to_unsigned(0,28); --integer range 0 to (2**28)-1 := 0;
signal app_addr_i_wr_start : integer range 0 to (2**28)-1 := 0;
signal wr_cnt : integer range 0 to RAM_SIZE-1 := 0;
signal wr_word_start: integer range 0 to 3;
signal ui_wr_data_d : std_logic_vector (127 downto 0);
signal ui_wr_data_dd : std_logic_vector (127 downto 0);
signal wr_start : std_logic := '0';
signal rd_cnt : integer range 0 to RAM_SIZE-1 := 0;
signal ui_rd_ready_d : std_logic := '0';
signal rd_start : std_logic := '0';
signal wr_pretriglen : integer range 0 to (2**27)-1;
signal wr_pretrigsaved : integer range 0 to (2**27)-1;
signal wr_length_addr : integer range 0 to (2**28)-1;
signal wr_postlength_addr : integer range 0 to (2**28)-1;
signal tmp_cnt : integer range 0 to (2**24)-1;
signal new_data_waiting : std_logic;
signal ui_wr_data_waiting_d : std_logic := '0';
signal ui_wr_data_waiting_dd : std_logic := '0';
signal cnt_cmd : integer range 0 to 127 := 0;
signal cnt_cmd_max : integer range 0 to 127 := 0;
signal cnt_wr_skip : integer range 0 to 127 := 0;
signal cnt_rd_skip : integer range 0 to 127 := 0;
signal ui_reset_d : std_logic;
signal ui_reset_dd : std_logic;
signal ui_reset_ddd : std_logic;
signal ui_rd_last_sample_i : std_logic := '0';
signal ui_wr_rdy_i : std_logic := '0';
signal rd_cnt_ini : std_logic := '0';
signal wr_pretrigdsc : unsigned(26 downto 0);
signal wr_framesize : unsigned(26 downto 0);
signal wr_PreTrigSavingCntRecvd : std_logic := '0';


--debug signals
signal debugDDRst : integer range 0 to 4;
signal wrn_data_not_written : std_logic := '0';
signal wrn_data_not_read : std_logic := '0';
signal err_app_rdy_stuck_low : std_logic := '0';

attribute keep: boolean;
attribute mark_debug: boolean;

attribute mark_debug of debugDDRst : signal is true;
attribute mark_debug of app_addr : signal is true;
attribute mark_debug of app_cmd : signal is true;
attribute mark_debug of app_en : signal is true;
attribute mark_debug of app_wdf_data : signal is true;
attribute mark_debug of app_wdf_end : signal is true;
attribute mark_debug of app_wdf_wren : signal is true; 
attribute mark_debug of app_rd_data : signal is true;
attribute mark_debug of app_rd_data_end : signal is true;
attribute mark_debug of app_rd_data_valid_i : signal is true;
attribute mark_debug of app_rdy : signal is true;
attribute mark_debug of app_wdf_rdy : signal is true;
attribute mark_debug of ui_reset : signal is true;
attribute mark_debug of wr_cnt : signal is true;
attribute mark_debug of rd_cnt : signal is true;

attribute keep of app_addr_i_wr : signal is true;
attribute keep of app_addr_i_rd : signal is true;
attribute mark_debug of app_addr_i_wr : signal is true;
attribute mark_debug of app_addr_i_rd : signal is true;
attribute keep of rd_cnt_ini : signal is true;
attribute mark_debug of rd_cnt_ini : signal is true;
attribute mark_debug of wr_pretrigdsc : signal is true;

begin

u_mig_ddr3: mig_ddr3
    port map (
       -- Memory interface ports
       ddr3_addr                      => ddr3_addr,
       ddr3_ba                        => ddr3_ba,
       ddr3_cas_n                     => ddr3_cas_n,
       ddr3_ck_n                      => ddr3_ck_n,
       ddr3_ck_p                      => ddr3_ck_p,
       ddr3_cke                       => ddr3_cke,
       ddr3_ras_n                     => ddr3_ras_n,
       ddr3_reset_n                   => ddr3_reset_n,
       ddr3_we_n                      => ddr3_we_n,
       ddr3_dq                        => ddr3_dq,
       ddr3_dqs_n                     => ddr3_dqs_n,
       ddr3_dqs_p                     => ddr3_dqs_p,
       init_calib_complete            => init_calib_complete,
       ddr3_odt                       => ddr3_odt,
       -- Application interface ports
       app_addr                       => app_addr,
       app_cmd                        => app_cmd,
       app_en                         => app_en,
       app_wdf_data                   => app_wdf_data,
       app_wdf_end                    => app_wdf_end,
       app_wdf_wren                   => app_wdf_wren,
       app_rd_data                    => app_rd_data,
       app_rd_data_end                => app_rd_data_end,
       app_rd_data_valid              => app_rd_data_valid_i,
       app_rdy                        => app_rdy,
       app_wdf_rdy                    => app_wdf_rdy,
       app_sr_req                     => '0',
       app_ref_req                    => '0',
       app_zq_req                     => '0',
       app_sr_active                  => app_sr_active,
       app_ref_ack                    => app_ref_ack,
       app_zq_ack                     => app_zq_ack,
       ui_clk                         => ui_clk_i,
       ui_clk_sync_rst                => ui_clk_sync_rst,
       -- System Clock Ports
       sys_clk_i                      => sys_clk_i,
       clk_ref_i                      => clk_ref_i,
       device_temp                  => device_temp,
       sys_rst                        => '0'
    );

ui_clk <= ui_clk_i;

-- move sample data to app_wdf_data fifo
app_wdf_data <= ui_wr_data;
ui_wr_rdy <= ui_wr_rdy_i;

app_wdf_wren <= app_wdf_wren_i;
app_wdf_end <= app_wdf_end_i;

app_addr_mux: process (ui_clk_i)

begin
    
    if rising_edge(ui_clk_i) then

        ui_reset_d <= ui_reset;

        if ui_clk_sync_rst = '0' then
            
            -- pre-trigger length (selected in GUI)
            -- this is the minimum number of samples to be saved in RAM before we can start waiting for trigger event
            wr_pretriglen <= to_integer(unsigned(ui_wr_pretriglenth));
            -- number of samples that were actually saved in ram before trigger event
            wr_pretrigsaved <= to_integer(unsigned(ui_wr_preTrigSavingCnt));
            if ui_PreTrigSavingCntRecvd = '1' then
                wr_PreTrigSavingCntRecvd <= '1';
            elsif rd_cnt_ini = '1' then
                wr_PreTrigSavingCntRecvd <= '0';
            end if;
            wr_pretrigdsc <= to_unsigned(wr_pretrigsaved-wr_pretriglen,wr_pretrigdsc'length);
            wr_framesize <= unsigned(ui_wr_framesize);
            
            --check for write request
            ui_wr_data_waiting_d <= ui_wr_data_waiting;
            
            --check for read request
            ui_rd_ready_d <= ui_rd_ready;
            
            -- if controller is ready to read data       
            ui_rd_data_valid <= app_rd_data_valid_i; -- read fifo write enable
            ui_rd_data <= app_rd_data;               -- read fifo data
                   
            case RAMstate(2 downto 0) is
            
                when A =>
                    
                    app_en <= '0';
                    app_wdf_wren_i <= '0';
                    app_wdf_end_i <= '0';
                    
                    if ui_reset_d = '0' then
                        -- reset rd and wr counter 
                        --if rd_cnt = wr_cnt then
                        if ui_frameStart = '1' then
                            app_addr_i_wr <= to_unsigned(0,app_addr_i_wr'length);
                            app_addr_i_rd <= to_unsigned(0,app_addr_i_rd'length);
                            wr_cnt <= 0;
                            rd_cnt <= 0;
                            rd_cnt_ini <= '0';
                        end if;
                        -- rd_cnt <= wr_cnt : there is data available to be read from ram                        
                        if rd_cnt = wr_cnt then
                            ui_rd_data_available <= '0';
                        else
                            if rd_cnt_ini = '1' then
                                ui_rd_data_available <= '1';
                            else
                                ui_rd_data_available <= '0';
                            end if;
                        end if;
                        
                        if ui_wr_data_waiting = '1' then
                            app_addr <= '0' & std_logic_vector(app_addr_i_wr);
                            ui_wr_rdy_i <= '0';
                            app_cmd <= "000";
                            RAMstate <= B;
                        -- initialize read address and write counter to account for pre-trigger data
                        elsif wr_PreTrigSavingCntRecvd = '1' and rd_cnt_ini = '0' then
                            -- if current RAM write address is greater than pre-trigger count *2
                            -- then all pre-trigger data is saved in RAM
                            if shift_right(app_addr_i_wr,3) > shift_right(unsigned(ui_wr_preTrigSavingCnt),2) then
                                rd_cnt_ini <= '1';
                                -- set RAM read start address
                                app_addr_i_rd <= wr_pretrigdsc(26 downto 0) & '0'; -- mulitply by 2
                                -- set write counter, relative to the read counter
                                wr_cnt <= to_integer(shift_right(app_addr_i_wr,3) - shift_right(wr_pretrigdsc,2));
                            end if;
                        elsif rd_cnt_ini = '1' and ui_rd_ready_d = '1' and (rd_cnt < wr_cnt) then
                            ui_wr_rdy_i <= '0';
                            app_addr <= '0' & std_logic_vector(app_addr_i_rd(27 downto 3) & "000");
                            app_cmd <= "001";
                            RAMstate <= C;
                        -- wait in idle
                        else
                            ui_wr_rdy_i <= '0';
                            RAMstate <= A;
                        end if;
                    else
                        ui_rd_data_available <= '0';
                        wr_cnt <= 0;
                        rd_cnt <= 0;
                        app_addr_i_rd <= to_unsigned(0,app_addr_i_rd'length);
                        app_addr_i_wr <= to_unsigned(0,app_addr_i_wr'length);
                        --app_addr_i_rd <= 268425448; test memory addr wrap
                        --app_addr_i_wr <= 268425448; test memory addr wrap
                        RAMstate <= A;
                    end if;
                    debugDDRst <= 0;
                
                when B =>          -- writing to RAM
                                        
                    -- select write command
                    app_cmd <= "000";
                    
                    app_wdf_rdy_d <= app_wdf_rdy;
                    
                    if ui_reset_d = '1' then
                        -- restart
                        app_addr_i_wr <= to_unsigned(0,app_addr_i_wr'length);
                        ui_wr_rdy_i <= '0';
                        app_wdf_wren_i <= '0';
                        app_wdf_end_i <= '0';
                        RAMstate <= A;
                    else
                        
                        if ui_wr_data_waiting_d = '1' then
                            -- if controller is ready (app_rdy='1') and there is space in controller fifo (app_wdf_rdy = '1')
                            -- start transfering data from write fifo to controller fifo
                            app_en <= '1';
                            if app_en = '0' and app_rdy = '0' then
                                app_wdf_wren_i <= '1';
                                app_wdf_end_i <= '1';
                                ui_wr_rdy_i <= '1';
                            else                                                 
                                if app_rdy = '1' and app_wdf_rdy = '1' then
                                    app_wdf_wren_i <= '1';
                                    app_wdf_end_i <= '1';
                                    ui_wr_rdy_i <= '1';
                                else
                                    app_wdf_wren_i <= '0';
                                    app_wdf_end_i <= '0';           
                                    ui_wr_rdy_i <= '0';
                                end if;
                            end if;
                            -- if controller is ready (app_rdy='1') and write command was sent (app_en='1')
                            -- incrememnt write address
                            if app_rdy = '1' and app_en = '1' then
                                wr_cnt <= wr_cnt + 1;
                                -- set write address ( Burst Length 8 -> next address is + 8 )
                                if to_integer(unsigned(app_addr)) = (RAM_SIZE*2)-8 then
                                    app_addr <= std_logic_vector(to_unsigned(0,app_addr'LENGTH));
                                    app_addr_i_wr <= to_unsigned(0,app_addr_i_wr'length);
                                else
                                    app_addr <= std_logic_vector(unsigned(app_addr) + 8);
                                    app_addr_i_wr <= unsigned(app_addr(27 downto 0)) + 8;
                                end if;
                            end if;
                            RAMstate <= B;
                        else
                            app_wdf_wren_i <= '0';
                            app_wdf_end_i <= '0';
                            ui_wr_rdy_i <= '0';
                            if app_en = '1' then
                                -- if last write command was accepted
                                if app_rdy = '1' then
                                    wr_cnt <= wr_cnt + 1;
                                    app_en <= '0'; 
                                    if to_integer(unsigned(app_addr)) = (RAM_SIZE*2)-8 then
                                        app_addr <= std_logic_vector(to_unsigned(0,app_addr'LENGTH));
                                        app_addr_i_wr <= to_unsigned(0,app_addr_i_wr'length);
                                    else
                                        app_addr <= std_logic_vector(unsigned(app_addr) + 8);
                                        app_addr_i_wr <= unsigned(app_addr(27 downto 0)) + 8;
                                    end if;
                                    RAMstate <= A;
                                else
                                    -- wait until controller is ready to accept final write command
                                    app_en <= '1';
                                    RAMstate <= B;
                                end if;
                            else
                                RAMstate <= A;
                            end if;
                        end if;           
                       
                    end if;
                    debugDDRst <= 1;
                
                when C =>          -- reading from RAM
                
                    -- select read command
                    app_cmd <= "001";
                    
                    if ui_reset_d = '1' then
                        -- restart
                        app_addr_i_rd <= to_unsigned(0,app_addr_i_rd'length);
                        RAMstate <= A;
                    else
                        -- stay in this state if read read fifo not AlmostFull (ui_rd_ready_d = '1')
                        -- and rd_cnt < wr_cnt-1
                        if ui_rd_ready_d = '1' and rd_cnt < wr_cnt-1 then                        
                            app_en <= '1';
                            -- if controller is ready to receive READ command                        
                            if app_rdy = '1' and app_en = '1' then
                                rd_cnt <= rd_cnt + 1;
                                -- set read address (BL8: next address is current + 8 )
                                if to_integer(unsigned(app_addr)) = (RAM_SIZE*2)-8 then
                                    app_addr <= std_logic_vector(to_unsigned(0,app_addr'LENGTH));
                                else
                                    app_addr <= std_logic_vector(unsigned(app_addr) + 8);
                                end if;
                            end if;
                            RAMstate <= C;
                        else
                            -- if last read command was accepted
                            if app_en = '1' then
                                if app_rdy = '1' then
                                    -- increment read pointer +8
                                    rd_cnt <= rd_cnt + 1;
                                    if to_integer(unsigned(app_addr)) = (RAM_SIZE*2)-8 then
                                        app_addr_i_rd <= to_unsigned(0,app_addr_i_rd'length);
                                    else
                                        app_addr_i_rd <= unsigned(app_addr(27 downto 0)) + 8;
                                    end if;
                                    -- stop reading
                                    app_en <= '0';
                                    RAMstate <= A;
                                else
                                    -- wait until app_rdy = '1'
                                    app_en <= '1';
                                    RAMstate <= C;
                                end if;
                                -- do not increment read pointer
                            else
                                -- if reading last sample, but app_en=0 (read samples one-by-one)
                                if rd_cnt = wr_cnt-1 then
                                    app_en <= '1';
                                    RAMstate <= C;
                                else
                                    app_en <= '0';
                                    RAMstate <= A;
                                end if;
                            end if;
                        end if;
                        
                    end if;
                    debugDDRst <= 2;
                
                when others =>
                
                    RAMstate <= A;
                        
            end case; -- RAMstate
            
         end if; -- ui_clk_sync_rst = '0'
          
    end if; -- rising_edge(ui_clk_i)               
    
end process;

end Behavioral;
