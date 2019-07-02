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

ENTITY fifo_128_to_32_tb IS
END fifo_128_to_32_tb;

ARCHITECTURE behavior OF fifo_128_to_32_tb IS 
	
	-- Component Declaration for the Unit Under Test (UUT)
	component fifo_128_to_32
		Generic (
		  constant DATA_IN_WIDTH : positive :=  128;
          constant FIFO_DEPTH    : positive :=  512
		);
		port (
		  clk     : in  STD_LOGIC;
          rst        : in  STD_LOGIC;
          WriteEn    : in  STD_LOGIC;
          DataIn    : in  STD_LOGIC_VECTOR (DATA_IN_WIDTH - 1 downto 0);
          ReadEn    : in  STD_LOGIC;
          DataOut    : out STD_LOGIC_VECTOR (DATA_IN_WIDTH/4 - 1 downto 0);
          DataOutValid : out std_logic;
          Empty    : out STD_LOGIC;
          AlmostEmpty : out STD_LOGIC;
          Full    : out STD_LOGIC;
          AlmostFull : out STD_LOGIC
		);
	end component;

	constant DATA_IN_WIDTH : integer := 128;
	constant FIFO_DEPTH	: integer := 512;

	--Inputs
	signal clk		: std_logic := '0';
	signal rst		: std_logic := '0';
	signal DataIn	: std_logic_vector(DATA_IN_WIDTH -1 downto 0) := (others => '0');
	signal ReadEn	: std_logic := '0';
	signal WriteEn	: std_logic := '0';
	
	--Outputs
	signal DataOut	: std_logic_vector(DATA_IN_WIDTH/4 - 1 downto 0);
	signal DataOutValid : std_logic;
	signal Empty	: std_logic;
	signal Full		: std_logic;
	signal AlmostEmpty	: std_logic;
    signal AlmostFull   : std_logic;
	
	-- Clock period definitions
	constant CLK_period : time := 10 ns;
	
	-- internal
	signal InputValid : std_logic := '0';
    signal AlmostEmpty_d : std_logic := '0';
	signal AlmostFull_d : std_logic := '0';
    signal writing_frame : std_logic := '0';
    signal flagd : std_logic := '0';
    signal wr_skip_cnt : integer range 0 to 127 := 0;
    
BEGIN

	-- Instantiate the Unit Under Test (UUT)
	uut: fifo_128_to_32
		PORT MAP (
			CLK		     => CLK,
			RST		     => RST,
			DataIn	     => DataIn,
			WriteEn	     => WriteEn,
			ReadEn	     => ReadEn,
			DataOut	     => DataOut,
			DataOutValid => DataOutValid,
			Full	     => Full,
			Empty	     => Empty,
			AlmostEmpty  => AlmostEmpty,
			AlmostFull   => AlmostFull
		);
	
	-- Clock process definitions
	CLK_process :process
	begin
	   CLK <= '0';
	wait for CLK_period/2;
	   CLK <= '1';
	wait for CLK_period/2;
	end process;
	
	-- Reset process
	rst_proc : process
	begin
	
        for i in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;
        RST <= '1';
        
        for i in 1 to 5 loop
        	wait until rising_edge(clk);
        end loop;
        RST <= '0';

--        -- test reset when reading/writing to fifo      
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
		variable counter1 : unsigned (DATA_IN_WIDTH/4-1 downto 0) := to_unsigned(4,DATA_IN_WIDTH/4);
		variable counter2 : unsigned (DATA_IN_WIDTH/4-1 downto 0) := to_unsigned(5,DATA_IN_WIDTH/4);
		variable counter3 : unsigned (DATA_IN_WIDTH/4-1 downto 0) := to_unsigned(6,DATA_IN_WIDTH/4);
		variable counter4 : unsigned (DATA_IN_WIDTH/4-1 downto 0) := to_unsigned(7,DATA_IN_WIDTH/4);
	begin		
        writing_frame <= '0';
        for i in 1 to 31 loop
            wait until falling_edge(clk);     
        end loop;
        wait until falling_edge(clk);
		while counter1 <= to_unsigned(10000,counter1'LENGTH) loop
            wait until falling_edge(clk);
            AlmostFull_d <= AlmostFull;  
            AlmostEmpty_d <= AlmostEmpty;
           -- check for AlmostFull rising edge (then stop writing to fifo)
            if AlmostFull_d = '0' and AlmostFull = '1' then
                WriteEn <= '0';
            -- or AlmostEmpty rising edge (then start writing to fifo)
            elsif AlmostEmpty_d = '0' and AlmostEmpty = '1' then
                WriteEn <= '1';
                DataIn <= X"000000DD000000010000000200000003";
            end if;
            if writing_frame = '1' then 
                if wr_skip_cnt = 23 then
                    WriteEn <= '1';
                    wr_skip_cnt <= 0;
                else
                    WriteEn <= '0';
                    wr_skip_cnt <= wr_skip_cnt + 1;
                end if;
            end if;
            if WriteEn = '1' then
                writing_frame <= '1';
                DataIn <= std_logic_vector(counter1) & std_logic_vector(counter2) & std_logic_vector(counter3) & std_logic_vector(counter4);
                counter1 := counter1 + 4;
                counter2 := counter2 + 4;
                counter3 := counter3 + 4;
                counter4 := counter4 + 4;
            end if;
        end loop;
        wait until falling_edge(clk);
        WriteEn <= '0';
        writing_frame <= '0';

		wait;
	end process;
	
	generate_flagd: process
    begin
        for i in 0 to 800 loop
            wait until rising_edge(clk);
        end loop; 
        for i in 0 to 150 loop
            wait until rising_edge(clk);
            flagd <= '0';
            for i in 0 to 56 loop
                wait until rising_edge(clk);
            end loop;
            flagd <= '1';
            for i in 0 to 1023 loop
                wait until rising_edge(clk);
            end loop;
            flagd <= '0';
            for i in 0 to 82 loop
                wait until rising_edge(clk);
            end loop;
            flagd <= '1';
            for i in 0 to 1023 loop
                wait until rising_edge(clk);
            end loop;
        end loop;      
    end process;
	
	-- Read process
	rd_proc : process
	begin
        for i in 1 to 30 loop
            wait until rising_edge(clk);     
        end loop;
        for i in 1 to 70 loop
            for i in 1 to 1024 loop
                wait until rising_edge(clk);
                if flagd = '1' then
                    ReadEn <= '1';
                else
                    ReadEn <= '0';
                end if;
            end loop;
            for i in 1 to 5 loop
                wait until rising_edge(clk);
                ReadEn <= '0';   
            end loop;
        end loop;
		wait;
	end process;

END;