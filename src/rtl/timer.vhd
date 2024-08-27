library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pexport.all;
use work.pRegisterBus.all;
use work.pReg_mikey.all;
use work.pBus_savestates.all;
use work.pReg_savestates.all; 

entity timer is
   port 
   (
      clk            : in  std_logic;
      ce             : in  std_logic;
      reset          : in  std_logic;
      fastforward    : in  std_logic;
      turbo          : in  std_logic;
                     
      RegBus_Din     : in  std_logic_vector(BUS_buswidth-1 downto 0);
      RegBus_Adr     : in  std_logic_vector(BUS_busadr-1 downto 0);
      RegBus_wren    : in  std_logic;
      RegBus_rst     : in  std_logic;
      RegBus_Dout    : out std_logic_vector(BUS_buswidth-1 downto 0);
                     
      irq_serial     : in  std_logic;
      IRQ_out        : out std_logic; 
      IRQ_clr        : out std_logic; 
      
      displayLine    : out std_logic;   
      frameEnd       : out std_logic;
      serialNewTx    : out std_logic;
      countup7       : out std_logic;
                        
      debugout       : out t_exporttimer;
      debugout16     : out std_logic_vector(15 downto 0);
         
      -- savestates        
      SSBUS_Din      : in  std_logic_vector(SSBUS_buswidth-1 downto 0);
      SSBUS_Adr      : in  std_logic_vector(SSBUS_busadr-1 downto 0);
      SSBUS_wren     : in  std_logic;
      SSBUS_rst      : in  std_logic;
      SSBUS_Dout     : out std_logic_vector(SSBUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of timer is
   
   -- register 
   type t_reg_wired_or is array(0 to 9) of std_logic_vector(7 downto 0);
   signal reg_wired_or : t_reg_wired_or;
   
   signal Reg_INTRST : std_logic_vector(INTRST.upper downto INTRST.lower) := (others => '0');
   signal Reg_INTSET : std_logic_vector(INTSET.upper downto INTSET.lower) := (others => '0');
   
   signal Reg_INTRST_written : std_logic;
   signal Reg_INTSET_written : std_logic;
   
   -- internal
   signal timerticks : std_logic_vector(0 to 7);
   signal IRQ_single : std_logic_vector(7 downto 0); 
   
   signal irq_status : std_logic_vector(7 downto 0);
   signal newstatus  : std_logic_vector(7 downto 0);
   signal irq_onbits : std_logic_vector(7 downto 0);
   
   -- savestates
   type t_ss_wired_or is array(0 to 8) of std_logic_vector(63 downto 0);
   signal ss_wired_or : t_ss_wired_or;
   
   signal SS_IRQ        : std_logic_vector(REG_SAVESTATE_IRQ.upper downto REG_SAVESTATE_IRQ.lower);
   signal SS_IRQ_BACK   : std_logic_vector(REG_SAVESTATE_IRQ.upper downto REG_SAVESTATE_IRQ.lower);
 
begin 

   iSS_IRQ : entity work.eReg_SS generic map ( REG_SAVESTATE_IRQ ) port map (clk, SSBUS_Din, SSBUS_Adr, SSBUS_wren, SSBUS_rst, ss_wired_or(8), SS_IRQ_BACK, SS_IRQ); 

   iReg_INTRST : entity work.eReg generic map ( INTRST ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(8), irq_status, Reg_INTRST, Reg_INTRST_written);  
   iReg_INTSET : entity work.eReg generic map ( INTSET ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(9), irq_status, Reg_INTSET, Reg_INTSET_written);  

   displayLine <= timerticks(0);
   frameEnd    <= timerticks(2);
   serialNewTx <= timerticks(4);
   
   process (reg_wired_or)
      variable wired_or : std_logic_vector(7 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      RegBus_Dout <= wired_or;
   end process;
   
   process (ss_wired_or)
      variable wired_or : std_logic_vector(63 downto 0);
   begin
      wired_or := ss_wired_or(0);
      for i in 1 to (ss_wired_or'length - 1) loop
         wired_or := wired_or or ss_wired_or(i);
      end loop;
      SSBUS_Dout <= wired_or;
   end process;

   itimer_module0 : entity work.timer_module 
   generic map ( 0, TIM0BKUP, TIM0CTLA, TIM0CNT, TIM0CTLB )                                  
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
      RegBus_Dout       => reg_wired_or(0),
         
      --savestate_bus     : inout proc_bus_gb_type;

      countup_in        => '0',
      tick              => timerticks(0),
      IRQ_out           => IRQ_single(0),
      irq_onBit         => irq_onbits(0),
      debugout          => debugout(0),
      debugout_pre      => debugout16,

      SSBUS_Din         => SSBUS_Din, 
      SSBUS_Adr         => SSBUS_Adr, 
      SSBUS_wren        => SSBUS_wren,
      SSBUS_rst         => SSBUS_rst, 
      SSBUS_Dout        => ss_wired_or(0)
   );
   
   itimer_module1 : entity work.timer_module 
   generic map ( 1, TIM1BKUP, TIM1CTLA, TIM1CNT, TIM1CTLB )                                  
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
      RegBus_Dout       => reg_wired_or(1),
         
      --savestate_bus     : inout proc_bus_gb_type;

      countup_in        => '0', -- audio 3
      tick              => timerticks(1),
      IRQ_out           => IRQ_single(1),
      irq_onBit         => irq_onbits(1),
      debugout          => debugout(1),

      SSBUS_Din         => SSBUS_Din, 
      SSBUS_Adr         => SSBUS_Adr, 
      SSBUS_wren        => SSBUS_wren,
      SSBUS_rst         => SSBUS_rst, 
      SSBUS_Dout        => ss_wired_or(1)
   );
   
   itimer_module2 : entity work.timer_module 
   generic map ( 2, TIM2BKUP, TIM2CTLA, TIM2CNT, TIM2CTLB )                                  
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
         
      --savestate_bus     : inout proc_bus_gb_type;

      countup_in        => timerticks(0),
      tick              => timerticks(2),
      IRQ_out           => IRQ_single(2),
      irq_onBit         => irq_onbits(2),
      debugout          => debugout(2),

      SSBUS_Din         => SSBUS_Din, 
      SSBUS_Adr         => SSBUS_Adr, 
      SSBUS_wren        => SSBUS_wren,
      SSBUS_rst         => SSBUS_rst, 
      SSBUS_Dout        => ss_wired_or(2)
   );
   
   itimer_module3 : entity work.timer_module 
   generic map ( 3, TIM3BKUP, TIM3CTLA, TIM3CNT, TIM3CTLB )                                  
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
      RegBus_Dout       => reg_wired_or(3),
         
      --savestate_bus     : inout proc_bus_gb_type;

      countup_in        => timerticks(1),
      tick              => timerticks(3),
      IRQ_out           => IRQ_single(3),
      irq_onBit         => irq_onbits(3),
      debugout          => debugout(3),

      SSBUS_Din         => SSBUS_Din, 
      SSBUS_Adr         => SSBUS_Adr, 
      SSBUS_wren        => SSBUS_wren,
      SSBUS_rst         => SSBUS_rst, 
      SSBUS_Dout        => ss_wired_or(3)
   );
   
   itimer_module4 : entity work.timer_module 
   generic map ( 4, TIM4BKUP, TIM4CTLA, TIM4CNT, TIM4CTLB )                                  
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
      RegBus_Dout       => reg_wired_or(4),
         
      --savestate_bus     : inout proc_bus_gb_type;

      countup_in        => timerticks(2),
      tick              => timerticks(4),
      IRQ_out           => open,
      irq_onBit         => irq_onbits(4),
      debugout          => debugout(4),

      SSBUS_Din         => SSBUS_Din, 
      SSBUS_Adr         => SSBUS_Adr, 
      SSBUS_wren        => SSBUS_wren,
      SSBUS_rst         => SSBUS_rst, 
      SSBUS_Dout        => ss_wired_or(4)
   );
   
   IRQ_single(4) <= irq_serial;
   
   
   itimer_module5 : entity work.timer_module 
   generic map ( 5, TIM5BKUP, TIM5CTLA, TIM5CNT, TIM5CTLB )                                  
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
      RegBus_Dout       => reg_wired_or(5),
         
      --savestate_bus     : inout proc_bus_gb_type;

      countup_in        => timerticks(3),
      tick              => timerticks(5),
      IRQ_out           => IRQ_single(5),
      irq_onBit         => irq_onbits(5),
      debugout          => debugout(5),

      SSBUS_Din         => SSBUS_Din, 
      SSBUS_Adr         => SSBUS_Adr, 
      SSBUS_wren        => SSBUS_wren,
      SSBUS_rst         => SSBUS_rst, 
      SSBUS_Dout        => ss_wired_or(5)
   );
   
   itimer_module6 : entity work.timer_module 
   generic map ( 6, TIM6BKUP, TIM6CTLA, TIM6CNT, TIM6CTLB )                                  
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
      RegBus_Dout       => reg_wired_or(6),
         
      --savestate_bus     : inout proc_bus_gb_type;

      countup_in        => '0',
      tick              => timerticks(6),
      IRQ_out           => IRQ_single(6),
      irq_onBit         => irq_onbits(6),
      debugout          => debugout(6),

      SSBUS_Din         => SSBUS_Din, 
      SSBUS_Adr         => SSBUS_Adr, 
      SSBUS_wren        => SSBUS_wren,
      SSBUS_rst         => SSBUS_rst, 
      SSBUS_Dout        => ss_wired_or(6)
   );
   
   itimer_module7 : entity work.timer_module 
   generic map ( 7, TIM7BKUP, TIM7CTLA, TIM7CNT, TIM7CTLB )                                  
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
      RegBus_Dout       => reg_wired_or(7),
         
      --savestate_bus     : inout proc_bus_gb_type;

      countup_in        => timerticks(5),
      tick              => timerticks(7),
      IRQ_out           => IRQ_single(7),
      irq_onBit         => irq_onbits(7),
      debugout          => debugout(7),

      SSBUS_Din         => SSBUS_Din, 
      SSBUS_Adr         => SSBUS_Adr, 
      SSBUS_wren        => SSBUS_wren,
      SSBUS_rst         => SSBUS_rst, 
      SSBUS_Dout        => ss_wired_or(7)
   );
   
   SS_IRQ_BACK(7 downto 0) <= irq_status;
   
   newstatus <= irq_status and (not Reg_INTRST);
   
   IRQ_out <= '1' when (IRQ_single /= x"00") else
              '1' when (Reg_INTRST_written = '1' and ((newstatus and irq_onbits) /= x"00")) else '0';
              
   IRQ_clr <= Reg_INTRST_written;
   
   countup7 <= timerticks(7);
   
   process (clk)
   begin
      if rising_edge(clk) then
         if (reset = '1') then
         
           irq_status <= SS_IRQ(7 downto 0); --(others => '0');
      
         elsif (ce = '1') then
         
            irq_status <= irq_status or IRQ_single;
            
            if (Reg_INTRST_written = '1') then
               irq_status <= newstatus;
            end if;
            
            if (Reg_INTSET_written = '1') then
               irq_status <= irq_status or Reg_INTSET;
            end if;
            
            
         end if;
      end if;
   end process;
   

end architecture;





