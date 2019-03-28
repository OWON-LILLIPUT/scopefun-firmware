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


LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY SPI_tb_ADC IS
END SPI_tb_ADC;
 
ARCHITECTURE behavior OF SPI_tb_ADC IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
	 component spi is
	  generic (
            SPI_LENGTH : integer -- NUMBER OF BITS TRANSFERED
            );
	  Port ( clk : in  std_logic;				
		     rst : in std_logic;
		     clk_divide : in std_logic_vector (4 downto 0);
			 spi_data : in  std_logic_vector (SPI_LENGTH-1 downto 0);
			 spi_write_trig : in std_logic;	
			 sck_idle_value : in std_logic;
			 spi_busy : out std_logic;
             cs : out  std_logic;				
             sck : out  std_logic;			
             si : out  std_logic
			 );			
	end component;
    
	--cont
	CONSTANT SPI_LENGTH : integer := 24;
	
    --Inputs
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal clk_divide : std_logic_vector(4 downto 0) := "10011";
    signal spi_data : std_logic_vector(15 downto 0) := (others => '0');
    signal spi_write_trig : std_logic := '0';
    signal sck_idle_value : std_logic := '0'; 
    
 	 --Outputs
    signal spi_busy : std_logic;
    signal cs : std_logic;
    signal cs_i : std_logic;
    signal sck : std_logic;
    signal sck_i : std_logic;

	signal si : std_logic;

	signal adc_spi_data : std_logic_vector (23 downto 0) := X"000D" & X"02";
	signal configureADC : std_logic :='0';
	
	signal DAC_state : std_logic_vector (1 downto 0) := "00";
	
	CONSTANT DAC_A: STD_LOGIC_VECTOR (1 DownTo 0) := "00";
    CONSTANT DAC_B: STD_LOGIC_VECTOR (1 DownTo 0) := "01";
	CONSTANT DAC_C: STD_LOGIC_VECTOR (1 DownTo 0) := "10";
	CONSTANT DAC_D: STD_LOGIC_VECTOR (1 DownTo 0) := "11";
	
   -- Clock period definitions
   constant clk_period : time := 10 ns;
   constant clk_divide_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: SPI
      generic map (SPI_LENGTH => SPI_LENGTH) 
      PORT MAP (
          clk => clk,
          rst => rst,
          clk_divide => clk_divide,
          spi_data => adc_spi_data,
          spi_write_trig => configureADC,
          sck_idle_value => sck_idle_value,
          spi_busy => spi_busy,
          cs => cs_i,
          sck => sck,
          si => si
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;

   cs <= cs_i;

   -- Stimulus process
   stim_proc: process
   begin	
		
		wait for 3*clk_period;

			-- update DAC config registers
            adc_spi_data <= X"800D" & X"01";
		
		    case DAC_state (1 downto 0) is
				
			    when DAC_A => -- "DAC REGISTER PROGRAMMING"
							
				    rst <= '1';
				    configureADC <= '1';
					DAC_state <= DAC_B; --goto WAIT
					
				when DAC_B => --"WAIT state"
				    
                    if spi_busy = '1' then
                        configureADC <= '0';
                        rst <= '0';
                        DAC_state <= DAC_B;
                    else
                        configureADC <= '1';
                        rst <= '1';
                        DAC_state <= DAC_C;
                    end if;
                
               when DAC_C => --"WAIT state"
                        
                    rst <= '0';
                    if spi_busy = '1' then
                        configureADC <= '0';
                        DAC_state <= DAC_C;
                    else
                        configureADC <= '0';
                        DAC_state <= DAC_C;
                    end if;
                     
				when others =>
					DAC_state <= DAC_A;
						
			end case;
			
   end process;

END;
