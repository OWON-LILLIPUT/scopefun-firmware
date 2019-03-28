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

-- Logic analyzer state machine signals
signal LAstate : std_logic_vector (2 downto 0);
CONSTANT A: STD_LOGIC_VECTOR (2 DownTo 0) := "000";
CONSTANT B: STD_LOGIC_VECTOR (2 DownTo 0) := "001";
CONSTANT C: STD_LOGIC_VECTOR (2 DownTo 0) := "010";
CONSTANT D: STD_LOGIC_VECTOR (2 DownTo 0) := "011";
CONSTANT E: STD_LOGIC_VECTOR (2 DownTo 0) := "100";
CONSTANT F: STD_LOGIC_VECTOR (2 DownTo 0) := "101";

-- logic analyzer data input      
signal dataDd : std_logic_vector (LA_DATA_WIDTH-1 downto 0);
signal dataDdd : std_logic_vector (LA_DATA_WIDTH-1 downto 0);
signal dataDddd : std_logic_vector (LA_DATA_WIDTH-1 downto 0);
signal dataDTrigSignal : std_logic_vector (LA_DATA_WIDTH-1 downto 0);
signal dataDTrigSignal_d : std_logic_vector (LA_DATA_WIDTH-1 downto 0);
signal dataDTrigSignal_dd : std_logic_vector (LA_DATA_WIDTH-1 downto 0);

-- logic analyzer core signals
signal dt_enable_d : std_logic;
type trig_patternA_mem_d is array(0 to 3) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal digital_trig_patternA_d : trig_patternA_mem_d:=((others=> (others=>'0')));
type trig_patternB_mem_d is array(0 to 3) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal digital_trig_patternB_d : trig_patternB_mem_d:=((others=> (others=>'0')));
type digital_trig_mask_mem_d is array(0 to 3) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal digital_trig_mask_d : digital_trig_mask_mem_d:=((others=> (others=>'0')));
type digital_trig_mask_mem_c is array(0 to 3) of STD_LOGIC_VECTOR (LA_DATA_WIDTH-1 downto 0);
signal digital_trig_mask_c : digital_trig_mask_mem_c:=((others=> (others=>'0')));
signal dt_stage : integer range 0 to 3 := 0;
signal dt_stage_capture_d : integer range 0 to 3;
signal dt_delaycnt : unsigned (LA_COUNTER_WIDTH-1 downto 0);
type dt_delayMaxcnt_mem is array(0 to 3) of unsigned (LA_COUNTER_WIDTH-1 downto 0);
signal dt_delayMaxcnt : dt_delayMaxcnt_mem :=((others=> (others=>'0')));
type dt_delayMaxcnt_d_mem is array(0 to 3) of unsigned (LA_COUNTER_WIDTH-1 downto 0);
signal dt_delayMaxcnt_d : dt_delayMaxcnt_d_mem :=((others=> (others=>'0')));
signal dtSerial_d : std_logic;
signal dtSerialCh_d : integer range 0 to LA_DATA_WIDTH-1;
type dt_edge_trigger_mem is array(0 to 3) of std_logic;
signal dt_edge_trigger : dt_edge_trigger_mem := (others=> '0');
signal triggered : std_logic;

-- attribute strings
attribute KEEP: boolean;
attribute ASYNC_REG: boolean;
-- apply attributes
attribute KEEP of dataDd: signal is true;
attribute ASYNC_REG of dataDd: signal is true;
attribute KEEP of dataDdd: signal is true;
attribute ASYNC_REG of dataDdd: signal is true;

begin

logic_analyzer: process(clk_in)

