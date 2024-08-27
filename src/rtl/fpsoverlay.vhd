library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

entity fpsoverlay is
   port 
   (
      clk            : in  std_logic;
      
      overlay_on     : in  std_logic;
                     
      pixel_out_addr : out integer range 0 to 16319 := 0;                     -- address for framebuffer 
      pixel_out_data : out std_logic_vector(11 downto 0) := (others => '0');  -- RGB data for framebuffer 
      pixel_out_we   : out std_logic := '0';                                  -- new pixel for framebuffer 
      
      pixel_in_addr  : in  integer range 0 to 16319;                     
      pixel_in_data  : in  std_logic_vector(11 downto 0); 
      pixel_in_we    : in  std_logic;                                 
      
      pixel_x        : in  integer range 0 to 159 := 0;                    
      pixel_y        : in  integer range 0 to 101 := 0;                    
      HzcountBCD     : in  unsigned(7 downto 0) := (others => '0');
      FPScountBCD    : in  unsigned(7 downto 0) := (others => '0')
   );
end entity;

architecture arch of fpsoverlay is

   type toverlayout is array (0 to 4) of std_logic_vector(11 downto 0);
   signal overlay_out      : toverlayout;
   signal overlay_combined : std_logic_vector(11 downto 0);
   
   type ttext is array (0 to 4) of unsigned(7 downto 0);
   signal textchar      : ttext;
   
   signal pixel_addr_1  : integer range 0 to 16319;                     
   signal pixel_data_1  : std_logic_vector(11 downto 0); 
   signal pixel_we_1    : std_logic;      
   
   signal pixel_addr_2  : integer range 0 to 16319;                     
   signal pixel_data_2  : std_logic_vector(11 downto 0); 
   signal pixel_we_2    : std_logic;    
   
   
begin 
   
   process (clk)
   begin
      if rising_edge(clk) then
      
         pixel_addr_1   <= pixel_in_addr;
         pixel_data_1   <= pixel_in_data; 
         pixel_we_1     <= pixel_in_we;
         
         pixel_addr_2   <= pixel_addr_1;
         pixel_data_2   <= pixel_data_1;
         pixel_we_2     <= pixel_we_1;  
         
         pixel_out_addr <= pixel_addr_2;
         pixel_out_data <= pixel_data_2 or overlay_combined;
         pixel_out_we   <= pixel_we_2;
         
      end if;
   end process;
   
   process (overlay_out)
      variable wired_or : std_logic_vector(11 downto 0);
   begin
      wired_or := (others => '0');
      for i in 0 to (overlay_out'length - 1) loop
         wired_or := wired_or or overlay_out(i);
      end loop;
      overlay_combined <= wired_or;
   end process;
   
   textchar(0) <= x"10" + HzcountBCD(7 downto 4);
   textchar(1) <= x"10" + HzcountBCD(3 downto 0);
   textchar(2) <= x"5C";
   textchar(3) <= x"10" + FPScountBCD(7 downto 4);
   textchar(4) <= x"10" + FPScountBCD(3 downto 0);
   
   --                                                 BGON    BACK   FRONT   X  Y             clk     ena         x        y      datain dataout         text
   ioverlayNumbers0 : entity work.overlay generic map ( '0', x"000", x"FFF",  2, 1) port map ( Clk, overlay_on, pixel_x, pixel_y, x"000", overlay_out(0), textchar(0));
   ioverlayNumbers1 : entity work.overlay generic map ( '0', x"000", x"FFF", 12, 1) port map ( Clk, overlay_on, pixel_x, pixel_y, x"000", overlay_out(1), textchar(1));
   ioverlayNumbers2 : entity work.overlay generic map ( '0', x"000", x"FFF", 22, 1) port map ( Clk, overlay_on, pixel_x, pixel_y, x"000", overlay_out(2), textchar(2));
   ioverlayNumbers3 : entity work.overlay generic map ( '0', x"000", x"FFF", 32, 1) port map ( Clk, overlay_on, pixel_x, pixel_y, x"000", overlay_out(3), textchar(3));
   ioverlayNumbers4 : entity work.overlay generic map ( '0', x"000", x"FFF", 42, 1) port map ( Clk, overlay_on, pixel_x, pixel_y, x"000", overlay_out(4), textchar(4));

end architecture;





