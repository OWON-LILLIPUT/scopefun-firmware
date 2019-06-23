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

entity fifo_32_to_128 is
	Generic (
		constant DATA_IN_WIDTH : positive :=   32;
		constant FIFO_DEPTH	   : positive :=  512
	);
	Port ( 
		clk_wr  : in  STD_LOGIC;
		clk_rd  : in STD_LOGIC;
		rst		: in  STD_LOGIC;
		WriteEn	: in  STD_LOGIC;
		DataIn	: in  STD_LOGIC_VECTOR (DATA_IN_WIDTH - 1 downto 0);
		ReadEn	: in  STD_LOGIC;
		DataOut	: out STD_LOGIC_VECTOR (DATA_IN_WIDTH*4 - 1 downto 0);
		Empty	: out STD_LOGIC;
		AlmostEmpty : out STD_LOGIC;
		Full	: out STD_LOGIC;
		AlmostFull : out STD_LOGIC
	);
end fifo_32_to_128;

architecture Behavioral of fifo_32_to_128 is

signal DataIn_1 : std_logic_vector(DATA_IN_WIDTH*2 - 1 downto 0);
signal DataIn_2 : std_logic_vector(DATA_IN_WIDTH*2 - 1 downto 0);
signal DataOut_1 : std_logic_vector(DATA_IN_WIDTH*2 - 1 downto 0);
signal DataOut_2 : std_logic_vector(DATA_IN_WIDTH*2 - 1 downto 0);
signal WriteEn_1 : std_logic:='0';
signal WriteEn_2 : std_logic:='0';
signal ReadEn_i : std_logic:='0';
signal rst_i : std_logic:='0';

signal RDCOUNT : std_logic_vector(8 downto 0);
signal WRCOUNT : std_logic_vector(8 downto 0);
signal RDERR : std_logic;
signal WRERR : std_logic; 

signal AlmostEmpty_2 : std_logic;
signal AlmostFull_2 : std_logic;
signal Full_2 : std_logic;
signal Empty_1 : std_logic;
signal Empty_2 : std_logic;

signal RDCOUNT_2 : std_logic_vector(8 downto 0);
signal WRCOUNT_2 : std_logic_vector(8 downto 0);
signal RDERR_2 : std_logic;
signal WRERR_2 : std_logic;

signal in_pkt_sel : integer range 0 to 3 := 0;
signal cnt_rst : integer range 0 to 31 := 0;
signal reset : std_logic := '0';

signal reset_d : std_logic;
signal reset_dd : std_logic;
signal rst_d : std_logic;

-- attribute strings
attribute KEEP: boolean;
attribute ASYNC_REG: boolean;
-- CDC registers (clock domain crossing signals)
attribute KEEP of reset: signal is true;
attribute KEEP of reset_d: signal is true;
attribute KEEP of reset_dd: signal is true;
attribute ASYNC_REG of reset_d: signal is true;
attribute ASYNC_REG of reset_dd: signal is true;

attribute KEEP of rst: signal is true;
attribute KEEP of rst_d: signal is true;
attribute ASYNC_REG of rst_d: signal is true;

attribute mark_debug: boolean;
attribute mark_debug of in_pkt_sel : signal is true;

begin



   -- FIFO_DUALCLOCK_MACRO: Dual-Clock First-In, First-Out (FIFO) RAM Buffer
   --                       Artix-7
   -- Xilinx HDL Language Template, version 2016.3

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

FIFO_DUALCLOCK_MACRO_inst1: FIFO_DUALCLOCK_MACRO
   generic map (
      DEVICE => "7SERIES",            -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES" 
      ALMOST_FULL_OFFSET => X"0101",  -- Sets almost full threshold
      ALMOST_EMPTY_OFFSET => X"0006", -- Sets the almost empty threshold
      DATA_WIDTH => DATA_IN_WIDTH*2,   -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
      FIFO_SIZE => "36Kb",            -- Target BRAM, "18Kb" or "36Kb" 
      FIRST_WORD_FALL_THROUGH => TRUE) -- Sets the FIFO FWFT to TRUE or FALSE
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
      DI => DataIn_1,                     -- Input data, width defined by DATA_WIDTH parameter
      RDCLK => clk_rd,               -- 1-bit input read clock
      RDEN => ReadEn_i,                 -- 1-bit input read enable
      RST => rst_i,                   -- 1-bit input reset
      WRCLK => clk_wr,               -- 1-bit input write clock
      WREN => WriteEn_1                  -- 1-bit input write enable
   );
   
