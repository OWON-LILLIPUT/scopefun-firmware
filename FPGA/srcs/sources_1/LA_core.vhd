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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity LA_core is
    generic (
        LA_DATA_WIDTH : integer := 12;    -- Data input width
        LA_COUNTER_WIDTH : integer := 16 -- Stage Counter width
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
           dt_delayMaxcnt_0 : in std_logic_vector (LA_COUNTER_WIDTH-1 downto 0);
           dt_delayMaxcnt_1 : in std_logic_vector (LA_COUNTER_WIDTH-1 downto 0);
           dt_delayMaxcnt_2 : in std_logic_vector (LA_COUNTER_WIDTH-1 downto 0);
           dt_delayMaxcnt_3 : in std_logic_vector (LA_COUNTER_WIDTH-1 downto 0);
           dtSerial : in std_logic;
           dtSerialCh : in std_logic_vector (3 downto 0);
           dt_triggered : out std_logic;
           reset : in std_logic);
end LA_core;

architecture Behavioral of LA_core is

constant STAGE_CNT : integer := 4;

-- Logic analyzer state machine signals
signal LAstate : std_logic_vector (2 downto 0) := "000";
CONSTANT A: STD_LOGIC_VECTOR (2 DownTo 0) := "000";
CONSTANT B: STD_LOGIC_VECTOR (2 DownTo 0) := "001";
CONSTANT C: STD_LOGIC_VECTOR (2 DownTo 0) := "010";
CONSTANT D: STD_LOGIC_VECTOR (2 DownTo 0) := "011";
CONSTANT E: STD_LOGIC_VECTOR (2 DownTo 0) := "100";
CONSTANT F: STD_LOGIC_VECTOR (2 DownTo 0) := "101";

-- logic analyzer data input      
signal dataDd : std_logic_vector (LA_DATA_WIDTH-1 downto 0);
signal dataDdd : std_logic_vector (LA_DATA_WIDTH-1 downto 0);
signal dataDTrigSignal : std_logic_vector (LA_DATA_WIDTH-1 downto 0);
signal dataDTrigSignal_d : std_logic_vector (LA_DATA_WIDTH-1 downto 0);

-- logic analyzer core signals
signal dt_enable_d : std_logic;
signal dt_enable_dd : std_logic;
type trig_patternA_mem_d is array(0 to STAGE_CNT-1) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal digital_trig_patternA_d : trig_patternA_mem_d:=((others=> (others=>'0')));
type trig_patternB_mem_d is array(0 to STAGE_CNT-1) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal digital_trig_patternB_d : trig_patternB_mem_d:=((others=> (others=>'0')));
type digital_trig_mask_mem_d is array(0 to STAGE_CNT-1) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal digital_trig_mask_d : digital_trig_mask_mem_d:=((others=> (others=>'0')));
type digital_trig_mask_mem_dd is array(0 to STAGE_CNT-1) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal digital_trig_mask_dd : digital_trig_mask_mem_dd:=((others=> (others=>'0')));
signal dt_stage : integer range 0 to STAGE_CNT-1 := 0;
signal dt_stage_capture_d : integer range 0 to STAGE_CNT-1;
type dt_delayMaxcntIs0_mem is array(0 to STAGE_CNT-1) of Boolean;
signal dt_delayMaxcntIs0 : dt_delayMaxcntIs0_mem:= (others=>True);
type dt_delaycnt_mem is array(0 to STAGE_CNT-1) of unsigned (LA_COUNTER_WIDTH-1 downto 0);
signal dt_delaycnt : dt_delaycnt_mem:=((others=> (others=>'0')));
type dt_delayMaxcnt_mem is array(0 to STAGE_CNT-1) of unsigned (LA_COUNTER_WIDTH-1 downto 0);
signal dt_delayMaxcnt : dt_delayMaxcnt_mem :=((others=> (others=>'0')));
type dt_delayMaxcnt_d_mem is array(0 to STAGE_CNT-1) of unsigned (LA_COUNTER_WIDTH-1 downto 0);
signal dt_delayMaxcnt_d : dt_delayMaxcnt_d_mem :=((others=> (others=>'0')));
signal dtSerial_d : std_logic;
signal dtSerialCh_d : integer range 0 to LA_DATA_WIDTH-1;
type dt_edge_trigger_mem is array(0 to STAGE_CNT-1) of std_logic;
signal dt_edge_trigger : dt_edge_trigger_mem := (others=> '0');
signal triggered : std_logic := '0';
signal LAstate_debug : integer range 0 to 7 := 0;
type xnor1tmp_mem is array(0 to STAGE_CNT-1) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal xnor1tmp : xnor1tmp_mem:=((others=> (others=>'0')));
type xnor2tmp_mem is array(0 to STAGE_CNT-1) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal xnor2tmp : xnor2tmp_mem:=((others=> (others=>'0')));
signal partial : STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);

