library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegisterBus.all;
use work.pBus_savestates.all;
use work.pReg_savestates.all; 

entity timer_module is
   generic
   (
      index          : integer;
      BKUP           : regmap_type;
      CTLA           : regmap_type;
      CNT            : regmap_type;
      CTLB           : regmap_type
   );
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

      countup_in     : in    std_logic;
      tick           : out   std_logic := '0';
      IRQ_out        : out   std_logic := '0';  
      IRQ_onBit      : out   std_logic;  
      debugout       : out   std_logic_vector(7 downto 0);
      debugout_pre   : out   std_logic_vector(15 downto 0);
         
      -- savestates        
      SSBUS_Din      : in  std_logic_vector(SSBUS_buswidth-1 downto 0);
      SSBUS_Adr      : in  std_logic_vector(SSBUS_busadr-1 downto 0);
      SSBUS_wren     : in  std_logic;
      SSBUS_rst      : in  std_logic;
      SSBUS_Dout     : out std_logic_vector(SSBUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of timer_module is

   -- register
   signal Reg_BKUP : std_logic_vector(BKUP.upper downto BKUP.lower) := (others => '0');
   signal Reg_CTLA : std_logic_vector(CTLA.upper downto CTLA.lower) := (others => '0');
   signal Reg_CNT  : std_logic_vector(CNT .upper downto CNT .lower) := (others => '0');
   signal Reg_CTLB : std_logic_vector(CTLB.upper downto CTLB.lower) := (others => '0');

   signal Reg_CTLA_written : std_logic;     
   signal Reg_CNT_written  : std_logic;     
   signal Reg_CTLB_written : std_logic; 
   
   signal Reg_CTLA_written_delay : std_logic_vector(2 downto 0); 

   signal Reg_CNT_readback  : std_logic_vector(7 downto 0) := (others => '0');   
   signal Reg_CTLB_readback : std_logic_vector(7 downto 0) := (others => '0');   

   type t_reg_wired_or is array(0 to 3) of std_logic_vector(7 downto 0);
   signal reg_wired_or : t_reg_wired_or;   

   signal timer_on         : std_logic;
   signal timer_reload     : std_logic;
   signal timer_enaIRQ     : std_logic;

   -- internal         
   signal counter          : unsigned(7 downto 0) := (others => '0');
   signal prescalecounter  : unsigned(13 downto 0) := (others => '0');
   signal prescaleborder   : integer range 1 to 8191 := 15;
   signal timer_done       : std_logic := '0';
   signal borrow_out       : std_logic := '0';
   signal turbocnt         : unsigned(1 downto 0) := (others => '0');
   
   -- savestates
   signal SS_TIMER         : std_logic_vector(REG_SAVESTATE_TIMER.upper downto REG_SAVESTATE_TIMER.lower);
   signal SS_TIMER_BACK    : std_logic_vector(REG_SAVESTATE_TIMER.upper downto REG_SAVESTATE_TIMER.lower);

begin 

   iSS_TIMER : entity work.eReg_SS generic map ( REG_SAVESTATE_TIMER, index ) port map (clk, SSBUS_Din, SSBUS_Adr, SSBUS_wren, SSBUS_rst, SSBUS_Dout, SS_TIMER_BACK, SS_TIMER); 


   iReg_BKUP : entity work.eReg generic map ( BKUP ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(0), Reg_BKUP,          Reg_BKUP);  
   iReg_CTLA : entity work.eReg generic map ( CTLA ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(1), Reg_CTLA,          Reg_CTLA, Reg_CTLA_written);  
   iReg_CNT  : entity work.eReg generic map ( CNT  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(2), Reg_CNT_readback,  Reg_CNT , Reg_CNT_written);  
   iReg_CTLB : entity work.eReg generic map ( CTLB ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(3), Reg_CTLB_readback, Reg_CTLB, Reg_CTLB_written);  
   
   process (reg_wired_or)
      variable wired_or : std_logic_vector(7 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      RegBus_Dout <= wired_or;
   end process;
   
   Reg_CTLB_readback <= Reg_CTLB(7 downto 4) & timer_done & Reg_CTLB(2) & countup_in & borrow_out;
   
   Reg_CNT_readback <= std_logic_vector(counter);
   debugout     <= Reg_CNT_readback;
   debugout_pre <= "00" & std_logic_vector(prescalecounter);
   
   tick <= borrow_out;
   
   timer_reload <= Reg_CTLA(4);
   timer_enaIRQ <= Reg_CTLA(7);
   
   IRQ_onBit <= timer_enaIRQ;
   
   SS_TIMER_BACK(15 downto  0) <= "00" & std_logic_vector(prescalecounter);
   SS_TIMER_BACK(23 downto 16) <= std_logic_vector(counter);        
   SS_TIMER_BACK(          24) <= timer_on;       
   SS_TIMER_BACK(          25) <= timer_done;     
   SS_TIMER_BACK(          26) <= borrow_out;     
   
   process (clk)
      variable ticked : std_logic;
   begin
      if rising_edge(clk) then
         
         if (index = 4) then
            case (to_integer(unsigned(Reg_CTLA(2 downto 0)))) is
               when 0 => prescaleborder <= 127;
               when 1 => prescaleborder <= 255;
               when 2 => prescaleborder <= 511;
               when 3 => prescaleborder <= 1023;
               when 4 => prescaleborder <= 2047;
               when 5 => prescaleborder <= 4095;
               when 6 => prescaleborder <= 8191;
               when others => null;
            end case;
         else
            case (to_integer(unsigned(Reg_CTLA(2 downto 0)))) is
               when 0 => prescaleborder <= 15;
               when 1 => prescaleborder <= 31;
               when 2 => prescaleborder <= 63;
               when 3 => prescaleborder <= 127;
               when 4 => prescaleborder <= 255;
               when 5 => prescaleborder <= 511;
               when 6 => prescaleborder <= 1023;
               when others => null;
            end case;
         end if;
            
         if (reset = '1') then
      
            prescalecounter  <= unsigned(SS_TIMER(13 downto  0)); -- (others => '0');
            counter          <= unsigned(SS_TIMER(23 downto 16)); -- (others => '0');
            timer_on         <= SS_TIMER(24); -- '0';
            timer_done       <= SS_TIMER(25); -- '0';
            borrow_out       <= SS_TIMER(26); -- '0';
      
         elsif (ce = '1') then
         
            if (Reg_CTLA_written = '1') then
               if (fastforward = '1') then -- requires because register bus doesn't use clock enable
                  Reg_CTLA_written_delay <= '0' & '1' & Reg_CTLA_written_delay(1);
               else
                  Reg_CTLA_written_delay <= '1' & Reg_CTLA_written_delay(2 downto 1);
               end if;
            else
               Reg_CTLA_written_delay <= '0' & Reg_CTLA_written_delay(2 downto 1);
            end if;
            
            --work
            ticked := '0';
            turbocnt <= turbocnt + 1;
            
            if (timer_on = '1') then
               if (turbo = '0' or turbocnt = 0) then
                  if (prescalecounter >= prescaleborder) then
                     prescalecounter <= (others => '0');
                     if (Reg_CTLA(2 downto 0) /= "111") then
                        ticked  := '1';
                     end if;
                  else
                     prescalecounter <= prescalecounter + 1;
                  end if;
               end if;
            end if;
            
            borrow_out <= '0';
            IRQ_out    <= '0';
            
            if (timer_on = '1' and (timer_reload = '1' or timer_done = '0')) then

               if (Reg_CTLA(2 downto 0) = "111" and countup_in = '1') then
                  ticked := '1';
               end if;
      
               if (ticked = '1') then
                  counter <= counter - 1;
                  if (counter = x"00") then
                  
                     borrow_out <= '1';
                     timer_done <= '1';
                     
                     if (timer_reload = '1') then
                        counter <= unsigned(Reg_BKUP);
                     elsif (index = 1 or index = 3 or index = 5 or index = 7) then
                        counter <= (others => '0');
                     end if;
                     
                     if (timer_enaIRQ = '1' and index /= 4) then
                        IRQ_out <= '1';
                     end if;
                  end if;
               end if;
            end if;
            
            -- set_settings
            if (Reg_CTLA_written_delay(0) = '1') then
               timer_on <= Reg_CTLA(3);
               if (Reg_CTLA(6) = '1') then
                  timer_done <= '0';
               end if;
               
               if (Reg_CTLA(6) = '1' or Reg_CTLA(3) = '1') then
                  prescalecounter  <= (others => '0');
               end if;
            end if;
            
            if (Reg_CTLB_written = '1') then
               timer_done <= Reg_CTLB(3);
            end if;
            
            if (Reg_CNT_written = '1') then
               counter <= unsigned(Reg_CNT);
            end if;
            
         end if;
      
      end if;
   end process;
  

end architecture;





