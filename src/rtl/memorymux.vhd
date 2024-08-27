library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRegisterBus.all;  
use work.pBus_savestates.all;
use work.pReg_savestates.all; 

entity memorymux is
   port 
   (
      clk                  : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      bus_request          : in  std_logic;
      bus_rnw              : in  std_logic;
      bus_addr             : in  unsigned(15 downto 0);
      bus_datawrite        : in  std_logic_vector(7 downto 0);
      bus_dataread         : out std_logic_vector(7 downto 0) := (others => '0');
      bus_done             : out std_logic := '0';
                           
      RAMaccess            : out std_logic := '0';
      cheatOverwrite       : in  std_logic;
      cheatData            : in  std_logic_vector(7 downto 0);
                           
      RegBus_Din           : out std_logic_vector(BUS_buswidth-1 downto 0) := (others => '0');
      RegBus_Adr           : out std_logic_vector(BUS_busadr-1 downto 0) := (others => '0');
      RegBus_wren          : out std_logic := '0';
      RegBus_Dout          : in  std_logic_vector(BUS_buswidth-1 downto 0);
      
      cpu_idle             : in  std_logic;
      dma_active           : in  std_logic;
      DMA_RAM_address      : in  integer range 0 to 65535;
      GPU_RAM_address      : in  integer range 0 to 65535;
      GPURAM_dataWrite     : in  std_logic_vector(7 downto 0);     
      GPURAM_wren          : in  std_logic;     
      DMAGPURAM_dataRead   : out std_logic_vector(7 downto 0);     
      
      cart_strobe0         : out std_logic;
      cart_strobe1         : out std_logic; 
      cart_wait            : in  std_logic; 
      serdat_read          : out std_logic;  
      
      bios_wraddr          : in  std_logic_vector(8 downto 0);
      bios_wrdata          : in  std_logic_vector(7 downto 0);
      bios_wr              : in  std_logic;
      
      bs93_addr            : in  integer range 0 to 65535;
      bs93_data            : in  std_logic_vector(7 downto 0);     
      bs93_wren            : in  std_logic;
      
      -- savestates              
      SSBus_Din            : in  std_logic_vector(SSBUS_buswidth-1 downto 0);
      SSBus_Adr            : in  std_logic_vector(SSBUS_busadr-1 downto 0);
      SSBus_wren           : in  std_logic;
      SSBus_rst            : in  std_logic;
      SSBus_Dout           : out std_logic_vector(SSBUS_buswidth-1 downto 0);
      
      SSMEM_Addr           : in  std_logic_vector(15 downto 0);
      SSMEM_WrEn           : in  std_logic_vector(1 downto 0);
      SSMEM_WriteData      : in  std_logic_vector(7 downto 0);
      SSMEM_ReadData_REG   : out std_logic_vector(7 downto 0);
      SSMEM_ReadData_RAM   : out std_logic_vector(7 downto 0)
   );
end entity;

architecture arch of memorymux is

   type tState is
   (
      IDLE,
      READ_MAPPEDREG,
      READ_REG,
      READ_ROM,
      READ_RAM,
      READ_CART,
      WRITE_WAIT
   );
   signal state : tState := IDLE;
   
   signal mappedSuzy             : std_logic;
   signal mappedMikey            : std_logic;
   signal mappedROM              : std_logic;
   signal mappedVector           : std_logic;
   signal mappedreg              : std_logic_vector(7 downto 0);
            
   signal ROM_address            : std_logic_vector(8 downto 0);
   signal ROM_data               : std_logic_vector(7 downto 0);
   signal ROM_lastBank           : std_logic := '0';
            
   -- 64kbyte ram    
   signal RAM_address            : std_logic_vector(15 downto 0);
   signal RAM_dataWrite          : std_logic_vector(7 downto 0);
   signal RAM_WE                 : std_logic;
   signal RAM_WE_muxed           : std_logic;
   signal RAM_dataRead           : std_logic_vector(7 downto 0);
   signal RAM_lastBank           : unsigned(7 downto 0) := (others => '0');
   
   signal RAMB_address           : std_logic_vector(15 downto 0);
   signal RAMB_data              : std_logic_vector(7 downto 0);
   signal RAMB_we                : std_logic;
      
   -- 512byte reg shadow ram   
   signal RAMShadowA_address     : std_logic_vector(8 downto 0);
   signal RAMShadowB_address     : std_logic_vector(8 downto 0);
   signal RAMShadowA_WE          : std_logic;
      
   signal wait_cnt               : integer range 0 to 1 := 0;
         
   -- savestates     
   signal SS_MEMORY              : std_logic_vector(REG_SAVESTATE_MEMORY.upper downto REG_SAVESTATE_MEMORY.lower);
   signal SS_MEMORY_BACK         : std_logic_vector(REG_SAVESTATE_MEMORY.upper downto REG_SAVESTATE_MEMORY.lower);

