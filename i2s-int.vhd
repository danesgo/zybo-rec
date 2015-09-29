----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Daniel González
-- 
-- Create Date:    12:03:03 09/28/2015 
-- Design Name: 
-- Module Name:    i2s_int - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity i2s_int is
	generic(
		width: integer := 24 -- Single Channel 24 bit ADC.
	);
	
	port(
		clk: in std_logic; -- main zybo clock 125 MHz 
		recdat: in std_logic; -- data to be recorded
		d_in: in std_logic_vector(width-1 downto 0); -- data from FIFO to be transmitted
		rst: in std_logic; --reset
		
		--inputs from fifo
		fifo_full, fifo_empty: in std_logic;
		--inputs from control
		rec,pb: in std_logic;
		
		--output
		mclk: out std_logic; -- 12.2MHz (obtained from the SSM2603 codec datasheet)
		bclk: out std_logic; -- 1.152MHz
		reclrc: out std_logic; -- always low = '0' because it's always channel 1
		pbdat: out std_logic; -- Serial data output pin, data to be played. 
		pblrc: out std_logic; -- for mono always low '0'
		mute: out std_logic; -- always high = '1' because it's never muted
		rec_done: out std_logic;  -- done flag for FIFO to write the current (recorded) value present on d_out
		pb_done: out std_logic; -- done flag for FIFO to read the current value (for playback) present on d_in
		d_out: out std_logic_vector(width-1 downto 0) --data received to FIFO for storage
	);
end i2s_int;

architecture Behavioral of i2s_int is
--Signals Declarations
	signal bclk_s: std_logic; --bit serial clock signal
	signal mclk_s: std_logic; --master clock signal
	signal CLKcount: integer range 0 to 55 := 0; -- Clock counter and divider 125MHz/1.152MHz = 108.5
	signal CLKcnt: integer range 0 to 6 := 0; -- Clock counter an divider 125MHz/12.288MHz = 10.17 
	signal b_cnt, b_cnt2: integer range 0 to width := 0;-- received bit counter
	signal b_reg, b_reg2: std_logic_vector (width-1 downto 0); --received data vector
	
	
begin
	Frec_DividerBCLK: process(clk, rst) begin
		if (rst = '1') then
		--reset state
			bclk_s <= '0';
			CLKcount <= 0;
		elsif rising_edge(clk) then
			if (CLKcount = 53) then --supposed to be 54 but that generates 1.136MHz
				bclk_s <= not(bclk_s);
				CLKcount <= 0;
			else
				CLKcount <= CLKcount + 1;
			end if;
		end if;
	end process;
	
	Frec_DividerMCLK: process(clk, rst) begin
		if (rst = '1') then
		--reset state
			mclk_s <= '0';
			CLKcnt <= 0;
		elsif rising_edge(clk) then
			if (CLKcnt = 4) then --supposed to be 5 but that generates 10.416MHz
				mclk_s <= not(mclk_s);
				CLKcnt <= 0;
			else
				CLKcnt <= CLKcnt + 1;
			end if;
		end if;
	end process;
	
	Data_ret: process(bclk_s, rst, fifo_full, pb) begin
		if (rst = '1') then
		--reset state
		elsif rising_edge(bclk_s) and (fifo_full = '0') and (pb = '1') then
			if (b_cnt = width-1) then
				b_reg <= b_reg(width - 2 downto 0) & recdat; --Chapus!
				b_cnt <= 0;
				rec_done <= '1';
			else
				b_reg <= b_reg(width - 2 downto 0) & recdat;
				b_cnt <= b_cnt + 1;
				rec_done <= '0';
			end if;
		end if;
	end process;
	
	Data_trans: process(bclk_s, rst, fifo_empty, rec) begin --transmision de datos cuando la fifo esta llena
		if (rst = '1') then
		--reset state code
		elsif rising_edge(bclk_s) and (fifo_empty = '0') and (rec = '1') then 
			if (b_cnt2 = width-1) then
				pbdat <= b_reg2(width - 1); --Chapus!
				b_reg2 <= b_reg2(width - 2 downto 0) & '0'; 
				b_cnt2 <= 0;
				pb_done <= '1';
				--b_reg2 <= std_logic_vector(to_signed(to_integer(unsigned(d_in)),width));
				b_reg2 <= d_in;
			else
				pbdat <= b_reg2(width - 1); --toma el MSB y lo envia a pbdat
				b_reg2 <= b_reg2(width - 2 downto 0) & '0'; --corrimiento hacia la izquierda
				b_cnt2 <= b_cnt2 + 1; --contador de bits
				pb_done <= '0';
			end if;
		end if;
	end process;
	bclk <= bclk_s;
	mclk <= mclk_s;
	reclrc <= '0';
	pblrc <= '0';
	mute <= '1';
	d_out <= b_reg; 
end Behavioral;

