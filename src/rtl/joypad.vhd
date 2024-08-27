library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegisterBus.all;
use work.pReg_suzy.all;

entity joypad is
   port 
   (     
      clk            : in  std_logic;
      
      JoyUP          : in  std_logic;
      JoyDown        : in  std_logic;
      JoyLeft        : in  std_logic;
      JoyRight       : in  std_logic;
      Option1        : in  std_logic;
      Option2        : in  std_logic;
      KeyB           : in  std_logic;
      KeyA           : in  std_logic;
      KeyPause       : in  std_logic;
   
      RegBus_Din     : in  std_logic_vector(BUS_buswidth-1 downto 0);
      RegBus_Adr     : in  std_logic_vector(BUS_busadr-1 downto 0);
      RegBus_wren    : in  std_logic;
      RegBus_rst     : in  std_logic;
      RegBus_Dout    : out std_logic_vector(BUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of joypad is

   -- register
   signal Reg_JOYSTICK : std_logic_vector(JOYSTICK.upper downto JOYSTICK.lower);
   signal Reg_SWITCHES : std_logic_vector(SWITCHES.upper downto SWITCHES.lower);
   signal Reg_SPRSYS   : std_logic_vector(SPRSYS  .upper downto SPRSYS  .lower);

   type t_reg_wired_or is array(0 to 1) of std_logic_vector(7 downto 0);
   signal reg_wired_or : t_reg_wired_or;   

begin 

   iReg_JOYSTICK : entity work.eReg generic map ( JOYSTICK ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(0), Reg_JOYSTICK);  
   iReg_SWITCHES : entity work.eReg generic map ( SWITCHES ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(1), Reg_SWITCHES);  
   iReg_SPRSYS   : entity work.eReg generic map ( SPRSYS   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, open           , Reg_SPRSYS, Reg_SPRSYS);    
  
   process (reg_wired_or)
      variable wired_or : std_logic_vector(7 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      RegBus_Dout <= wired_or;
   end process;


   Reg_JOYSTICK(0) <= KeyA;
   Reg_JOYSTICK(1) <= KeyB;
   Reg_JOYSTICK(2) <= Option2;
   Reg_JOYSTICK(3) <= Option1;
   Reg_JOYSTICK(4) <= JoyLeft  when Reg_SPRSYS(3) = '1' else JoyRight;
   Reg_JOYSTICK(5) <= JoyRight when Reg_SPRSYS(3) = '1' else JoyLeft;
   Reg_JOYSTICK(6) <= JoyUP    when Reg_SPRSYS(3) = '1' else JoyDown;
   Reg_JOYSTICK(7) <= JoyDown  when Reg_SPRSYS(3) = '1' else JoyUP;
   
   Reg_SWITCHES(7 downto 1) <= (7 downto 1 => '0');
   Reg_SWITCHES(0)          <= KeyPause;


end architecture;