begin 

   iSS_MEMORY : entity work.eReg_SS generic map ( REG_SAVESTATE_MEMORY ) port map (clk, SSBUS_Din, SSBUS_Adr, SSBUS_wren, SSBUS_rst, SSBUS_Dout, SS_MEMORY_BACK, SS_MEMORY); 

   RAM_address <= std_logic_vector(to_unsigned(DMA_RAM_address, 16)) when cpu_idle = '1' and dma_active = '1' else 
                  std_logic_vector(to_unsigned(GPU_RAM_address, 16)) when cpu_idle = '1' and dma_active = '0' else
                  std_logic_vector(bus_addr);
                  
   RAM_WE_muxed <= '0'         when cpu_idle = '1' and dma_active = '1' else 
                   GPURAM_wren when cpu_idle = '1' and dma_active = '0' else
                   RAM_WE;
                  
   RAM_dataWrite <= GPURAM_dataWrite when cpu_idle = '1' else 
                    bus_datawrite;

   RAMB_address <= std_logic_vector(to_unsigned(bs93_addr, 16)) when bs93_wren = '1' else SSMEM_Addr;
   RAMB_data    <= bs93_data                                    when bs93_wren = '1' else SSMEM_WriteData;
   RAMB_we      <= '1'                                          when bs93_wren = '1' else SSMEM_WrEn(1);
   
   iram: entity work.dpram
   generic map
   (
       addr_width => 16,
       data_width => 8
   )
   port map
   (
      clock_a      => clk,
      clken_a     => ce,
      address_a   => RAM_address,
      data_a      => RAM_dataWrite,
      wren_a      => RAM_WE_muxed,
      q_a         => RAM_dataRead,

      clock_b      => clk,
      address_b   => RAMB_address,
      data_b      => RAMB_data,
      wren_b      => RAMB_we,
      q_b         => SSMEM_ReadData_RAM
   );
   
   RAMShadowA_address <= std_logic_vector(bus_addr(8 downto 0));
   
   RAMShadowB_address <= SSMEM_Addr(8 downto 0);
   
   ireg_shadow: entity work.dpram
   generic map
   (
       addr_width => 9,
       data_width => 8
   )
   port map
   (
      clock_a      => clk,
      address_a   => RAMShadowA_address,
      data_a      => bus_datawrite,
      wren_a      => RAMShadowA_WE,
      q_a         => open,

      clock_b      => clk,
      address_b   => RAMShadowB_address,
      data_b      => SSMEM_WriteData,
      wren_b      => SSMEM_WrEn(0),
      q_b         => SSMEM_ReadData_REG
   );
   
   
   ilynxboot : entity work.lynxboot
   port map
   (
      clk         => clk,
      address     => ROM_address,
      data        => ROM_data,
      bios_wraddr => bios_wraddr,
      bios_wrdata => bios_wrdata,
      bios_wr     => bios_wr
   );
      
   mappedreg <= x"0"  & (not mappedVector) & (not mappedROM) & (not mappedMikey) & (not mappedSuzy);
  
   ROM_address <= std_logic_vector(bus_addr(8 downto 0));
   
   DMAGPURAM_dataRead <= RAM_dataRead;
   
   cart_strobe0 <= '1' when (bus_request = '1' and bus_rnw = '1' and mappedSuzy  = '1' and bus_addr = 16#FCB2#) else '0';
   cart_strobe1 <= '1' when (bus_request = '1' and bus_rnw = '1' and mappedSuzy  = '1' and bus_addr = 16#FCB3#) else '0';
   
   serdat_read  <= '1' when (bus_request = '1' and bus_rnw = '1' and mappedMikey = '1' and bus_addr = 16#FD8D#) else '0';
  
   SS_MEMORY_BACK(3 downto 0) <= mappedreg(3 downto 0);
  
   process (clk)
   begin
      if rising_edge(clk) then
      
         if (reset = '1') then  
            
            state           <= IDLE;
            mappedSuzy      <= not SS_MEMORY(0); -- '1';
            mappedMikey     <= not SS_MEMORY(1); -- '1';
            mappedROM       <= not SS_MEMORY(2); -- '1';
            mappedVector    <= not SS_MEMORY(3); -- '1';
            
         elsif (SSMEM_WrEn(0) = '1') then
         
            RegBus_wren <= '1';
            RegBus_Adr  <= std_logic_vector(SSMEM_Addr(8 downto 0));
            RegBus_Din  <= SSMEM_WriteData;

         elsif (ce = '1') then
            
            bus_done      <= '0';
            RAM_WE        <= '0';
            RAMShadowA_WE <= '0';
            RegBus_wren   <= '0';
            
            if (wait_cnt > 0) then
               wait_cnt <= wait_cnt - 1;
            end if;
            
            case state is
         
               when IDLE =>
                  if (bus_request = '1') then
                     wait_cnt <= 1;
                     
                     if (bus_addr = x"FFF9") then
                        if (bus_rnw = '1') then
                           state <= READ_MAPPEDREG;
                        else
                           mappedSuzy   <= not bus_datawrite(0);
                           mappedMikey  <= not bus_datawrite(1);
                           mappedROM    <= not bus_datawrite(2);
                           mappedVector <= not bus_datawrite(3); 
                           state <= WRITE_WAIT;
                        end if;
                        
                     elsif ((mappedSuzy = '1' and bus_addr >= 16#FC00# and bus_addr < 16#FCFF#) or (mappedMikey = '1' and bus_addr >= 16#FD00# and bus_addr < 16#FDFF#)) then -- suzy & mikey
                        if (bus_rnw = '1') then
                           RegBus_Adr    <= std_logic_vector(bus_addr(8 downto 0));
                           if (bus_addr = 16#FCB2# or bus_addr = 16#FCB3#) then
                              state <= READ_CART;
                           else
                              state <= READ_REG;
                           end if;
                        else
                           state         <= WRITE_WAIT;
                           RAMShadowA_WE <= '1';
                           RegBus_wren   <= '1';
                           RegBus_Adr    <= std_logic_vector(bus_addr(8 downto 0));
                           RegBus_Din    <= bus_datawrite;
                        end if;
                           
                     elsif ((bus_addr >= 16#FFFA# and mappedVector = '1') or (bus_addr >= 16#FE00# and bus_addr < 16#FFF9# and mappedROM = '1')) then
                        if (bus_rnw = '1') then
                           if (ROM_lastBank = ROM_address(8)) then
                              wait_cnt <= 0;
                           end if;
                           ROM_lastBank <= ROM_address(8);
                           state        <= READ_ROM;
                        else
                           state <= WRITE_WAIT;
                        end if;
                           
                     else --if (bus_addr < 16#FC00#)
                        if (bus_rnw = '1') then
                           if (RAM_lastBank = bus_addr(15 downto 8)) then
                              wait_cnt <= 0;
                           end if;
                           RAM_lastBank <= bus_addr(15 downto 8); -- possible it must invalidate when access from DMA/GPU happened?
                           state        <= READ_RAM;
                           RAMaccess    <= '1';
                        else
                           state  <= WRITE_WAIT;
                           RAM_WE <= '1';
                        end if;
                        
                     end if;
                  end if;
                  
               when READ_MAPPEDREG =>
                  bus_dataread <= mappedreg;
                  if (wait_cnt = 0) then
                     state    <= IDLE;
                     bus_done <= '1';
                  end if;
               
               when READ_REG =>
                  bus_dataread <= RegBus_Dout;
                  if (wait_cnt = 0) then
                     state    <= IDLE;
                     bus_done <= '1';
                  end if;
               
               when READ_ROM =>
                  bus_dataread <= ROM_data;
                  if (wait_cnt = 0) then
                     state        <= IDLE;
                     bus_done     <= '1';
                  end if;
               
               when READ_RAM =>
                  if (cheatOverwrite = '1') then
                     bus_dataread <= cheatData;
                  else
                     bus_dataread <= RAM_dataRead;
                  end if;
                  if (wait_cnt = 0) then
                     state     <= IDLE;
                     bus_done  <= '1';
                     RAMaccess <= '0';
                  end if;
                  
               when READ_CART =>
                  bus_dataread <= RegBus_Dout;
                  if (wait_cnt = 0 and cart_wait = '0') then
                     state    <= IDLE;
                     bus_done <= '1';
                  end if;
                  
               when WRITE_WAIT =>
                  if (wait_cnt = 0) then
                     state    <= IDLE;
                     bus_done <= '1';
                  end if;
                  
            end case;
            
         end if;
      
      end if;
   end process;
   

end architecture;





