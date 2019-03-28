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
-- Scopefun firmware: FIFO
--

library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity fifo_128_to_32 is
	Generic (
		constant DATA_IN_WIDTH : positive :=  128;
		constant FIFO_DEPTH	   : positive :=  512
	);
	Port (
		clk     : in  STD_LOGIC;
		rst		: in  STD_LOGIC;
		WriteEn	: in  STD_LOGIC;
		DataIn	: in  STD_LOGIC_VECTOR (DATA_IN_WIDTH - 1 downto 0);
		ReadEn	: in  STD_LOGIC;
		DataOut	    : out STD_LOGIC_VECTOR (DATA_IN_WIDTH/4 - 1 downto 0);
		DataOutValid : out STD_LOGIC;
		Empty	    : out STD_LOGIC;
		AlmostEmpty : out STD_LOGIC;
		Full	    : out STD_LOGIC;
		AlmostFull  : out STD_LOGIC
	);
end fifo_128_to_32;

architecture Behavioral of fifo_128_to_32 is

signal DataIn_1 : std_logic_vector(DATA_IN_WIDTH/2 - 1 downto 0);
signal DataIn_2 : std_logic_vector(DATA_IN_WIDTH/2 - 1 downto 0);
signal DataOut_1 : std_logic_vector(DATA_IN_WIDTH/2 - 1 downto 0);
signal DataOut_2 : std_logic_vector(DATA_IN_WIDTH/2 - 1 downto 0);
signal DataOut_2tmp : std_logic_vector(DATA_IN_WIDTH/2 - 1 downto 0);
signal WriteEn_1 : std_logic:='0';
signal WriteEn_2 : std_logic:='0';
signal ReadEn_d : std_logic:='0';
signal ReadEn_1 : std_logic:='0';
signal ReadEn_2 : std_logic:='0';
signal Empty_1 : std_logic:='0';
signal Empty_i : std_logic:='1';
signal rst_i : std_logic:='0';

signal RDCOUNT : std_logic_vector(8 downto 0);
signal WRCOUNT : std_logic_vector(8 downto 0);
signal RDERR : std_logic;
signal WRERR : std_logic; 

signal AlmostEmpty_2 : std_logic;
signal AlmostFull_2 : std_logic;
signal Empty_2 : std_logic;
signal Full_2 : std_logic;

signal RDCOUNT_2 : std_logic_vector(8 downto 0);
signal WRCOUNT_2 : std_logic_vector(8 downto 0);
signal RDERR_2 : std_logic;
signal WRERR_2 : std_logic;

signal out_sample_sel : integer range 0 to 3 := 0;
signal cnt_rst : integer range 0 to 31 := 0;
signal reset : std_logic := '0';
signal read_init : std_logic := '1';
signal r_init_cnt : integer range 0 to 3 := 0;
signal rst_d : std_logic;
signal rst_dd : std_logic;
signal DataOutValid_i : std_logic := '0';

-- attribute strings
attribute KEEP: boolean;
attribute ASYNC_REG: boolean;
-- CDC registers (clock domain crossing signals)
attribute KEEP of rst_d: signal is true;
attribute KEEP of rst_dd: signal is true;
attribute ASYNC_REG of rst_d: signal is true;
attribute ASYNC_REG of rst_dd: signal is true;

attribute mark_debug: boolean;
attribute mark_debug of out_sample_sel : signal is true;
attribute mark_debug of ReadEn : signal is true;
attribute mark_debug of ReadEn_1 : signal is true;
attribute mark_debug of ReadEn_2 : signal is true;
attribute mark_debug of DataIn_1 : signal is true;
attribute mark_debug of WriteEn_1 : signal is true;

begin

   -- FIFO_SYNC_MACRO: Synchronous First-In, First-Out (FIFO) RAM Buffer
   --                  Artix-7
   -- Xilinx HDL Language Template, version 2016.2

   -- Note -  This Unimacro model assumes the port directions to be "downto". 
   --         Simulation of this model with "to" in the port directions could lead to erroneous results.

   -----------------------------------------------------------------
   -- DATA_WIDTH | FIFO_SIZE | FIFO Depth | RDCOUNT/WRCOUNT Width --
   -- ===========|===========|============|=======================--
   --   37-72    |  "36Kb"   |     512    |         9-bit         -- <-- we will use this one
   --   19-36    |  "36Kb"   |    1024    |        10-bit         --
   --   19-36    |  "18Kb"   |     512    |         9-bit         --
   --   10-18    |  "36Kb"   |    2048    |        11-bit         --
   --   10-18    |  "18Kb"   |    1024    |        10-bit         --
   --    5-9     |  "36Kb"   |    4096    |        12-bit         --
   --    5-9     |  "18Kb"   |    2048    |        11-bit         --
   --    1-4     |  "36Kb"   |    8192    |        13-bit         --
   --    1-4     |  "18Kb"   |    4096    |        12-bit         --
   -----------------------------------------------------------------

