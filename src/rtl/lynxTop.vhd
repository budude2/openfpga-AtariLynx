library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.pexport.all;
use work.pRegisterBus.all;
use work.pBus_savestates.all;

entity LynxTop is
   generic 
   (
      is_simu : std_logic := '0'
   );
   port
   (
      clk                        : in  std_logic; -- 64Mhz -> 1/4 CE
      reset_in                   : in  std_logic;
      pause_in                   : in  std_logic;
      
      -- rom
      rom_addr                   : out std_logic_vector(19 downto 0);
      rom_byte                   : in  std_logic_vector( 7 downto 0);
      rom_req                    : out std_logic;
      rom_ack                    : in  std_logic;
      
      romsize                    : in  std_logic_vector(19 downto 0);
      romwrite_data              : in  std_logic_vector(15 downto 0);
      romwrite_addr              : in  std_logic_vector(19 downto 0);
      romwrite_wren              : in  std_logic;

      -- bios
      bios_wraddr                : in  std_logic_vector(8 downto 0);
      bios_wrdata                : in  std_logic_vector(7 downto 0);
      bios_wr                    : in  std_logic;
      
      -- video
      pixel_out_addr             : out integer range 0 to 16319;       -- address for framebuffer 
      pixel_out_data             : out std_logic_vector(11 downto 0);  -- RGB data for framebuffer 
      pixel_out_we               : out std_logic;                      -- new pixel for framebuffer 
      
      -- audio
      audio_l                    : out std_logic_vector(15 downto 0); -- 16 bit signed
      audio_r                    : out std_logic_vector(15 downto 0); -- 16 bit signed

      --settings
      fastforward                : in  std_logic;
      turbo                      : in  std_logic;
      speedselect                : in  std_logic_vector(1 downto 0); -- 0 = 400%, 1 = 133%, 2 = 160%, 3 = 200%
      fpsoverlay_on              : in  std_logic;
   
      -- JOYSTICK
      JoyUP                      : in  std_logic;
      JoyDown                    : in  std_logic;
      JoyLeft                    : in  std_logic;
      JoyRight                   : in  std_logic;
      Option1                    : in  std_logic;
      Option2                    : in  std_logic;
      KeyB                       : in  std_logic;
      KeyA                       : in  std_logic;
      KeyPause                   : in  std_logic;
   
      -- savestates
      increaseSSHeaderCount      : in  std_logic;
      save_state                 : in  std_logic;
      load_state                 : in  std_logic;
      savestate_number           : integer range 0 to 3;
      state_loaded               : out std_logic;
      
      SAVE_out_Din               : out std_logic_vector(63 downto 0);                                                   
      SAVE_out_Dout              : in  std_logic_vector(63 downto 0);                                           
      SAVE_out_Adr               : out std_logic_vector(25 downto 0);             
      SAVE_out_rnw               : out std_logic;          
      SAVE_out_ena               : out std_logic;          
      SAVE_out_be                : out std_logic_vector(7 downto 0);
      SAVE_out_done              : in  std_logic;          
      
      rewind_on                  : in  std_logic;
      rewind_active              : in  std_logic;
      
      -- cheats
      cheat_clear                : in  std_logic;
      cheats_enabled             : in  std_logic;
      cheat_on                   : in  std_logic;
      cheat_in                   : in  std_logic_vector(127 downto 0);
      cheats_active              : out std_logic := '0'
   );
end entity;

