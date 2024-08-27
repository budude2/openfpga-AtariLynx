library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegisterBus.all;
use work.pBus_savestates.all;
use work.pReg_savestates.all; 

entity sound_module is
   generic
   (
      index          : integer;
      VOL            : regmap_type;
      SHFTFB         : regmap_type;
      OUTVAL         : regmap_type;
      L8SHFT         : regmap_type;
      TBACK          : regmap_type;
      CTL            : regmap_type;
      COUNT          : regmap_type;
      MISC           : regmap_type
   );
   port 
   (
      clk            : in  std_logic;
      ce             : in  std_logic;
      reset          : in  std_logic;
      turbo          : in  std_logic;
                     
      RegBus_Din     : in  std_logic_vector(BUS_buswidth-1 downto 0);
      RegBus_Adr     : in  std_logic_vector(BUS_busadr-1 downto 0);
      RegBus_wren    : in  std_logic;
      RegBus_rst     : in  std_logic;
      RegBus_Dout    : out std_logic_vector(BUS_buswidth-1 downto 0);   

      countup_in     : in  std_logic;
      tick           : out std_logic := '0';
      soundout       : out signed(7 downto 0) := (others => '0');
         
      -- savestates        
      SSBUS_Din      : in  std_logic_vector(SSBUS_buswidth-1 downto 0);
      SSBUS_Adr      : in  std_logic_vector(SSBUS_busadr-1 downto 0);
      SSBUS_wren     : in  std_logic;
      SSBUS_rst      : in  std_logic;
      SSBUS_Dout     : out std_logic_vector(SSBUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of sound_module is

   -- register
   signal Reg_VOL    : std_logic_vector(VOL   .upper downto VOL   .lower) := (others => '0');
   signal Reg_SHFTFB : std_logic_vector(SHFTFB.upper downto SHFTFB.lower) := (others => '0');
   signal Reg_OUTVAL : std_logic_vector(OUTVAL.upper downto OUTVAL.lower) := (others => '0');
   signal Reg_L8SHFT : std_logic_vector(L8SHFT.upper downto L8SHFT.lower) := (others => '0');
   signal Reg_TBACK  : std_logic_vector(TBACK .upper downto TBACK .lower) := (others => '0');
   signal Reg_CTL    : std_logic_vector(CTL   .upper downto CTL   .lower) := (others => '0');
   signal Reg_COUNT  : std_logic_vector(COUNT .upper downto COUNT .lower) := (others => '0');
   signal Reg_MISC   : std_logic_vector(MISC  .upper downto MISC  .lower) := (others => '0');
   
   signal Reg_SHFTFB_written : std_logic;     
   signal Reg_OUTVAL_written : std_logic;     
   signal Reg_L8SHFT_written : std_logic;         
   signal Reg_CTL_written    : std_logic;     
   signal Reg_COUNT_written  : std_logic;     
   signal Reg_MISC_written   : std_logic;     

   signal Reg_OUTVAL_readback : std_logic_vector(7 downto 0) := (others => '0');   
   signal Reg_L8SHFT_readback : std_logic_vector(7 downto 0) := (others => '0');   
   signal Reg_CTL_readback    : std_logic_vector(7 downto 0) := (others => '0');   
   signal Reg_COUNT_readback  : std_logic_vector(7 downto 0) := (others => '0');   
   signal Reg_MISC_readback   : std_logic_vector(7 downto 0) := (others => '0');   

   type t_reg_wired_or is array(0 to 7) of std_logic_vector(7 downto 0);
   signal reg_wired_or : t_reg_wired_or;   

   signal timer_on         : std_logic;
   signal timer_reload     : std_logic;

   -- internal         
   signal counter          : unsigned(7 downto 0) := (others => '0');
   signal prescalecounter  : unsigned(9 downto 0) := (others => '0');
   signal prescaleborder   : integer range 1 to 1023 := 15;
   signal timer_done       : std_logic := '0';
   signal borrow_out       : std_logic := '0';
   signal turbocnt         : unsigned(1 downto 0) := (others => '0');
   
   signal nextsample       : std_logic := '0';
   signal soundval         : signed(7 downto 0) := (others => '0');
   signal shiftreg         : std_logic_vector(11 downto 0) := (others => '0');
   signal switches         : std_logic_vector(11 downto 0) := (others => '0');
   
   -- savestates
   signal SS_SOUND         : std_logic_vector(REG_SAVESTATE_SOUND.upper downto REG_SAVESTATE_SOUND.lower);
   signal SS_SOUND_BACK    : std_logic_vector(REG_SAVESTATE_SOUND.upper downto REG_SAVESTATE_SOUND.lower);

begin 

   iSS_SOUND : entity work.eReg_SS generic map ( REG_SAVESTATE_SOUND, index ) port map (clk, SSBUS_Din, SSBUS_Adr, SSBUS_wren, SSBUS_rst, SSBUS_Dout, SS_SOUND_BACK, SS_SOUND); 

   iReg_VOL    : entity work.eReg generic map ( VOL    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(0), Reg_VOL            , Reg_VOL   );  
   iReg_SHFTFB : entity work.eReg generic map ( SHFTFB ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(1), Reg_SHFTFB         , Reg_SHFTFB, Reg_SHFTFB_written);  
   iReg_OUTVAL : entity work.eReg generic map ( OUTVAL ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(2), Reg_OUTVAL_readback, Reg_OUTVAL, Reg_OUTVAL_written);  
   iReg_L8SHFT : entity work.eReg generic map ( L8SHFT ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(3), Reg_L8SHFT_readback, Reg_L8SHFT, Reg_L8SHFT_written);  
   iReg_TBACK  : entity work.eReg generic map ( TBACK  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(4), Reg_TBACK          , Reg_TBACK );  
   iReg_CTL    : entity work.eReg generic map ( CTL    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(5), Reg_CTL_readback   , Reg_CTL   , Reg_CTL_written   );  
   iReg_COUNT  : entity work.eReg generic map ( COUNT  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(6), Reg_COUNT_readback , Reg_COUNT , Reg_COUNT_written );  
   iReg_MISC   : entity work.eReg generic map ( MISC   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(7), Reg_MISC_readback  , Reg_MISC  , Reg_MISC_written  );  
   
   process (reg_wired_or)
      variable wired_or : std_logic_vector(7 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      RegBus_Dout <= wired_or;
   end process;
   
   Reg_OUTVAL_readback <= std_logic_vector(soundval);
   Reg_L8SHFT_readback <= shiftreg(7 downto 0);
   Reg_CTL_readback    <= Reg_CTL(7) & '0' & Reg_CTL(5 downto 0);
   Reg_COUNT_readback  <= std_logic_vector(counter);
   Reg_MISC_readback   <= shiftreg(11 downto 8) & Reg_MISC(2) & '0' & countup_in & borrow_out; -- is this really correct? return bit 2 at position 3?
   
   
   tick <= borrow_out;
   soundout <= soundval;
   
   timer_reload <= Reg_CTL(4);
   
   SS_SOUND_BACK( 7 downto  0) <= std_logic_vector(soundval);  
   SS_SOUND_BACK(19 downto  8) <= shiftreg;  
   SS_SOUND_BACK(31 downto 20) <= switches;  
   SS_SOUND_BACK(41 downto 32) <= std_logic_vector(prescalecounter);  
   SS_SOUND_BACK(49 downto 42) <= std_logic_vector(counter);  
   SS_SOUND_BACK(50) <= timer_on;  
   SS_SOUND_BACK(51) <= timer_done;  
   SS_SOUND_BACK(52) <= borrow_out;  
   SS_SOUND_BACK(53) <= nextsample;  
   
   process (clk)
      variable ticked : std_logic;
      variable newbit : std_logic;
   begin
      if rising_edge(clk) then
         
         case (to_integer(unsigned(Reg_CTL(2 downto 0)))) is
            when 0 => prescaleborder <= 15;
            when 1 => prescaleborder <= 31;
            when 2 => prescaleborder <= 63;
            when 3 => prescaleborder <= 127;
            when 4 => prescaleborder <= 255;
            when 5 => prescaleborder <= 511;
            when 6 => prescaleborder <= 1023;
            when others => null;
         end case;
            
         if (reset = '1') then
      
            soundval         <=   signed(SS_SOUND( 7 downto  0)); -- (others => '0');
            shiftreg         <=          SS_SOUND(19 downto  8);  -- (others => '0');
            switches         <=          SS_SOUND(31 downto 20);  -- (others => '0');
            prescalecounter  <= unsigned(SS_SOUND(41 downto 32)); -- (others => '0');
            counter          <= unsigned(SS_SOUND(49 downto 42)); -- (others => '0');
            timer_on         <= SS_SOUND(50); -- '0';
            timer_done       <= SS_SOUND(51); -- '0';
            borrow_out       <= SS_SOUND(52); -- '0';
            nextsample       <= SS_SOUND(53); -- '0';
      
         elsif (ce = '1') then
            
            --work
            ticked := '0';
            turbocnt <= turbocnt + 1;
            
            if (timer_on = '1') then
               if (turbo = '0' or turbocnt = 0) then
                  if (prescalecounter >= prescaleborder) then
                     prescalecounter <= (others => '0');
                     if (Reg_CTL(2 downto 0) /= "111") then
                        ticked  := '1';
                     end if;
                  else
                     prescalecounter <= prescalecounter + 1;
                  end if;
               end if;
            end if;
            
            borrow_out <= '0';
            
            nextsample <= '0';
            if (timer_on = '1' and (timer_reload = '1' or timer_done = '0')) then

               if (Reg_CTL(2 downto 0) = "111" and countup_in = '1') then
                  ticked := '1';
               end if;
      
               if (ticked = '1') then
                  counter <= counter - 1;
                  if (counter = x"00") then
                  
                     borrow_out <= '1';
                     
                     if (timer_reload = '1') then
                        counter <= unsigned(Reg_TBACK);
                     else
                        counter    <= (others => '0');
                        timer_done <= '1'; -- only set when reload = '0' -> cannot be read back ?
                     end if;
                     
                     nextsample <= '1';
                     
                  end if;
               end if;
            end if;
            
            -- generate next sample
            if (nextsample = '1') then
            
               -- maybe we need to filter out those high frequencies?
               --if (Reg_TBACK /= x"00") then
               --   newbit := '0';
               --   for i in 0 to 11 loop
               --      if (switches(i) = '1') then 
               --         newbit := newbit xor shiftreg(i);
               --      end if;
               --   end loop;
               --   newbit := not newbit;
               --else
               --   newbit := shiftreg(0);
               --end if;
            
               newbit := '0';
               for i in 0 to 11 loop
                  if (switches(i) = '1') then 
                     newbit := newbit xor shiftreg(i);
                  end if;
               end loop;
               newbit := not newbit;
               
               shiftreg <= shiftreg(10 downto 0) & newbit;
               if (Reg_CTL(5) = '1') then -- integrate
                  if (newbit = '1') then
                     if ((to_integer(soundval) + to_integer(signed(Reg_VOL))) > 127) then
                        soundval <= to_signed(127, 8);
                     else
                        soundval <= soundval + signed(Reg_VOL);
                     end if; 
                  else
                     if ((to_integer(soundval) - to_integer(signed(Reg_VOL))) < -128) then
                        soundval <= to_signed(1-128, 8);
                     else
                        soundval <= soundval - signed(Reg_VOL);
                     end if; 
                  end if;
               else
                  if (newbit = '1') then
                     soundval <= signed(Reg_VOL);
                  else
                     soundval <= -signed(Reg_VOL);
                  end if;
               end if;
            
            end if;
            
            -- set_settings
            if (Reg_SHFTFB_written = '1') then
               switches(11) <= Reg_SHFTFB(7);
               switches(10) <= Reg_SHFTFB(6);
               switches(5 downto 0) <= Reg_SHFTFB(5 downto 0);
            end if;
            
            if (Reg_OUTVAL_written = '1') then
               soundval <= signed(Reg_OUTVAL);
            end if;
            
            if (Reg_L8SHFT_written = '1') then
               shiftreg(7 downto 0) <= Reg_L8SHFT; 
            end if;
            
            if (Reg_CTL_written = '1') then
               switches(7) <= Reg_CTL(7);
               timer_on <= Reg_CTL(3);
               if (Reg_CTL(6) = '1') then
                  timer_done <= '0';
               end if;
               
               if (Reg_CTL(6) = '1' or Reg_CTL(3) = '1') then
                  prescalecounter  <= (others => '0');
               end if;
            end if;
            
            if (Reg_COUNT_written = '1') then
               counter <= unsigned(Reg_COUNT);
            end if;
            
            if (Reg_MISC_written = '1') then
               shiftreg(11 downto 8) <= Reg_MISC(7 downto 4); 
            end if;
            
         end if;
      
      end if;
   end process;
  

end architecture;