FIFO_SYNC_MACRO_inst1: FIFO_SYNC_MACRO
   generic map (
      DEVICE => "7SERIES",            -- Target Device: "VIRTEX5, "VIRTEX6", "7SERIES" 
      ALMOST_FULL_OFFSET => X"0100",  -- Sets almost full threshold      100h = 256
      ALMOST_EMPTY_OFFSET => X"0080", -- Sets the almost empty threshold  80h = 128
      DATA_WIDTH => DATA_IN_WIDTH/2,   -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
      FIFO_SIZE => "36Kb")            -- Target BRAM, "18Kb" or "36Kb" 
   port map (
      ALMOSTEMPTY => AlmostEmpty,   -- 1-bit output almost empty
      ALMOSTFULL => AlmostFull,     -- 1-bit output almost full
      DO => DataOut_1,                     -- Output data, width defined by DATA_WIDTH parameter
      EMPTY => Empty_1,               -- 1-bit output empty
      FULL => Full,                 -- 1-bit output full
      RDCOUNT => RDCOUNT,           -- Output read count, width determined by FIFO depth
      RDERR => RDERR,               -- 1-bit output read error
      WRCOUNT => WRCOUNT,           -- Output write count, width determined by FIFO depth
      WRERR => WRERR,               -- 1-bit output write error
      CLK => clk,                   -- 1-bit input clock
      DI => DataIn_1,                     -- Input data, width defined by DATA_WIDTH parameter
      RDEN => ReadEn_1,                 -- 1-bit input read enable
      RST => rst_i,                   -- 1-bit input reset
      WREN => WriteEn_1                  -- 1-bit input write enable
   );

FIFO_SYNC_MACRO_inst2: FIFO_SYNC_MACRO
   generic map (
      DEVICE => "7SERIES",            -- Target Device: "VIRTEX5, "VIRTEX6", "7SERIES" 
      ALMOST_FULL_OFFSET => X"0100",  -- Sets almost full threshold
      ALMOST_EMPTY_OFFSET => X"0080", -- Sets the almost empty threshold
      DATA_WIDTH => DATA_IN_WIDTH/2,   -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
      FIFO_SIZE => "36Kb")            -- Target BRAM, "18Kb" or "36Kb" 
   port map (
      ALMOSTEMPTY => AlmostEmpty_2,   -- 1-bit output almost empty
      ALMOSTFULL => AlmostFull_2,     -- 1-bit output almost full
      DO => DataOut_2,                     -- Output data, width defined by DATA_WIDTH parameter
      EMPTY => Empty_2,               -- 1-bit output empty
      FULL => Full_2,                 -- 1-bit output full
      RDCOUNT => RDCOUNT_2,           -- Output read count, width determined by FIFO depth
      RDERR => RDERR_2,               -- 1-bit output read error
      WRCOUNT => WRCOUNT_2,           -- Output write count, width determined by FIFO depth
      WRERR => WRERR_2,               -- 1-bit output write error
      CLK => clk,                   -- 1-bit input clock
      DI => DataIn_2,                     -- Input data, width defined by DATA_WIDTH parameter
      RDEN => ReadEn_2,                 -- 1-bit input read enable
      RST => rst_i,                   -- 1-bit input reset
      WREN => WriteEn_2                  -- 1-bit input write enable
   );
   -- End of FIFO_SYNC_MACRO_inst instantiation

DataOutValid <= DataOutValid_i;
Empty <= Empty_i;