-- attribute strings
attribute KEEP: boolean;
attribute ASYNC_REG: boolean;
attribute mark_debug: boolean;

-- apply attributes
attribute KEEP of dataDd: signal is true;
attribute ASYNC_REG of dataDd: signal is true;
attribute KEEP of dataDdd: signal is true;
attribute ASYNC_REG of dataDdd: signal is true;

attribute KEEP of LAstate_debug: signal is true;
attribute mark_debug of LAstate_debug: signal is true;

--attribute KEEP of : signal is true;
--attribute mark_debug of : signal is true;

begin

logic_analyzer: process(clk_in)

begin

    if (rising_edge(clk_in)) then
        
        dt_enable_d <= dt_enable;
        dt_enable_dd <= dt_enable_d;
        --digital trigger signal setup      
        dataDd <= dataD;
        dataDdd <= dataDd;
        
        dtSerialCh_d <= to_integer(unsigned(dtSerialCh));
        if dtSerial_d = '0' then
            dataDTrigSignal <= dataDdd;
        else
            dataDTrigSignal(0) <= dataDdd(dtSerialCh_d);
            for n in 0 to LA_DATA_WIDTH-2 loop
                dataDTrigSignal(n+1) <= dataDTrigSignal(n); 
            end loop;
        end if;
        dataDTrigSignal_d <= dataDTrigSignal;
        
        dt_triggered <= triggered;
                         
        dt_stage_capture_d <= to_integer(unsigned(dt_stage_capture));      
        dtSerial_d <= dtSerial;
        dt_delaycnt(0) <= to_unsigned(0,LA_COUNTER_WIDTH);
        dt_delaycnt(1) <= to_unsigned(0,LA_COUNTER_WIDTH);
        dt_delaycnt(2) <= to_unsigned(0,LA_COUNTER_WIDTH);
        dt_delaycnt(3) <= to_unsigned(0,LA_COUNTER_WIDTH);
        digital_trig_patternA_d(0) <= digital_trig_patternA_0;
        digital_trig_patternA_d(1) <= digital_trig_patternA_1;
        digital_trig_patternA_d(2) <= digital_trig_patternA_2;
        digital_trig_patternA_d(3) <= digital_trig_patternA_3;
        digital_trig_patternB_d(0) <= digital_trig_patternB_0;
        digital_trig_patternB_d(1) <= digital_trig_patternB_1;
        digital_trig_patternB_d(2) <= digital_trig_patternB_2;
        digital_trig_patternB_d(3) <= digital_trig_patternB_3;
        digital_trig_mask_d(0) <= digital_trig_mask_0;     
        digital_trig_mask_d(1) <= digital_trig_mask_1; 
        digital_trig_mask_d(2) <= digital_trig_mask_2;
        digital_trig_mask_d(3) <= digital_trig_mask_3;
        dt_delayMaxcnt_d(0) <= unsigned(dt_delayMaxcnt_0);
        dt_delayMaxcnt_d(1) <= unsigned(dt_delayMaxcnt_1);
        dt_delayMaxcnt_d(2) <= unsigned(dt_delayMaxcnt_2);
        dt_delayMaxcnt_d(3) <= unsigned(dt_delayMaxcnt_3);
        
        if dt_enable_d = '1' then
            for k in 0 to STAGE_CNT-1 loop
                xnor1tmp(k) <= (dataDTrigSignal_d XNOR digital_trig_patternA_d(k)) AND digital_trig_mask_d(k);
                xnor2tmp(k) <= (dataDTrigSignal   XNOR digital_trig_patternB_d(k)) AND digital_trig_mask_d(k);
            end loop;
        end if; 
        
        case LAstate(2 downto 0) is
            
            when A =>   -- "IDLE"
         
                dt_stage <= 0;
                
                for i in 0 to STAGE_CNT-1 loop
                    --check if digital trigger is edge or level
                    if digital_trig_patternA_d(i) /= digital_trig_patternB_d(i) then
                        dt_edge_trigger(i) <= '1';
                    else
                        dt_edge_trigger(i) <= '0';
                    end if;
                   --check if digital counters are set to zero
                    if dt_delayMaxcnt_d(i) = 0 then
                        dt_delayMaxcntIs0(i) <= True;
                    else
                        dt_delayMaxcntIs0(i) <= False;
                    end if;
                end loop;
                
                -- if external (digital) trigger has been enabled
                if dt_enable_dd = '0' and dt_enable_d = '1' then
                    LAstate <= B;
                else
                    LAstate <= A;
                end if;
                LAstate_debug <= 0;
                
            when B =>   -- "Wait for stage pattern match"
                
                if reset = '1' then 
                    LAstate <= A;  
                             
                else
                                  
                    for k in 0 to STAGE_CNT-1 loop
                        if dt_stage = k then
                            if ( xnor1tmp(k) AND xnor2tmp(k) ) = digital_trig_mask_d(k) then
                                LAstate <= C;
                            else
                                LAstate <= B;   
                            end if;  
                        end if;
                    end loop;
                    
                end if;
                LAstate_debug <= 1;
                
             when C =>  -- count the counter or not?
             
                if reset = '1' then 
                    LAstate <= A;
                             
                else
                    for i in 0 to STAGE_CNT-1 loop
                        if dt_stage = i then
                            -- if counter for the current stage is set to zero 
                            if dt_delayMaxcntIs0(i) = True then
                                if i < STAGE_CNT-1 then 
                                    dt_stage <= dt_stage + 1;
                                end if;
                                -- if the current stage is final
                                if dt_stage >= dt_stage_capture_d then
                                    LAstate <= E;
                                else
                                    LAstate <= B;
                                end if;
                           -- if counter for the current stage is NOT set to zero
                           elsif dt_delayMaxcntIs0(i) = False then
                                LAstate <= D; -- go to counter
                           end if;
                        end if;
                    end loop;   
                end if;
                LAstate_debug <= 2;
                     
             when D =>  -- counter
                
                -- count the delay counter
                if reset = '1' then 
                    LAstate <= A;
                
                else
                    for j in 0 to STAGE_CNT-1 loop
                        if dt_stage = j then
                            if dt_delaycnt(j) = dt_delayMaxcnt_d(j) then
                                if j < STAGE_CNT-1 then 
                                    dt_stage <= dt_stage + 1;
                                end if;
                                -- if the current stage is final
                                if dt_stage >= dt_stage_capture_d then
                                    LAstate <= E;
                                else
                                    LAstate <= B;
                                end if;
                            else
                                dt_delaycnt(j) <= dt_delaycnt(j) + 1;
                                LAstate <= D;
                            end if;
                        end if;
                    end loop;
                end if;
                LAstate_debug <= 3;
                         
             when E =>  -- send trigger indication
                
                if reset = '1' then
                    LAstate <= A;
                    
                -- wait until triggered indicator received by core (dt_enable_d will transition from '1' to '0')
                elsif dt_enable_dd = '1' and dt_enable_d = '0' then
                    triggered <= '0';
                    LAstate <= A;
                else
                    triggered <= '1'; -- trigger signal asserted
                    LAstate <= E;
                end if;
                LAstate_debug <= 4;
          
             when others =>
                
                LAstate <= A;
                LAstate_debug <= 5;

        end case;
        
    end if;

end process;

end Behavioral;