FIFO_DUALCLOCK_MACRO_inst2: FIFO_DUALCLOCK_MACRO
   generic map (
      DEVICE => "7SERIES",            -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES" 
      ALMOST_FULL_OFFSET => X"0101",  -- Sets almost full threshold
      ALMOST_EMPTY_OFFSET => X"0006", -- Sets the almost empty threshold
      DATA_WIDTH => DATA_IN_WIDTH*2,   -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
      FIFO_SIZE => "36Kb",            -- Target BRAM, "18Kb" or "36Kb" 
      FIRST_WORD_FALL_THROUGH => TRUE) -- Sets the FIFO FWFT to TRUE or FALSE
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
      DI => DataIn_2,                     -- Input data, width defined by DATA_WIDTH parameter
      RDCLK => clk_rd,               -- 1-bit input read clock
      RDEN => ReadEn_i,                 -- 1-bit input read enable
      RST => rst_i,                   -- 1-bit input reset
      WRCLK => clk_wr,               -- 1-bit input write clock
      WREN => WriteEn_2                  -- 1-bit input write enable
   );
   -- End of FIFO_DUALCLOCK_MACRO_inst instantiation

-- connect out data
DataOut (127 downto 64) <= DataOut_1;
DataOut ( 63 downto  0) <= DataOut_2; 

Empty <= Empty_1 or Empty_2;

ReadEn_i <= ReadEn and not(reset);

-- FIFO Process
fifo_proc: process (clk_wr)

	begin
		if rising_edge(clk_wr) then
		
    	    --RST must be held high for at least five WRCLK/RDCLK clock cycles
            -- and WREN/RDCLK must be low before RST becomes active high
            -- and WREN/RDCLK remains low during this reset cycle
            --WREN must be low for at least two WRCLK clock cycles after RST deasserted
            
            -- note: RST does not clear memory data!
            rst_d <= rst;
            if rst_d = '0' and rst = '1' then
                reset <= '1';
            end if;
            if reset = '1' then
                in_pkt_sel <= 0;
                WriteEn_1 <= '0';
                WriteEn_2 <= '0';
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
            else
                rst_i <= '0';
                --connect in data
                if WriteEn = '1' then
            		case in_pkt_sel is
         				when 0 =>
         					in_pkt_sel <= 1;
         					DataIn_1(63 downto 32) <= DataIn;
         					WriteEn_1 <= '0';
         					WriteEn_2 <= '0';  					
         				when 1 =>
         					in_pkt_sel <= 2;
         					DataIn_1(31 downto 0) <= DataIn;
         					WriteEn_1 <= '1';
         					WriteEn_2 <= '0';
         			    when 2 =>
                            in_pkt_sel <= 3;
                            DataIn_2(63 downto 32) <= DataIn;
                            WriteEn_1 <= '0';
                            WriteEn_2 <= '0';                     
                        when 3 =>
                            in_pkt_sel <= 0;
                            DataIn_2(31 downto 0) <= DataIn;
                            WriteEn_1 <= '0';
                            WriteEn_2 <= '1';
         				when others =>
         					null;                       
         			end case;
         	    else 
                    WriteEn_1 <= '0';
         	        WriteEn_2 <= '0';
     			end if;
            end if;
		end if;
end process;
		
--rd_proc: process (clk_rd)
    
--    begin
--        if rising_edge(clk_rd) then
            
--            --ASYNC_REG
--            reset_d <= reset;
--            reset_dd <= reset_d;
            
--            if reset_dd = '1' then
--                ReadEn_i <= '0';
--            else    
--                ReadEn_i <= ReadEn;
--            end if;    
                
--        end if;
    
--end process;		

end Behavioral;