architecture arch of LynxTop is

   signal pixel_addr             : integer range 0 to 16319 := 0;       
   signal pixel_we               : std_logic := '0';  

   -- clock
   signal ce_counter             : unsigned (1 downto 0) := (others => '0');
   signal ce                     : std_logic := '0';
   signal ce_fast                : std_logic := '0';
   signal fastcounter_1_33x      : integer range 0 to 2 := 0;
   signal fastcounter_1_6x       : integer range 0 to 4 := 0;
   signal fastcounter_2x         : std_logic := '0';
   
   -- register
   signal RegBus_Din             : std_logic_vector(BUS_buswidth-1 downto 0);
   signal RegBus_Adr             : std_logic_vector(BUS_busadr-1 downto 0);
   signal RegBus_wren            : std_logic;
   signal RegBus_rst             : std_logic;
   signal RegBus_Dout            : std_logic_vector(BUS_buswidth-1 downto 0);
   
   type t_reg_wired_or is array(0 to 8) of std_logic_vector(7 downto 0);
   signal reg_wired_or : t_reg_wired_or;
   
   -- cart
   signal cart_strobe0           : std_logic;
   signal cart_strobe1           : std_logic;
   signal cart_wait              : std_logic;
   signal cart_idle              : std_logic;
   
   -- timer
   signal IRQ_request            : std_logic; 
   signal IRQ_clear              : std_logic; 
   signal countup7               : std_logic; 
   
   -- Display DMA
   signal displayLine            : std_logic;
   signal frameEnd               : std_logic;
   
   signal dma_active             : std_logic;
   signal DMA_RAM_address        : integer range 0 to 65535;
   signal DMAGPU_RAM_dataRead    : std_logic_vector(7 downto 0);
   
   signal pixel_dma_addr         : integer range 0 to 16319;     
   signal pixel_dma_data         : std_logic_vector(11 downto 0);
   signal pixel_dma_we           : std_logic;                    

   signal pixel_x                : integer range 0 to 159;                    
   signal pixel_y                : integer range 0 to 101;                    
   signal HzcountBCD             : unsigned(7 downto 0);
   
   -- cheats
   signal RAMaccess              : std_logic;
   signal cheatOverwrite         : std_logic;
   signal cheatData               : std_logic_vector(7 downto 0);
   
   -- memorymux
   signal bus_request            : std_logic := '0';
   signal bus_rnw                : std_logic := '0';
   signal bus_addr               : unsigned(15 downto 0) := (others => '0');
   signal bus_datawrite          : std_logic_vector(7 downto 0) := (others => '0');
   signal bus_dataread           : std_logic_vector(7 downto 0);
   signal bus_done               : std_logic;
   
   -- CPU
   signal cpu_idle               : std_logic;

   signal cpu_bus_request        : std_logic;
   signal cpu_bus_rnw            : std_logic;
   signal cpu_bus_addr           : unsigned(15 downto 0);
   signal cpu_bus_datawrite      : std_logic_vector(7 downto 0);
   signal cpu_bus_dataread       : std_logic_vector(7 downto 0);
   signal cpu_bus_done           : std_logic;

   signal irqdisabled            : std_logic;
   signal irqpending             : std_logic;
   signal irqfinish              : std_logic;
   
   -- serial
   signal serdat_read            : std_logic;
   signal serialNewTx            : std_logic;
   signal irq_serial             : std_logic;
   
   -- gpu
   signal GPU_RAM_address        : integer range 0 to 65535;
   signal GPURAM_dataWrite       : std_logic_vector(7 downto 0);     
   signal GPURAM_wren            : std_logic;
   
   signal cpu_sleep              : std_logic;  
   signal gpu_idle               : std_logic;  
   
   signal fpscountBCD            : unsigned(7 downto 0);
   
   -- header
   signal bank0size              : std_logic_vector(15 downto 0);
   signal hasHeader              : std_logic;
   
   signal custom_PCAddr          : std_logic_vector(15 downto 0);
   signal custom_PCuse           : std_logic;
   
   signal bs93_addr              : integer range 0 to 65535;
   signal bs93_data              : std_logic_vector(7 downto 0);     
   signal bs93_wren              : std_logic;

   -- savestates
   signal reset                  : std_logic;
   signal sleep_savestate        : std_logic;
   signal sleep_rewind           : std_logic;
   signal system_idle            : std_logic;
   signal savestate_slow         : std_logic;
   
   type t_ss_wired_or is array(0 to 8) of std_logic_vector(63 downto 0);
   signal ss_wired_or : t_ss_wired_or;
   
   signal savestate_savestate    : std_logic; 
   signal savestate_loadstate    : std_logic; 
   signal savestate_address      : integer; 
   signal savestate_busy         : std_logic; 
   
   signal SSBUS_Din              : std_logic_vector(SSBUS_buswidth-1 downto 0);
   signal SSBUS_Adr              : std_logic_vector(SSBUS_busadr-1 downto 0);
   signal SSBUS_wren             : std_logic := '0';
   signal SSBUS_rst              : std_logic := '0';
   signal SSBUS_Dout             : std_logic_vector(SSBUS_buswidth-1 downto 0);
          
   signal SSMEM_Addr             : std_logic_vector(15 downto 0);
   signal SSMEM_WrEn             : std_logic_vector(1 downto 0);
   signal SSMEM_WriteData        : std_logic_vector(7 downto 0);
   signal SSMEM_ReadData_REG     : std_logic_vector(7 downto 0);
   signal SSMEM_ReadData_RAM     : std_logic_vector(7 downto 0);

   -- export
