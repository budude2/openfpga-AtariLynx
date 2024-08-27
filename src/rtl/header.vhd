library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegisterBus.all;
use work.pReg_suzy.all;
use work.pReg_mikey.all;

entity header is
   port 
   (
      clk            : in  std_logic;

      romsize        : in  std_logic_vector(19 downto 0);
      romwrite_data  : in  std_logic_vector(15 downto 0);
      romwrite_addr  : in  std_logic_vector(19 downto 0);
      romwrite_wren  : in  std_logic;
      
      bank0size      : out std_logic_vector(15 downto 0);
      hasHeader      : out std_logic := '0';
            
      custom_PCAddr  : out std_logic_vector(15 downto 0);
      custom_PCuse   : out std_logic := '0';
      
      bs93_addr      : buffer integer range 0 to 65535;
      bs93_data      : out std_logic_vector(7 downto 0);     
      bs93_wren      : out std_logic := '0'
   );
end entity;

architecture arch of header is

   signal lynxheader       : std_logic_vector(1 downto 0);
   signal bank0size_header : std_logic_vector(15 downto 0);

   signal bs93header       : std_logic_vector(1 downto 0);
   signal bs93size         : integer range 0 to 65535;
   signal bs93nextByte     : std_logic := '0';
   
begin 

   process (clk)
   begin
      if rising_edge(clk) then

         bs93_wren    <= '0';
         bs93nextByte <= '0';

         if (romwrite_wren = '1') then
         
            -- LYNX header
            if (romwrite_addr = x"00000") then 
               if (romwrite_data = x"594C") then lynxheader(0) <= '1'; else lynxheader(0) <= '0'; end if;
            end if;
            if (romwrite_addr = x"00002") then 
               if (romwrite_data = x"584E") then lynxheader(1) <= '1'; else lynxheader(1) <= '0'; end if;
            end if;
            if (romwrite_addr = x"00004") then 
               bank0size_header <= romwrite_data;
            end if;
            
            -- BS93 header
            if (romwrite_addr = x"00006") then 
               if (romwrite_data = x"5342") then bs93header(0) <= '1'; else bs93header(0) <= '0'; end if;
            end if;
            if (romwrite_addr = x"00008") then 
               if (romwrite_data = x"3339") then bs93header(1) <= '1'; else bs93header(1) <= '0'; end if;
            end if;
            if (romwrite_addr = x"00002") then 
               custom_PCAddr <= romwrite_data(7 downto 0) & romwrite_data(15 downto 8);
               bs93_addr     <= to_integer(unsigned(romwrite_data(7 downto 0) & romwrite_data(15 downto 8))) - 1;
            end if;
            if (romwrite_addr = x"00004") then 
               bs93size <= to_integer(unsigned(romwrite_data(7 downto 0) & romwrite_data(15 downto 8)));
            end if;
            
            if (bs93header = "11") then
               if (unsigned(romwrite_addr) >= 10 and bs93size > 0) then
                  bs93_addr    <= bs93_addr + 1;
                  bs93_data    <= romwrite_data(7 downto 0);
                  bs93_wren    <= '1';
                  bs93size     <= bs93size - 1;
                  bs93nextByte <= '1';
               end if;
            end if;
            
         end if;
         
         -- bs93 second byte
         if (bs93nextByte = '1') then
            bs93_addr <= bs93_addr + 1;
            bs93_data <= romwrite_data(15 downto 8);
            bs93_wren <= '1';
            bs93size  <= bs93size - 1;
         end if;

         -- bank0size
         hasHeader    <= '0';
         custom_PCuse <= '0';
         if (lynxheader = "11") then
            hasHeader <= '1';
            bank0size <= bank0size_header;
         elsif (bs93header = "11") then
            bank0size    <= (others => '0');
            custom_PCuse <= '1';
         else
            if (unsigned(romsize(19 downto 8)) > 0) then
               if    (unsigned(romsize(19 downto 8)) <= x"100") then bank0size <= x"0100";
               elsif (unsigned(romsize(19 downto 8)) <= x"200") then bank0size <= x"0200";
               elsif (unsigned(romsize(19 downto 8)) <= x"400") then bank0size <= x"0400";
               elsif (unsigned(romsize(19 downto 8)) <= x"800") then bank0size <= x"0800";
               end if;
            else
               bank0size <= (others => '0');
            end if;
         end if;

      end if;
   end process;


end architecture;