begin

    if (rising_edge(clk_in)) then
        
        dt_enable_d <= dt_enable;
        --digital trigger signal setup      
        dataDd <= dataD;
        dataDdd <= dataDd;
        dataDddd <= dataDdd;
        if dtSerial_d = '0' then
            dataDTrigSignal <= dataDddd;
        else
            dataDTrigSignal(0) <= dataDddd(dtSerialCh_d);
            for i in 0 to LA_DATA_WIDTH-2 loop
                dataDTrigSignal(i+1) <= dataDTrigSignal(i); 
            end loop;
        end if;
        dataDTrigSignal_d <= dataDTrigSignal;
        dataDTrigSignal_dd <= dataDTrigSignal_d;
        
        dt_triggered <= triggered;
        
        case LAstate(2 downto 0) is
            
            when A =>   -- "IDLE"
                 
                triggered <= '0'; 
                dt_stage <= 0;
                dt_delaycnt <= to_unsigned(0,LA_COUNTER_WIDTH);
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
                digital_trig_mask_c(0) <= digital_trig_mask_0;     
                digital_trig_mask_c(1) <= digital_trig_mask_1; 
                digital_trig_mask_c(2) <= digital_trig_mask_2;
                digital_trig_mask_c(3) <= digital_trig_mask_3;
                dt_delayMaxcnt_d(0) <= unsigned(dt_delayMaxcnt_0);
                dt_delayMaxcnt_d(1) <= unsigned(dt_delayMaxcnt_1);
                dt_delayMaxcnt_d(2) <= unsigned(dt_delayMaxcnt_2);
                dt_delayMaxcnt_d(3) <= unsigned(dt_delayMaxcnt_3);
                dt_stage_capture_d <= to_integer(unsigned(dt_stage_capture));
                dtSerial_d <= dtSerial;
                dtSerialCh_d <= to_integer(unsigned(dtSerialCh));
                
                --check if digital trigger is edge or level
                for i in 0 to 3 loop
                    if digital_trig_patternA_d(i) /= digital_trig_patternB_d(i) then
                        dt_edge_trigger(i) <= '1';
                    else
                        dt_edge_trigger(i) <= '0';
                    end if;
                end loop;
                
                -- if external trigger has been enabled
                if dt_enable = '1' and dt_enable_d = '0' then
                    LAstate <= B;
                else
                    LAstate <= A;
                end if;
            
            when B =>   -- "Wait for stage pattern match"
                
                if reset = '1' then 
                    LAstate <= A;           
                else
                    if (dt_edge_trigger(dt_stage) = '1' ) then
--                        if
--                        ( (dataDTrigSignal_dd XNOR digital_trig_patternA_d(dt_stage)) AND
--                        ( dataDTrigSignal_d   XNOR digital_trig_patternB_d(dt_stage)) AND
--                        digital_trig_mask_d(dt_stage) ) = digital_trig_mask_c(dt_stage)
--                        then
--                            LAstate <= D;
--                        else
--                            LAstate <= B;   
--                        end if;
                    else
                        if
                        ( (dataDTrigSignal_dd XNOR digital_trig_patternA_d(dt_stage)) AND
                         digital_trig_mask_d(dt_stage) ) = digital_trig_mask_c(dt_stage)
                        then
                            LAstate <= D;
                        else
                            LAstate <= B;  
                        end if;
                    end if;
                end if;
            
--            when C =>   -- "Check stage counter match"         
            
--                if reset = '1' then 
--                    LAstate <= A;
                    
--                else
--                    -- if delay counter for the current stage is set to 0     
--                    if dt_delayMaxcnt_d(dt_stage) = 0 then
--                        -- if the current stage is the one to start capturing
--                        if dt_stage_capture_d = dt_stage then
--                            LAstate <= E;
--                        else
--                            dt_stage <= dt_stage + 1;
--                            LAstate <= B;
--                        end if;
--                    else
--                        -- go to count the counter if it is not 0
--                        LAstate <= D;
--                    end if;
                
--                end if;
                
             when D =>  -- count the counter
             
                if reset = '1' then 
                    LAstate <= A;
                             
                elsif dt_delaycnt = dt_delayMaxcnt_d(dt_stage) then
                -- if the current stage is the one to start saving samples
                    if dt_stage_capture_d = dt_stage then
                        LAstate <= E;
                    else
                    -- return to trigger detection for the next stage
                        dt_stage <= dt_stage + 1;
                        LAstate <= B; -- return to trigger detection
                        dt_delaycnt <= to_unsigned(0,LA_COUNTER_WIDTH);
                    end if;
                else
                -- count the delay counter
                    dt_delaycnt <= dt_delaycnt + 1;
                    LAstate <= D;
                end if;                
             when E =>
                
                triggered <= '1'; -- assert capture signal
                LAstate <= A;      
                  
             when others =>
                
                LAstate <= A;

        end case;
        
    end if;

end process;

end Behavioral;