-- synthesis translate_off
   signal new_export             : std_logic;   
   signal cpu_done               : std_logic; 
   signal cpu_export             : cpu_export_type;
   signal dma_done               : std_logic;
   signal export_timer           : t_exporttimer;
   signal export_16              : std_logic_vector(15 downto 0);
-- synthesis translate_on

begin
   
   -- CE Generation
   process (clk)
   begin
      if rising_edge(clk) then
      
         if (fastcounter_1_33x < 2) then
            fastcounter_1_33x <= fastcounter_1_33x + 1;
         else
            fastcounter_1_33x <= 0;
         end if;
         
         if (fastcounter_1_6x < 4) then
            fastcounter_1_6x <= fastcounter_1_6x + 1;
         else
            fastcounter_1_6x <= 0;
         end if;
         
         fastcounter_2x    <= not fastcounter_2x;
      
         ce_fast <= '0';
         if (turbo = '1') then
            ce_fast <= '1';
         elsif (fastforward = '1') then
            case (speedselect) is
               when "00" =>                                                        ce_fast <= '1';         -- 400%
               when "01" => if (fastcounter_1_33x = 2)                        then ce_fast <= '1'; end if; -- 133%
               when "10" => if (fastcounter_1_6x = 2 or fastcounter_1_6x = 4) then ce_fast <= '1'; end if; -- 160%
               when "11" => if (fastcounter_2x = '1')                         then ce_fast <= '1'; end if; -- 200%
               when others => null;
            end case;
         end if; 
         
         if (reset = '1' or sleep_savestate = '1' or sleep_rewind = '1') then
            ce         <= '0';
            ce_counter <= (others => '0');
         elsif (pause_in = '0' or ce = '1') then
            ce_counter <= ce_counter + 1;
            ce <= '0'; 
            if (fastforward = '1' or turbo = '1') then
               if ((ce_counter = "11" and (savestate_slow = '1' or rewind_active = '1')) or (savestate_slow = '0' and rewind_active = '0' and ce_fast = '1')) then
                   ce <= '1';
               end if;
            elsif (ce_counter = "11" ) then 
               ce <= '1';
            end if;
         end if;
         
      end if;
   end process;
   
   
   -- register
   process (reg_wired_or)
      variable wired_or : std_logic_vector(7 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      RegBus_Dout <= wired_or;
   end process;
   
   idummyregs : entity work.dummyregs
   port map
   (
      clk          => clk,
      ce           => ce,
      reset        => reset,
                                 
      RegBus_Din   => RegBus_Din,
      RegBus_Adr   => RegBus_Adr,
      RegBus_wren  => RegBus_wren,
      RegBus_rst   => RegBus_rst,
      RegBus_Dout  => reg_wired_or(0)
   );
   
   -- cart
   icart : entity work.cart
   port map
   (
      clk            => clk,
      ce             => ce,
      reset          => reset,
      
      hasHeader      => hasHeader,
      bank0size      => bank0size,
      bank1size      => x"0000",
                        
      RegBus_Din     => RegBus_Din,
      RegBus_Adr     => RegBus_Adr,
      RegBus_wren    => RegBus_wren,
      RegBus_rst     => RegBus_rst,
      RegBus_Dout    => reg_wired_or(1),
      
      cart_strobe0   => cart_strobe0,
      cart_strobe1   => cart_strobe1,
      cart_wait      => cart_wait,
      cart_idle      => cart_idle,
      
      rom_addr       => rom_addr,
      rom_byte       => rom_byte,
      rom_req        => rom_req, 
      rom_ack        => rom_ack, 

      SSBUS_Din      => SSBUS_Din, 
      SSBUS_Adr      => SSBUS_Adr, 
      SSBUS_wren     => SSBUS_wren,
      SSBUS_rst      => SSBUS_rst, 
      SSBUS_Dout     => ss_wired_or(0)
   );
   
   -- timer
   itimer : entity work.timer
   port map
   (
      clk               => clk,        
      ce                => ce,         
      reset             => reset,      
      fastforward       => fastforward,
      turbo             => turbo,
                                
      RegBus_Din        => RegBus_Din, 
      RegBus_Adr        => RegBus_Adr, 
      RegBus_wren       => RegBus_wren,
      RegBus_rst        => RegBus_rst, 
      RegBus_Dout       => reg_wired_or(2),
                        
      irq_serial        => irq_serial,
      IRQ_out           => IRQ_request,
      IRQ_clr           => IRQ_clear,
      
      displayLine       => displayLine,
      frameEnd          => frameEnd,    
      serialNewTx       => serialNewTx,
      countup7          => countup7,
      
-- synthesis translate_off
      debugout          => export_timer,
      debugout16        => export_16,
-- synthesis translate_on

      SSBUS_Din         => SSBUS_Din, 
      SSBUS_Adr         => SSBUS_Adr, 
      SSBUS_wren        => SSBUS_wren,
      SSBUS_rst         => SSBUS_rst, 
      SSBUS_Dout        => ss_wired_or(1)
   );
   
   -- Display DMA
   idisplay_dma : entity work.display_dma
   port map
   (
      clk               => clk,        
      ce                => ce,         
      reset             => reset,      
                                
      RegBus_Din        => RegBus_Din, 
      RegBus_Adr        => RegBus_Adr, 
      RegBus_wren       => RegBus_wren,
      RegBus_rst        => RegBus_rst, 
      RegBus_Dout       => reg_wired_or(3),
      
      cpu_idle          => cpu_idle,
      displayLine       => displayLine,     
      frameEnd          => frameEnd,        
                           
      dma_active        => dma_active,  
      
-- synthesis translate_off
      dma_done          => dma_done,     
-- synthesis translate_on

      RAM_address       => DMA_RAM_address, 
      RAM_dataRead      => DMAGPU_RAM_dataRead,
                        
      pixel_out_addr    => pixel_dma_addr,
      pixel_out_data    => pixel_dma_data,
      pixel_out_we      => pixel_dma_we,  
      
      pixel_out_x       => pixel_x,  
      pixel_out_y       => pixel_y,  
      HzcountBCDout     => HzcountBCD,

      SSBUS_Din         => SSBUS_Din, 
      SSBUS_Adr         => SSBUS_Adr, 
      SSBUS_wren        => SSBUS_wren,
      SSBUS_rst         => SSBUS_rst, 
      SSBUS_Dout        => ss_wired_or(2) 
   );
   
   -- cheats
   ilynx_cheats : entity work.lynx_cheats
   port map
   (
      clk            => clk,
      reset          => reset_in,
                     
      cheat_clear    => cheat_clear,   
      cheats_enabled => cheats_enabled,
      cheat_on       => cheat_on,      
      cheat_in       => cheat_in,      
      cheats_active  => cheats_active, 
                     
      BusAddr        => cpu_bus_addr,
      RAMaccess      => RAMaccess,
      cheatOverwrite => cheatOverwrite,
      cheatData      => cheatData
   );
   
   -- Memory Mux
   bus_request   <= cpu_bus_request;
   bus_rnw       <= cpu_bus_rnw;     
   bus_addr      <= cpu_bus_addr;     
   bus_datawrite <= cpu_bus_datawrite;
   
   cpu_bus_dataread <= bus_dataread; 
   cpu_bus_done     <= bus_done;     
   
   imemorymux : entity work.memorymux
   port map
   (
      clk                  => clk,          
      ce                   => ce,           
      reset                => reset,        
                     
      bus_request          => bus_request,  
      bus_rnw              => bus_rnw,      
      bus_addr             => bus_addr,     
      bus_datawrite        => bus_datawrite,
      bus_dataread         => bus_dataread, 
      bus_done             => bus_done,
      
      RAMaccess            => RAMaccess,
      cheatOverwrite       => cheatOverwrite,
      cheatData            => cheatData,
      
      RegBus_Din           => RegBus_Din,
      RegBus_Adr           => RegBus_Adr,
      RegBus_wren          => RegBus_wren,
      RegBus_Dout          => RegBus_Dout,
   
      cpu_idle             => cpu_idle,
      dma_active           => dma_active,
      DMA_RAM_address      => DMA_RAM_address,
      GPU_RAM_address      => GPU_RAM_address,
      GPURAM_dataWrite     => GPURAM_dataWrite,  
      GPURAM_wren          => GPURAM_wren,     
      DMAGPURAM_dataRead   => DMAGPU_RAM_dataRead,
         
      cart_strobe0         => cart_strobe0,
      cart_strobe1         => cart_strobe1,
      cart_wait            => cart_wait,
      serdat_read          => serdat_read,
      
      bios_wraddr          => bios_wraddr,
      bios_wrdata          => bios_wrdata,
      bios_wr              => bios_wr, 

      bs93_addr            => bs93_addr,
      bs93_data            => bs93_data,
      bs93_wren            => bs93_wren,
         
      SSBUS_Din            => SSBUS_Din, 
      SSBUS_Adr            => SSBUS_Adr, 
      SSBUS_wren           => SSBUS_wren,
      SSBUS_rst            => SSBUS_rst, 
      SSBUS_Dout           => ss_wired_or(3),
      
      SSMEM_Addr           => SSMEM_Addr,        
      SSMEM_WrEn           => SSMEM_WrEn,        
      SSMEM_WriteData      => SSMEM_WriteData,   
      SSMEM_ReadData_REG   => SSMEM_ReadData_REG,
      SSMEM_ReadData_RAM   => SSMEM_ReadData_RAM
   );
   
   -- cpu
   icpu : entity work.cpu
   port map
   (
      clk               => clk,  
      ce                => ce,   
      reset             => reset,
   
      cpu_idle          => cpu_idle,
      dma_active        => dma_active,  
      cpu_sleep         => cpu_sleep,       
   
      bus_request       => cpu_bus_request,  
      bus_rnw           => cpu_bus_rnw,     
      bus_addr          => cpu_bus_addr,     
      bus_datawrite     => cpu_bus_datawrite,
      bus_dataread      => cpu_bus_dataread,
      bus_done          => cpu_bus_done,     
   
      irqrequest_in     => IRQ_request,    
      irqclear_in       => IRQ_clear,   
      irqdisabled       => irqdisabled,  
      irqpending        => irqpending,  
      irqfinish         => irqfinish, 

      load_savestate    => sleep_savestate,  
      custom_PCAddr     => custom_PCAddr,
      custom_PCuse      => custom_PCuse,       
            
-- synthesis translate_off
      cpu_done          => cpu_done,         
      cpu_export        => cpu_export,
-- synthesis translate_on

      SSBUS_Din         => SSBUS_Din, 
      SSBUS_Adr         => SSBUS_Adr, 
      SSBUS_wren        => SSBUS_wren,
      SSBUS_rst         => SSBUS_rst, 
      SSBUS_Dout        => ss_wired_or(4)
   );
   
   -- math
   imath : entity work.math
   port map
   (
      clk            => clk,  
      ce             => ce,   
      reset          => reset,
                     
      RegBus_Din     => RegBus_Din, 
      RegBus_Adr     => RegBus_Adr, 
      RegBus_wren    => RegBus_wren,
      RegBus_rst     => RegBus_rst, 
      RegBus_Dout    => reg_wired_or(4),
        
      SSBUS_Din      => SSBUS_Din,  
      SSBUS_Adr      => SSBUS_Adr,  
      SSBUS_wren     => SSBUS_wren, 
      SSBUS_rst      => SSBUS_rst,  
      SSBUS_Dout     => ss_wired_or(5)
   );
   
   -- joystick
   ijoypad: entity work.joypad
   port map
   (     
      clk            => clk,     
                                
      JoyUP          => JoyUP,   
      JoyDown        => JoyDown, 
      JoyLeft        => JoyLeft,
      JoyRight       => JoyRight,
      Option1        => Option1, 
      Option2        => Option2, 
      KeyB           => KeyB,    
      KeyA           => KeyA,    
      KeyPause       => KeyPause,
   
      RegBus_Din     => RegBus_Din, 
      RegBus_Adr     => RegBus_Adr, 
      RegBus_wren    => RegBus_wren,
      RegBus_rst     => RegBus_rst, 
      RegBus_Dout    => reg_wired_or(5)
   );
   
   -- serial
   iserial : entity work.serial
   port map
   (
      clk            => clk,  
      ce             => ce,   
      reset          => reset,
                     
      RegBus_Din     => RegBus_Din, 
      RegBus_Adr     => RegBus_Adr, 
      RegBus_wren    => RegBus_wren,
      RegBus_rst     => RegBus_rst, 
      RegBus_Dout    => reg_wired_or(6),  
      
      serdat_read    => serdat_read,
      serialNewTx    => serialNewTx,
      
      irq_serial     => irq_serial,
         
      -- savestates        
      SSBUS_Din      => SSBUS_Din,  
      SSBUS_Adr      => SSBUS_Adr,  
      SSBUS_wren     => SSBUS_wren, 
      SSBUS_rst      => SSBUS_rst,  
      SSBUS_Dout     => ss_wired_or(6)
   );
   
   -- gpu
   igpu : entity work.gpu
   generic map
   (
      is_simu => is_simu
   )
   port map
   (
      clk            => clk,  
      ce             => ce,   
      reset          => reset,
                     
      RegBus_Din     => RegBus_Din, 
      RegBus_Adr     => RegBus_Adr, 
      RegBus_wren    => RegBus_wren,
      RegBus_rst     => RegBus_rst, 
      RegBus_Dout    => reg_wired_or(7), 
      
      cpu_idle       => cpu_idle,  
      dma_active     => dma_active,
      cpu_sleep      => cpu_sleep, 
      load_savestate => sleep_savestate,
      gpu_idle       => gpu_idle,
      
      irqrequest_in  => IRQ_request,
      irqdisabled    => irqdisabled,  
      irqpending     => irqpending,  
      irqfinish      => irqfinish,    

      RAM_address    => GPU_RAM_address,
      RAM_dataWrite  => GPURAM_dataWrite,
      RAM_wren       => GPURAM_wren,
      RAM_dataRead   => DMAGPU_RAM_dataRead,
      
      fpscountBCDout => fpscountBCD,
                 
      -- savestates        
      SSBUS_Din      => SSBUS_Din,  
      SSBUS_Adr      => SSBUS_Adr,  
      SSBUS_wren     => SSBUS_wren, 
      SSBUS_rst      => SSBUS_rst,  
      SSBUS_Dout     => ss_wired_or(7)
   );
   
   --sound
   isound : entity work.sound
   port map
   (
      clk            => clk,        
      ce             => ce,         
      reset          => reset,      
      turbo          => turbo,
                     
      RegBus_Din     => RegBus_Din, 
      RegBus_Adr     => RegBus_Adr, 
      RegBus_wren    => RegBus_wren,
      RegBus_rst     => RegBus_rst, 
      RegBus_Dout    => reg_wired_or(8), 
                     
      countup7       => countup7,
                     
      audio_l        => audio_l,
      audio_r        => audio_r,
         
      -- savestates        
      SSBUS_Din      => SSBUS_Din,  
      SSBUS_Adr      => SSBUS_Adr,  
      SSBUS_wren     => SSBUS_wren, 
      SSBUS_rst      => SSBUS_rst,  
      SSBUS_Dout     => ss_wired_or(8)
   );
   
   -- fps overlay
   ifpsoverlay : entity work.fpsoverlay
   port map
   (
      clk            => clk,           
                                      
      overlay_on     => fpsoverlay_on,    
                                      
      pixel_out_addr => pixel_out_addr,
      pixel_out_data => pixel_out_data,
      pixel_out_we   => pixel_out_we,  
                                      
      pixel_in_addr  => pixel_dma_addr, 
      pixel_in_data  => pixel_dma_data, 
      pixel_in_we    => pixel_dma_we,   
                                      
      pixel_x        => pixel_x,       
      pixel_y        => pixel_y,       
      HzcountBCD     => HzcountBCD,    
      FPScountBCD    => FPScountBCD  
   );
   
   -- header
   iheader : entity work.header
   port map
   (
      clk            => clk,          
                                     
      romsize        => romsize,      
      romwrite_data  => romwrite_data,
      romwrite_addr  => romwrite_addr,
      romwrite_wren  => romwrite_wren,
                                     
      bank0size      => bank0size,    
      hasHeader      => hasHeader,
      
      custom_PCAddr  => custom_PCAddr,
      custom_PCuse   => custom_PCuse,
      
      bs93_addr      => bs93_addr,
      bs93_data      => bs93_data,
      bs93_wren      => bs93_wren
   );      
   
   -- savestates
   process (ss_wired_or)
      variable wired_or : std_logic_vector(63 downto 0);
   begin
      wired_or := ss_wired_or(0);
      for i in 1 to (ss_wired_or'length - 1) loop
         wired_or := wired_or or ss_wired_or(i);
      end loop;
      SSBUS_Dout <= wired_or;
   end process;
   
   system_idle <= '1' when (cpu_idle = '1' and gpu_idle = '1' and dma_active = '0' and cart_idle = '1') else '0';

   isavestates : entity work.savestates
   port map
   (
      clk                     => clk,
      ce                      => ce,
      reset_in                => reset_in,
      reset_out               => reset,
      RegBus_rst              => RegBus_rst,
            
      load_done               => state_loaded,
            
      increaseSSHeaderCount   => increaseSSHeaderCount,
      save                    => savestate_savestate,
      load                    => savestate_loadstate,
      savestate_address       => savestate_address,  
      savestate_busy          => savestate_busy,    

      system_idle             => system_idle,
      savestate_slow          => savestate_slow,
            
      BUS_Din                 => SSBUS_Din, 
      BUS_Adr                 => SSBUS_Adr, 
      BUS_wren                => SSBUS_wren,
      BUS_rst                 => SSBUS_rst, 
      BUS_Dout                => SSBUS_Dout,
            
      loading_savestate       => open,
      saving_savestate        => open,
      sleep_savestate         => sleep_savestate,
            
      Save_RAMAddr            => SSMEM_Addr,        
      Save_RAMWrEn            => SSMEM_WrEn,        
      Save_RAMWriteData       => SSMEM_WriteData,   
      Save_RAMReadData_REG    => SSMEM_ReadData_REG,
      Save_RAMReadData_RAM    => SSMEM_ReadData_RAM,
      
      bus_out_Din             => SAVE_out_Din,
      bus_out_Dout            => SAVE_out_Dout,
      bus_out_Adr             => SAVE_out_Adr,
      bus_out_rnw             => SAVE_out_rnw,
      bus_out_ena             => SAVE_out_ena,
      bus_out_be              => SAVE_out_be,
      bus_out_done            => SAVE_out_done
   );   
   
   istatemanager : entity work.statemanager
   generic map
   (
      Softmap_SaveState_ADDR   => 58720256,
      Softmap_Rewind_ADDR      => 33554432
   )
   port map
   (
      clk                 => clk,  
      ce                  => ce,  
      reset               => reset_in,
                         
      rewind_on           => rewind_on,    
      rewind_active       => rewind_active,
                        
      savestate_number    => savestate_number,
      save                => save_state,
      load                => load_state,
                       
      sleep_rewind        => sleep_rewind,
      vsync               => frameEnd,
      system_idle         => system_idle,
                 
      request_savestate   => savestate_savestate,
      request_loadstate   => savestate_loadstate,
      request_address     => savestate_address,  
      request_busy        => savestate_busy    
   );
   
   -- export
-- synthesis translate_off
   gexport : if is_simu = '1' generate
   begin
   
      new_export <= (cpu_done and not dma_active) or dma_done;
      
      iexport : entity work.export
      port map
      (
         clk            => clk,
         ce             => ce,
         reset          => reset,
         
         new_export     => new_export,
         export_cpu     => cpu_export,
         export_timer   => export_timer,
         
         export_8       => x"00",
         export_16      => x"0000", --export_16,
         export_32      => x"00000000"
      );
   
   
   end generate;
-- synthesis translate_on
   

end architecture;