-- FIFO Process
fifo_proc: process (clk)
    
	begin
		if rising_edge(clk) then
		
		    -- connect in data
            DataIn_1 <= DataIn(127 downto 64);
            DataIn_2 <= DataIn( 63 downto  0);
            
            ReadEn_d <= ReadEn;
            
		    --RST must be held high for at least five WRCLK/RDCLK clock cycles
            -- and WREN/RDCLK must be low before RST becomes active high
            -- and WREN/RDCLK remains low during this reset cycle
            --WREN must be low for at least two WRCLK clock cycles after RST deasserted
            rst_d <= rst;
            rst_dd <= rst_d;
            if rst_dd = '0' and rst_d = '1' then
                reset <= '1';
            end if;
            if reset = '1' then
                read_init <= '1';
                Empty_i <= Empty_2;
                out_sample_sel <= 0;
                r_init_cnt <= 0;
                DataOutValid_i <= '0';
                WriteEn_1 <= '0';
                WriteEn_2 <= '0';
                ReadEn_1 <= '0';
                ReadEn_2 <= '0';
                if cnt_rst = 0 then
                    rst_i <= '0';
                    cnt_rst <= cnt_rst + 1;
                elsif cnt_rst = 1 then
                    rst_i <= '1';
                    cnt_rst <= cnt_rst + 1;
                elsif cnt_rst = 18 then
                    if rst_d = '1' then
                        rst_i <= '1';
                        cnt_rst <= 18;
                    else
                        rst_i <= '0';
                        cnt_rst <= cnt_rst + 1;
                    end if;
                elsif cnt_rst = 25 then
                    reset <= '0';
                    cnt_rst <= 0;
                else
                    reset <= '1';
                    cnt_rst <= cnt_rst + 1;
                end if;
--            elsif reset = '0' and (WriteEn = '1' or ReadEn = '1') then
            else
                rst_i <= '0';
                WriteEn_1 <= WriteEn;
                WriteEn_2 <= WriteEn;
                               
                -- "preload"  DataOut_1 and DataOut_2 with samples
                -- (each DataOut register will contain 2 samples after init)
                If read_init = '1' and (Empty_2 = '0' or Empty_i = '0') then
                    Empty_i <= '0';
                    DataOutValid_i <= '0';
                    if r_init_cnt = 0 then
                        read_init <= '1';
                        r_init_cnt <= 1;
                        ReadEn_1 <= '1';
                        ReadEn_2 <= '1';                    
                    else
                        read_init <= '0';
                        r_init_cnt <= 0;
                        ReadEn_1 <= '0';
                        ReadEn_2 <= '0';   
                    end if;
                -- continue reading samples after read_init if read is requested
                elsif Empty_i = '0' and ReadEn_d = '1' then
         		    DataOutValid_i <= '1';
         		    -- delay Empty flag until final 4 samples are read
         		    -- so that data will be valid until last sample
            		if Empty_2 = '1' and out_sample_sel = 3 then
                         Empty_i <= '1';
                         read_init <= '1';  --reset read init
                     else
                         Empty_i <= '0';
                         read_init <= '0';
                     end if;
                    -- connect data out to fifo out registers
            		case out_sample_sel is
         				when 0 =>
                            ReadEn_1 <= '0';
                            ReadEn_2 <= '0';
         					DataOut <= DataOut_1(63 downto 32);
         					out_sample_sel <= 1;
         				when 1 =>
                            ReadEn_1 <= '0';
                            ReadEn_2 <= '0';
         					DataOut <= DataOut_1(31 downto 0);
         					out_sample_sel <= 2;
                        when 2 =>
                            -- special case, if read was aborted when out_sample_sel = 2
                            if ReadEn = '0' then
                                ReadEn_1 <= '0';
                                ReadEn_2 <= '0';
                            else
                                ReadEn_1 <= '1';
                                ReadEn_2 <= '1';
                            end if;
                            DataOut <= DataOut_2(63 downto 32);
                            out_sample_sel <= 3;
                        when 3 =>
                            ReadEn_1 <= '0';
                            ReadEn_2 <= '0';                             
                            DataOut <= DataOut_2(31 downto 0);
                            out_sample_sel <= 0;
         				when others =>
         					null;                  
         			end case;
         	    -- special case, if read was aborted when out_sample_sel = 2
         	    -- ReadEn must be asserted just before read re-start
         	    elsif Empty_2 = '0' and ReadEn_d = '0' and ReadEn = '1' and out_sample_sel = 3 then
         	        Empty_i <= '0';
         	        DataOutValid_i <= '0';
         	        ReadEn_1 <= '1';
                    ReadEn_2 <= '1';
         	    else
--         	        Empty_i <= Empty_2;
         	        DataOutValid_i <= '0';
                    ReadEn_1 <= '0';
                    ReadEn_2 <= '0';
     		    end if;
            end if;
		end if;
	end process;
		
end Behavioral;