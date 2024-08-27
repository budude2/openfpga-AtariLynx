library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pexport.all;
use work.pRegisterBus.all;
use work.pReg_mikey.all;
use work.pBus_savestates.all;
use work.pReg_savestates.all; 

entity sound is
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
                     
      countup7       : in  std_logic;
                     
      audio_l 	      : out std_logic_vector(15 downto 0); -- 16 bit signed
      audio_r 	      : out std_logic_vector(15 downto 0); -- 16 bit signed
         
      -- savestates        
      SSBUS_Din      : in  std_logic_vector(SSBUS_buswidth-1 downto 0);
      SSBUS_Adr      : in  std_logic_vector(SSBUS_busadr-1 downto 0);
      SSBUS_wren     : in  std_logic;
      SSBUS_rst      : in  std_logic;
      SSBUS_Dout     : out std_logic_vector(SSBUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of sound is
   
   -- register 
   type t_reg_wired_or is array(0 to 9) of std_logic_vector(7 downto 0);
   signal reg_wired_or : t_reg_wired_or;
   
   signal Reg_MSTEREO : std_logic_vector(MSTEREO.upper downto MSTEREO.lower) := (others => '0');
   signal Reg_ATTEN_A : std_logic_vector(ATTEN_A.upper downto ATTEN_A.lower) := (others => '0');
   signal Reg_ATTEN_B : std_logic_vector(ATTEN_B.upper downto ATTEN_B.lower) := (others => '0');
   signal Reg_ATTEN_C : std_logic_vector(ATTEN_C.upper downto ATTEN_C.lower) := (others => '0');
   signal Reg_ATTEN_D : std_logic_vector(ATTEN_D.upper downto ATTEN_D.lower) := (others => '0');
   signal Reg_MPAN    : std_logic_vector(MPAN   .upper downto MPAN   .lower) := (others => '0');
   
   -- internal
   signal timerticks : std_logic_vector(0 to 3);
   
   type tsoundout is array(0 to 3) of signed(7 downto 0);
   signal soundout : tsoundout;
   
   type tsoundpanned is array(0 to 3) of integer range -2048 to 2047;
   signal span_l : tsoundpanned;
   signal span_r : tsoundpanned;
   
   -- savestates
   type t_ss_wired_or is array(0 to 3) of std_logic_vector(63 downto 0);
   signal ss_wired_or : t_ss_wired_or;

begin 

   iReg_MSTEREO : entity work.eReg generic map ( MSTEREO ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(4), Reg_MSTEREO, Reg_MSTEREO);  
   iReg_ATTEN_A : entity work.eReg generic map ( ATTEN_A ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(5), Reg_ATTEN_A, Reg_ATTEN_A);  
   iReg_ATTEN_B : entity work.eReg generic map ( ATTEN_B ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(6), Reg_ATTEN_B, Reg_ATTEN_B);  
   iReg_ATTEN_C : entity work.eReg generic map ( ATTEN_C ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(7), Reg_ATTEN_C, Reg_ATTEN_C);  
   iReg_ATTEN_D : entity work.eReg generic map ( ATTEN_D ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(8), Reg_ATTEN_D, Reg_ATTEN_D);  
   iReg_MPAN    : entity work.eReg generic map ( MPAN    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(9), Reg_MPAN   , Reg_MPAN   );  

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
   
   isound_module0 : entity work.sound_module
   generic map
   (
      index          => 0,
      VOL            => AUD0VOL,   
      SHFTFB         => AUD0SHFTFB,
      OUTVAL         => AUD0OUTVAL,
      L8SHFT         => AUD0L8SHFT,
      TBACK          => AUD0TBACK, 
      CTL            => AUD0CTL,   
      COUNT          => AUD0COUNT, 
      MISC           => AUD0MISC  
   )
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
      RegBus_Dout    => reg_wired_or(0),
                    
      countup_in     => countup7,
      tick           => timerticks(0),
      soundout       => soundout(0),
                      
      -- savestates
      SSBUS_Din      => SSBUS_Din, 
      SSBUS_Adr      => SSBUS_Adr, 
      SSBUS_wren     => SSBUS_wren,
      SSBUS_rst      => SSBUS_rst, 
      SSBUS_Dout     => ss_wired_or(0)
   );
   
   isound_module1 : entity work.sound_module
   generic map
   (
      index          => 1,
      VOL            => AUD1VOL,   
      SHFTFB         => AUD1SHFTFB,
      OUTVAL         => AUD1OUTVAL,
      L8SHFT         => AUD1L8SHFT,
      TBACK          => AUD1TBACK, 
      CTL            => AUD1CTL,   
      COUNT          => AUD1COUNT, 
      MISC           => AUD1MISC  
   )
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
      RegBus_Dout    => reg_wired_or(1),
                    
      countup_in     => timerticks(0),
      tick           => timerticks(1),
      soundout       => soundout(1),
                      
      -- savestates
      SSBUS_Din      => SSBUS_Din, 
      SSBUS_Adr      => SSBUS_Adr, 
      SSBUS_wren     => SSBUS_wren,
      SSBUS_rst      => SSBUS_rst, 
      SSBUS_Dout     => ss_wired_or(1)
   );
   
   isound_module2 : entity work.sound_module
   generic map
   (
      index          => 2,
      VOL            => AUD2VOL,   
      SHFTFB         => AUD2SHFTFB,
      OUTVAL         => AUD2OUTVAL,
      L8SHFT         => AUD2L8SHFT,
      TBACK          => AUD2TBACK, 
      CTL            => AUD2CTL,   
      COUNT          => AUD2COUNT, 
      MISC           => AUD2MISC  
   )
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
      RegBus_Dout    => reg_wired_or(2),
                    
      countup_in     => timerticks(1),
      tick           => timerticks(2),
      soundout       => soundout(2),
                      
      -- savestates
      SSBUS_Din      => SSBUS_Din, 
      SSBUS_Adr      => SSBUS_Adr, 
      SSBUS_wren     => SSBUS_wren,
      SSBUS_rst      => SSBUS_rst, 
      SSBUS_Dout     => ss_wired_or(2)
   );
   
   isound_module3 : entity work.sound_module
   generic map
   (
      index          => 3,
      VOL            => AUD3VOL,   
      SHFTFB         => AUD3SHFTFB,
      OUTVAL         => AUD3OUTVAL,
      L8SHFT         => AUD3L8SHFT,
      TBACK          => AUD3TBACK, 
      CTL            => AUD3CTL,   
      COUNT          => AUD3COUNT, 
      MISC           => AUD3MISC  
   )
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
      RegBus_Dout    => reg_wired_or(3),
                    
      countup_in     => timerticks(2),
      tick           => timerticks(3),
      soundout       => soundout(3),
                      
      -- savestates
      SSBUS_Din      => SSBUS_Din, 
      SSBUS_Adr      => SSBUS_Adr, 
      SSBUS_wren     => SSBUS_wren,
      SSBUS_rst      => SSBUS_rst, 
      SSBUS_Dout     => ss_wired_or(3)
   );
   
   process (clk)
      variable soundsum_left  : signed(15 downto 0);
      variable soundsum_right : signed(15 downto 0);
   begin
      if rising_edge(clk) then
         if (reset = '1') then
         
            audio_l <= (others => '0');
            audio_r <= (others => '0');
            
         elsif (ce = '1') then
         
            if (Reg_MPAN(4) = '1') then span_l(0) <= to_integer(soundout(0)) * to_integer(unsigned(Reg_ATTEN_A(7 downto 4))); else span_l(0) <= to_integer(soundout(0)) * 16; end if;
            if (Reg_MPAN(5) = '1') then span_l(1) <= to_integer(soundout(1)) * to_integer(unsigned(Reg_ATTEN_B(7 downto 4))); else span_l(1) <= to_integer(soundout(1)) * 16; end if;
            if (Reg_MPAN(6) = '1') then span_l(2) <= to_integer(soundout(2)) * to_integer(unsigned(Reg_ATTEN_C(7 downto 4))); else span_l(2) <= to_integer(soundout(2)) * 16; end if;
            if (Reg_MPAN(7) = '1') then span_l(3) <= to_integer(soundout(3)) * to_integer(unsigned(Reg_ATTEN_D(7 downto 4))); else span_l(3) <= to_integer(soundout(3)) * 16; end if;
         
            if (Reg_MPAN(0) = '1') then span_r(0) <= to_integer(soundout(0)) * to_integer(unsigned(Reg_ATTEN_A(3 downto 0))); else span_r(0) <= to_integer(soundout(0)) * 16; end if;
            if (Reg_MPAN(1) = '1') then span_r(1) <= to_integer(soundout(1)) * to_integer(unsigned(Reg_ATTEN_B(3 downto 0))); else span_r(1) <= to_integer(soundout(1)) * 16; end if;
            if (Reg_MPAN(2) = '1') then span_r(2) <= to_integer(soundout(2)) * to_integer(unsigned(Reg_ATTEN_C(3 downto 0))); else span_r(2) <= to_integer(soundout(2)) * 16; end if;
            if (Reg_MPAN(3) = '1') then span_r(3) <= to_integer(soundout(3)) * to_integer(unsigned(Reg_ATTEN_D(3 downto 0))); else span_r(3) <= to_integer(soundout(3)) * 16; end if;

            soundsum_left := (others => '0');
            if (Reg_MSTEREO(4) = '0') then soundsum_left  := soundsum_left  + to_signed(span_l(0), 12); end if;
            if (Reg_MSTEREO(5) = '0') then soundsum_left  := soundsum_left  + to_signed(span_l(1), 12); end if;
            if (Reg_MSTEREO(6) = '0') then soundsum_left  := soundsum_left  + to_signed(span_l(2), 12); end if;
            if (Reg_MSTEREO(7) = '0') then soundsum_left  := soundsum_left  + to_signed(span_l(3), 12); end if;
            
            soundsum_right := (others => '0');
            if (Reg_MSTEREO(0) = '0') then soundsum_right := soundsum_right + to_signed(span_r(0), 12); end if;
            if (Reg_MSTEREO(1) = '0') then soundsum_right := soundsum_right + to_signed(span_r(1), 12); end if;
            if (Reg_MSTEREO(2) = '0') then soundsum_right := soundsum_right + to_signed(span_r(2), 12); end if;
            if (Reg_MSTEREO(3) = '0') then soundsum_right := soundsum_right + to_signed(span_r(3), 12); end if;
            
            audio_l <= std_logic_vector(to_signed(to_integer(soundsum_left) * 2, 16));
            audio_r <= std_logic_vector(to_signed(to_integer(soundsum_right) * 2, 16));
            
         end if;
      end if;
   end process;
   

end architecture;





