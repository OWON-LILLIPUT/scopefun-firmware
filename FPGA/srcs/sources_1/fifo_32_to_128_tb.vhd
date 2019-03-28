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
-- Scopefun firmware: FIFO testbench
--

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY fifo_32_to_128_tb IS
END fifo_32_to_128_tb;

ARCHITECTURE behavior OF fifo_32_to_128_tb IS 
	
	-- Component Declaration for the Unit Under Test (UUT)
	component fifo_32_to_128
		Generic (
		  constant DATA_IN_WIDTH : positive :=   32;
          constant FIFO_DEPTH    : positive :=  512
		);
		port (
		  clk_wr     : in STD_LOGIC;
		  clk_rd     : in std_logic;
          rst        : in STD_LOGIC;
          WriteEn    : in STD_LOGIC;
          DataIn    : in  STD_LOGIC_VECTOR (DATA_IN_WIDTH - 1 downto 0);
          ReadEn    : in  STD_LOGIC;
          DataOut    : out STD_LOGIC_VECTOR (DATA_IN_WIDTH*4 - 1 downto 0);
          Empty    : out STD_LOGIC;
          AlmostEmpty : out STD_LOGIC;
          Full    : out STD_LOGIC;
          AlmostFull : out STD_LOGIC
		);
	end component;

	constant DATA_IN_WIDTH : integer := 32;
	constant FIFO_DEPTH	: integer := 512;

	--Inputs
	signal clk_wr   : std_logic := '0';
	signal clk_rd   : std_logic := '0';
	signal rst		: std_logic := '0';
	signal DataIn	: std_logic_vector(DATA_IN_WIDTH -1 downto 0) := (others => '0');
	signal ReadEn	: std_logic := '0';
	signal WriteEn	: std_logic := '0';
	
	--Outputs
	signal DataOut	: std_logic_vector(DATA_IN_WIDTH*4 - 1 downto 0);
	signal Empty	: std_logic;
	signal Full		: std_logic;
	signal AlmostEmpty	: std_logic;
    signal AlmostFull   : std_logic;
	
	-- Clock period definitions
	constant clk_wr_period : time := 10 ns;
	constant clk_rd_period : time := 20 ns;
	
	-- internal
	signal InputValid : std_logic := '0';
    signal AlmostEmpty_d : std_logic := '0';
	signal AlmostFull_d : std_logic := '0';
    signal writing_frame : std_logic := '0';
    
BEGIN

	-- Instantiate the Unit Under Test (UUT)
	uut: fifo_32_to_128
		PORT MAP (
			clk_wr		 => clk_wr,
			clk_rd       => clk_rd,
			RST		     => RST,
			DataIn	     => DataIn,
			WriteEn	     => WriteEn,
			ReadEn	     => ReadEn,
			DataOut	     => DataOut,
			Full	     => Full,
			Empty	     => Empty,
			AlmostEmpty  => AlmostEmpty,
			AlmostFull   => AlmostFull
		);
	
	-- Clock process definitions
	clk_wr_period_proc :process
	begin
	   clk_wr <= '0';
	wait for clk_wr_period/2;
	   clk_wr <= '1';
	wait for clk_wr_period/2;
	end process;

	-- Clock process definitions
	clk_rd_period_proc :process
	begin
	   clk_rd <= '0';
	wait for clk_rd_period/2;
	   clk_rd <= '1';
	wait for clk_rd_period/2;
	end process;
	
	-- Reset process
	rst_proc : process
	begin
	
        for i in 1 to 1 loop
            wait until falling_edge(clk_wr);
        end loop;
        RST <= '1';
        
        for i in 1 to 31 loop
        	wait until falling_edge(clk_wr);
        end loop;
        RST <= '0';

--        -- test reset when writing to fifo      
--        for i in 1 to 700 loop
--            wait until rising_edge(clk);
--        end loop;
--        RST <= '1';
--        wait until rising_edge(clk);
--        RST <= '0';
		
	wait;
	end process;
	
	-- Write process
	wr_proc : process
		variable counter : unsigned (DATA_IN_WIDTH-1 downto 0) := (others => '0');
	begin		
        writing_frame <= '0';
        for i in 1 to 40 loop
            wait until falling_edge(clk_wr);     
        end loop;
		for i in 1 to FIFO_DEPTH*15 loop
            wait until falling_edge(clk_wr);
            writing_frame <= '1';
            DataIn <= std_logic_vector(counter);
            counter := counter + 1;
            WriteEn <= '1';
            wait until falling_edge(clk_wr);
            WriteEn <= '0';
            wait until falling_edge(clk_wr);
		end loop;
		wait until falling_edge(clk_wr);
		WriteEn <= '0';
		writing_frame <= '0';

		wait;
	end process;
	
	-- Read process
	rd_proc : process
	begin
        for i in 1 to 20 loop
            wait until falling_edge(clk_rd);     
        end loop;
        while Empty = '1' loop
            wait until falling_edge(clk_rd);     
        end loop;
        while writing_frame = '1' loop
            wait until falling_edge(clk_rd);
            AlmostFull_d <= AlmostFull;
            AlmostEmpty_d <= AlmostEmpty;
            -- check for AlmostFull rising edge (then start reading from fifo)
            if AlmostFull_d = '0' and AlmostFull = '1' then
		       ReadEn <= '1';
            -- or Empty rising edge (then stop reading from of fifo)
		    elsif AlmostEmpty_d = '0' and AlmostEmpty = '1' then
		       ReadEn <= '0';
		    end if;
        end loop;
        while Empty = '0' loop
            wait until falling_edge(clk_rd);
            ReadEn <= '1';
        end loop;
        ReadEn <= '0';

		wait;
	end process;

END;