library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegisterBus.all;
use work.pReg_mikey.all;
use work.pBus_savestates.all;
use work.pReg_savestates.all; 

entity display_dma is
   port 
   (
      clk            : in  std_logic;
      ce             : in  std_logic;
      reset          : in  std_logic;
                     
      RegBus_Din     : in  std_logic_vector(BUS_buswidth-1 downto 0);
      RegBus_Adr     : in  std_logic_vector(BUS_busadr-1 downto 0);
      RegBus_wren    : in  std_logic;
      RegBus_rst     : in  std_logic;
      RegBus_Dout    : out std_logic_vector(BUS_buswidth-1 downto 0);   
      
      cpu_idle       : in  std_logic;
      displayLine    : in  std_logic;
      frameEnd       : in  std_logic;
      
      dma_active     : out std_logic := '0';
      dma_done       : out std_logic;
      RAM_address    : out integer range 0 to 65535;
      RAM_dataRead   : in  std_logic_vector(7 downto 0);
      
      pixel_out_addr : out integer range 0 to 16319 := 0;                     -- address for framebuffer 
      pixel_out_data : out std_logic_vector(11 downto 0) := (others => '0');  -- RGB data for framebuffer 
      pixel_out_we   : out std_logic := '0';                                  -- new pixel for framebuffer 
      
      pixel_out_x    : buffer integer range 0 to 159 := 0;                    
      pixel_out_y    : out integer range 0 to 101 := 0;                    
      HzcountBCDout  : out unsigned(7 downto 0) := (others => '0');
   
      -- savestates        
      SSBUS_Din      : in  std_logic_vector(SSBUS_buswidth-1 downto 0);
      SSBUS_Adr      : in  std_logic_vector(SSBUS_busadr-1 downto 0);
      SSBUS_wren     : in  std_logic;
      SSBUS_rst      : in  std_logic;
      SSBUS_Dout     : out std_logic_vector(SSBUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of display_dma is

   -- register
   signal Reg_TIM2BKUP : std_logic_vector(TIM2BKUP.upper downto TIM2BKUP.lower) := (others => '0');
   signal Reg_DISPADRH : std_logic_vector(DISPADRH.upper downto DISPADRH.lower) := (others => '0');
   signal Reg_DISPADRL : std_logic_vector(DISPADRL.upper downto DISPADRL.lower) := (others => '0');
   signal Reg_DISPCTL  : std_logic_vector(DISPCTL.upper  downto DISPCTL.lower ) := (others => '0');
   
   type tcolor is array (0 to 15) of std_logic_vector(11 downto 0);
   signal color : tcolor;

   type t_reg_wired_or is array(0 to 33) of std_logic_vector(7 downto 0);
   signal reg_wired_or : t_reg_wired_or;   
   
   -- internal
   type tstate is
   (
      IDLE,
      WAITSTART,
      READBYTE,
      READDONE,
      WRITEPIXELHIGH,
      WRITEPIXELLOW
   );   
   signal state : tstate := IDLE;
   
   signal first          : std_logic := '0';
   signal currentLine    : unsigned(7 downto 0)  := (others => '0');
   signal lineDMACounter : unsigned(6 downto 0)  := (others => '0');
   signal pixeladdr      : unsigned(15 downto 0) := (others => '0');
   signal bytesleft      : integer range 0 to 79 := 0;
   
   signal dma_new        : std_logic;
   
   signal dataBuffer     : std_logic_vector(7 downto 0) := (others => '0');
   signal pixel_addrNext : integer range 0 to 16319 := 0;
   
   -- hz counter
   signal secondcounter  : integer range 0 to 63999999 := 0;
   signal HzcountBCD     : unsigned(7 downto 0) := (others => '0');
   
   -- savestates
   signal SS_DMA         : std_logic_vector(REG_SAVESTATE_DMA.upper downto REG_SAVESTATE_DMA.lower);
   signal SS_DMA_BACK    : std_logic_vector(REG_SAVESTATE_DMA.upper downto REG_SAVESTATE_DMA.lower);

begin 

   iSS_DMA : entity work.eReg_SS generic map ( REG_SAVESTATE_DMA ) port map (clk, SSBUS_Din, SSBUS_Adr, SSBUS_wren, SSBUS_rst, SSBUS_Dout, SS_DMA_BACK, SS_DMA); 


   iReg_TIM2BKUP : entity work.eReg generic map ( TIM2BKUP ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, open           , Reg_TIM2BKUP, Reg_TIM2BKUP);  
   iReg_DISPADRH : entity work.eReg generic map ( DISPADRH ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(0), Reg_DISPADRH, Reg_DISPADRH);  
   iReg_DISPADRL : entity work.eReg generic map ( DISPADRL ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(1), Reg_DISPADRL, Reg_DISPADRL);  
   iReg_DISPCTL  : entity work.eReg generic map ( DISPCTL  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, open           , Reg_DISPCTL , Reg_DISPCTL );  
      
   gcolorregs: for i in 0 to 15 generate
   begin
      iReg_GREEN   : entity work.eReg generic map ( GREEN  , i ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(2 + i), color(i)(11 downto 8), color(i)(11 downto 8));  
      iReg_BLUERED : entity work.eReg generic map ( BLUERED, i ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(18 + i), color(i)( 7 downto 0), color(i)( 7 downto 0));  
   end generate;
      
   process (reg_wired_or)
      variable wired_or : std_logic_vector(7 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      RegBus_Dout <= wired_or;
   end process;
   
   -- hz counter
   process (clk)
   begin
      if rising_edge(clk) then
         if (ce = '1' and frameEnd = '1') then
            if (HzcountBCD(3 downto 0) < 9) then
               HzcountBCD(3 downto 0) <= HzcountBCD(3 downto 0) + 1;
            else
               if (HzcountBCD(7 downto 4) < 9) then
                  HzcountBCD(3 downto 0) <= x"0";
                  HzcountBCD(7 downto 4) <= HzcountBCD(7 downto 4) + 1;
               end if;
            end if;
         end if;
         
         if (secondcounter < 63999999) then
            secondcounter <= secondcounter + 1;
         else
            secondcounter  <= 0;
            HzcountBCDout <= HzcountBCD;
            HzcountBCD    <= (others => '0');
         end if;

      end if;
   end process;
   
   
   dma_new    <= '1' when (displayLine = '1' and first = '0' and (lineDMACounter > 0 or currentLine = (unsigned(Reg_TIM2BKUP) - 3))) else '0';
   dma_active <= '0' when state = IDLE and dma_new = '0' else '1'; 
   
   RAM_address <= to_integer(pixeladdr);
   
   SS_DMA_BACK( 7 downto  0) <= std_logic_vector(currentLine   );
   SS_DMA_BACK(14 downto  8) <= std_logic_vector(lineDMACounter);
   SS_DMA_BACK(          15) <= first;
   SS_DMA_BACK(31 downto 16) <= std_logic_vector(pixeladdr     );
   
   process (clk)
      variable colorval : std_logic_vector(11 downto 0);
   begin
      if rising_edge(clk) then
      
         pixel_out_we <= '0';
         dma_done     <= '0';
      
         if (reset = '1') then
      
            state          <= IDLE;
            currentLine    <= unsigned(SS_DMA( 7 downto  0)); --(others => '0');
            lineDMACounter <= unsigned(SS_DMA(14 downto  8)); --(others => '0');
            first          <= SS_DMA(          15);           -- '1';
            pixeladdr      <= unsigned(SS_DMA(31 downto 16)); --(others => '0');

         elsif (ce = '1') then
         
            if (frameEnd = '1') then
               first          <= '0';
               currentLine    <= unsigned(Reg_TIM2BKUP);
               lineDMACounter <= (others => '0');
            end if;
         
            case (state) is
            
               when IDLE =>
                  if (displayLine = '1') then
                     if (currentLine = (unsigned(Reg_TIM2BKUP) - 3)) then
                        lineDMACounter <= to_unsigned(101, 7);
                        pixeladdr      <= unsigned(Reg_DISPADRH) & unsigned(Reg_DISPADRL(7 downto 2)) & "00";
                        if (Reg_DISPCTL(1) = '1') then -- flip mode
                           pixeladdr(1 downto 0) <= "11";
                        end if;
                     end if;
                  
                     if (dma_new = '1') then
                        bytesleft      <= 79;
                        if (lineDMACounter > 0) then
                           lineDMACounter <= lineDMACounter - 1;
                        end if;
                        pixel_addrNext <= (101 - to_integer(currentLine)) * 160;
                        pixel_out_x    <= 0;
                        pixel_out_y    <= (101 - to_integer(currentLine));
                        if (cpu_idle = '1') then
                           state   <= READBYTE;
                        else
                           state   <= WAITSTART;
                        end if;
                     end if;
                     
                     if (currentLine > 0) then
                        currentLine <= currentLine - 1;
                     end if;
                  end if;

               when WAITSTART =>
                  if (cpu_idle = '1') then
                     state   <= READBYTE;
                  else
                     state   <= WAITSTART;
                  end if;
               
               when READBYTE =>
                  state <= READDONE;
               
               when READDONE => 
                  state      <= WRITEPIXELHIGH;
                  if (Reg_DISPCTL(1) = '1') then -- flip mode
                     pixeladdr  <= pixeladdr - 1;
                  else
                     pixeladdr  <= pixeladdr + 1;
                  end if;
                  dataBuffer <= RAM_dataRead;
               
               when WRITEPIXELHIGH =>
                  state          <= WRITEPIXELLOW;  
                  pixel_addrNext <= pixel_addrNext + 1;
                  pixel_out_x    <= pixel_out_x + 1;
                  pixel_out_we   <= '1';
                  pixel_out_addr <= pixel_addrNext;
                  
                  if (Reg_DISPCTL(1) = '1') then
                     colorval := color(to_integer(unsigned(dataBuffer(3 downto 0))));
                  else
                     colorval := color(to_integer(unsigned(dataBuffer(7 downto 4))));
                  end if;
                  pixel_out_data <= colorval(3 downto 0) & colorval(11 downto 8) & colorval(7 downto 4);
               
               when WRITEPIXELLOW => 
                  if (pixel_addrNext < 16319) then
                     pixel_addrNext <= pixel_addrNext + 1;
                  end if; 
                  
                  if (pixel_out_x < 159) then 
                     pixel_out_x    <= pixel_out_x + 1;
                  end if;
                  pixel_out_we   <= '1';
                  pixel_out_addr <= pixel_addrNext;
                  
                  if (Reg_DISPCTL(1) = '1') then
                     colorval := color(to_integer(unsigned(dataBuffer(7 downto 4))));
                  else
                     colorval := color(to_integer(unsigned(dataBuffer(3 downto 0))));
                  end if;
                  pixel_out_data <= colorval(3 downto 0) & colorval(11 downto 8) & colorval(7 downto 4);
                  if (bytesleft > 0) then
                     state     <= READBYTE;
                     bytesleft <= bytesleft - 1;
                  else
                     state    <= IDLE;
                     dma_done <= '1';
                  end if;
            
            end case;
            
         end if;
      end if;
   end process;
  

end architecture;





