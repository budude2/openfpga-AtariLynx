library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   
use STD.textio.all;  

use work.pRegisterBus.all;
use work.pReg_mikey.all;
use work.pReg_suzy.all;
use work.pBus_savestates.all;
use work.pReg_savestates.all; 

entity gpu is
   generic 
   (
      is_simu : std_logic := '0'
   );
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
      dma_active     : in  std_logic;
      cpu_sleep      : out std_logic;
      load_savestate : in  std_logic;
      gpu_idle       : out std_logic;
      
      irqrequest_in  : in  std_logic;
      irqdisabled    : in  std_logic;
      irqpending     : in  std_logic;
      irqfinish      : in  std_logic;

      RAM_address    : out integer range 0 to 65535;
      RAM_dataWrite  : out std_logic_vector(7 downto 0);     
      RAM_wren       : out std_logic;    
      RAM_dataRead   : in  std_logic_vector(7 downto 0);

      fpscountBCDout : out unsigned(7 downto 0) := (others => '0');
      
      -- savestates        
      SSBUS_Din      : in  std_logic_vector(SSBUS_buswidth-1 downto 0);
      SSBUS_Adr      : in  std_logic_vector(SSBUS_busadr-1 downto 0);
      SSBUS_wren     : in  std_logic;
      SSBUS_rst      : in  std_logic;
      SSBUS_Dout     : out std_logic_vector(SSBUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of gpu is

   constant DISABLEDRAW : std_logic := '0';

   constant SCREEN_WIDTH  : integer := 160;
   constant SCREEN_HEIGHT : integer := 102;

   -- register
   -- gpu regs
   signal Reg_TMPADRL    : std_logic_vector(TMPADRL  .upper downto TMPADRL  .lower);
   signal Reg_TMPADRH    : std_logic_vector(TMPADRH  .upper downto TMPADRH  .lower);
   signal Reg_TILTACUML  : std_logic_vector(TILTACUML.upper downto TILTACUML.lower);
   signal Reg_TILTACUMH  : std_logic_vector(TILTACUMH.upper downto TILTACUMH.lower);
   signal Reg_HOFFL      : std_logic_vector(HOFFL    .upper downto HOFFL    .lower);
   signal Reg_HOFFH      : std_logic_vector(HOFFH    .upper downto HOFFH    .lower);
   signal Reg_VOFFL      : std_logic_vector(VOFFL    .upper downto VOFFL    .lower);
   signal Reg_VOFFH      : std_logic_vector(VOFFH    .upper downto VOFFH    .lower);
   signal Reg_VIDBASL    : std_logic_vector(VIDBASL  .upper downto VIDBASL  .lower);
   signal Reg_VIDBASH    : std_logic_vector(VIDBASH  .upper downto VIDBASH  .lower);
   signal Reg_COLLBASL   : std_logic_vector(COLLBASL .upper downto COLLBASL .lower);
   signal Reg_COLLBASH   : std_logic_vector(COLLBASH .upper downto COLLBASH .lower);
   signal Reg_VIDADRL    : std_logic_vector(VIDADRL  .upper downto VIDADRL  .lower);
   signal Reg_VIDADRH    : std_logic_vector(VIDADRH  .upper downto VIDADRH  .lower);
   signal Reg_COLLADRL   : std_logic_vector(COLLADRL .upper downto COLLADRL .lower);
   signal Reg_COLLADRH   : std_logic_vector(COLLADRH .upper downto COLLADRH .lower);
   signal Reg_SCBNEXTL   : std_logic_vector(SCBNEXTL .upper downto SCBNEXTL .lower);
   signal Reg_SCBNEXTH   : std_logic_vector(SCBNEXTH .upper downto SCBNEXTH .lower);
   signal Reg_SPRDLINEL  : std_logic_vector(SPRDLINEL.upper downto SPRDLINEL.lower);
   signal Reg_SPRDLINEH  : std_logic_vector(SPRDLINEH.upper downto SPRDLINEH.lower);
   signal Reg_HPOSSTRTL  : std_logic_vector(HPOSSTRTL.upper downto HPOSSTRTL.lower);
   signal Reg_HPOSSTRTH  : std_logic_vector(HPOSSTRTH.upper downto HPOSSTRTH.lower);
   signal Reg_VPOSSTRTL  : std_logic_vector(VPOSSTRTL.upper downto VPOSSTRTL.lower);
   signal Reg_VPOSSTRTH  : std_logic_vector(VPOSSTRTH.upper downto VPOSSTRTH.lower);
   signal Reg_SPRHSIZL   : std_logic_vector(SPRHSIZL .upper downto SPRHSIZL .lower);
   signal Reg_SPRHSIZH   : std_logic_vector(SPRHSIZH .upper downto SPRHSIZH .lower);
   signal Reg_SPRVSIZL   : std_logic_vector(SPRVSIZL .upper downto SPRVSIZL .lower);
   signal Reg_SPRVSIZH   : std_logic_vector(SPRVSIZH .upper downto SPRVSIZH .lower);
   signal Reg_STRETCHL   : std_logic_vector(STRETCHL .upper downto STRETCHL .lower);
   signal Reg_STRETCHH   : std_logic_vector(STRETCHH .upper downto STRETCHH .lower);
   signal Reg_TILTL      : std_logic_vector(TILTL    .upper downto TILTL    .lower);
   signal Reg_TILTH      : std_logic_vector(TILTH    .upper downto TILTH    .lower);
   signal Reg_SPRDOFFL   : std_logic_vector(SPRDOFFL .upper downto SPRDOFFL .lower);
   signal Reg_SPRDOFFH   : std_logic_vector(SPRDOFFH .upper downto SPRDOFFH .lower);
   signal Reg_SPRVPOSL   : std_logic_vector(SPRVPOSL .upper downto SPRVPOSL .lower);
   signal Reg_SPRVPOSH   : std_logic_vector(SPRVPOSH .upper downto SPRVPOSH .lower);
   signal Reg_COLLOFFL   : std_logic_vector(COLLOFFL .upper downto COLLOFFL .lower);
   signal Reg_COLLOFFH   : std_logic_vector(COLLOFFH .upper downto COLLOFFH .lower);
   signal Reg_VSIZACUML  : std_logic_vector(VSIZACUML.upper downto VSIZACUML.lower);
   signal Reg_VSIZACUMH  : std_logic_vector(VSIZACUMH.upper downto VSIZACUMH.lower);
   signal Reg_HSIZOFFL   : std_logic_vector(HSIZOFFL .upper downto HSIZOFFL .lower);
   signal Reg_HSIZOFFH   : std_logic_vector(HSIZOFFH .upper downto HSIZOFFH .lower);
   signal Reg_VSIZOFFL   : std_logic_vector(VSIZOFFL .upper downto VSIZOFFL .lower);
   signal Reg_VSIZOFFH   : std_logic_vector(VSIZOFFH .upper downto VSIZOFFH .lower);
   signal Reg_SCBADRL    : std_logic_vector(SCBADRL  .upper downto SCBADRL  .lower);
   signal Reg_SCBADRH    : std_logic_vector(SCBADRH  .upper downto SCBADRH  .lower);
   signal Reg_PROCADRL   : std_logic_vector(PROCADRL .upper downto PROCADRL .lower);
   signal Reg_PROCADRH   : std_logic_vector(PROCADRH .upper downto PROCADRH .lower);
   
   signal gpureg_we      : std_logic_vector(0 to 47);

   signal TMPADR         : std_logic_vector(15 downto 0) := (others => '0');
   signal TILTACUM       : std_logic_vector(15 downto 0) := (others => '0');
   signal HOFF           : std_logic_vector(15 downto 0) := (others => '0');
   signal VOFF           : std_logic_vector(15 downto 0) := (others => '0');
   signal VIDBAS         : std_logic_vector(15 downto 0) := (others => '0');
   signal COLLBAS        : std_logic_vector(15 downto 0) := (others => '0');
   signal VIDADR         : std_logic_vector(15 downto 0) := (others => '0');
   signal COLLADR        : std_logic_vector(15 downto 0) := (others => '0');
   signal SCBNEXT        : std_logic_vector(15 downto 0) := (others => '0');
   signal SPRDLINE       : std_logic_vector(15 downto 0) := (others => '0');
   signal HPOSSTRT       : std_logic_vector(15 downto 0) := (others => '0');
   signal VPOSSTRT       : std_logic_vector(15 downto 0) := (others => '0');
   signal SPRHSIZ        : std_logic_vector(15 downto 0) := (others => '0');
   signal SPRVSIZ        : std_logic_vector(15 downto 0) := (others => '0');
   signal STRETCH        : std_logic_vector(15 downto 0) := (others => '0');
   signal TILT           : std_logic_vector(15 downto 0) := (others => '0');
   signal SPRDOFF        : std_logic_vector(15 downto 0) := (others => '0');
   signal SPRVPOS        : std_logic_vector(15 downto 0) := (others => '0');
   signal COLLOFF        : std_logic_vector(15 downto 0) := (others => '0');
   signal VSIZACUM       : std_logic_vector(15 downto 0) := (others => '0');
   signal HSIZOFF        : std_logic_vector(15 downto 0) := (others => '0');
   signal VSIZOFF        : std_logic_vector(15 downto 0) := (others => '0');
   signal SCBADR         : std_logic_vector(15 downto 0) := (others => '0');
   signal PROCADR        : std_logic_vector(15 downto 0) := (others => '0');
   
   signal Reg_SPRCTL0     : std_logic_vector(SPRCTL0.upper downto SPRCTL0.lower);
   signal Reg_SPRCTL1     : std_logic_vector(SPRCTL1.upper downto SPRCTL1.lower);
   signal Reg_SPRCOLL     : std_logic_vector(SPRCOLL.upper downto SPRCOLL.lower);   
   signal Reg_SPRCTL0_INT : std_logic_vector(SPRCTL0.upper downto SPRCTL0.lower) := (others => '0');
   signal Reg_SPRCTL1_INT : std_logic_vector(SPRCTL1.upper downto SPRCTL1.lower) := (others => '0');
   signal Reg_SPRCOLL_INT : std_logic_vector(SPRCOLL.upper downto SPRCOLL.lower) := (others => '0');
   signal SPRCTL0_written : std_logic;
   signal SPRCTL1_written : std_logic;
   signal SPRCOLL_written : std_logic;
   
   signal SPRCTL0_Type          : std_logic_vector(2 downto 0);
   signal SPRCTL0_Vflip         : std_logic;
   signal SPRCTL0_Hflip         : std_logic;
   signal SPRCTL0_PixelBits     : integer range 1 to 4;
      
   signal SPRCTL1_StartLeft     : std_logic;
   signal SPRCTL1_StartUp       : std_logic;
   signal SPRCTL1_SkipSprite    : std_logic;
   signal SPRCTL1_ReloadPalette : std_logic;
   signal SPRCTL1_ReloadDepth   : std_logic_vector(1 downto 0);
   signal SPRCTL1_Literal       : std_logic;

   signal SPRCOLL_Number        : std_logic_vector(3 downto 0);
   signal SPRCOLL_Collide       : std_logic;
   
   -- control regs
   signal Reg_CPUSLEEP    : std_logic_vector(CPUSLEEP .upper downto CPUSLEEP .lower);
   signal Reg_SPRGO       : std_logic_vector(SPRGO    .upper downto SPRGO    .lower);
   signal Reg_SUZYBUSEN   : std_logic_vector(SUZYBUSEN.upper downto SUZYBUSEN.lower);
   signal Reg_SPRSYS      : std_logic_vector(SPRSYS   .upper downto SPRSYS   .lower);
                          
   signal Reg_SPRGO_BACK  : std_logic_vector(SPRGO    .upper downto SPRGO    .lower);
   signal Reg_SPRSYS_BACK : std_logic_vector(SPRSYS   .upper downto SPRSYS   .lower);

   signal Reg_CPUSLEEP_written : std_logic;
   signal Reg_SPRGO_written    : std_logic;

   type t_reg_wired_or is array(0 to 54) of std_logic_vector(7 downto 0);
   signal reg_wired_or : t_reg_wired_or;
   
   signal EVER_ON          : std_logic;
   signal SPRITE_GO        : std_logic := '0';
   signal SPRSYS_VStretch  : std_logic;
   signal SPRSYS_NoCollide : std_logic;

   -- control stage
   signal cpu_sleep_intern : std_logic := '0';
   
   type tcontrolstate is
   (
      CONTROLIDLE,
      CHECKSPRITE,
      WAITCPU,
      WAITBYTE,
      READBYTES,
      CONTROLDRAW
   );
   signal controlstate   : tcontrolstate;
   type tcontrolstep is
   (
      READCTL0,
      READCTL1,
      READCOLL,
      READSCBNEXT,
      READSTARTADDR,
      READHSTART,
      READVSTART,
      READHSIZ,
      READVSIZ,
      READSTRETCH,
      READTILT,
      READPALETTE
   );
   signal controlstep    : tcontrolstep;
                                  
   signal bytecount        : integer range 0 to 2;
   signal controladdress   : unsigned(15 downto 0) := (others => '0');
   signal controlWE        : std_logic := '0';
   signal controlWriteData : std_logic_vector(7 downto 0) := (others => '0');
   signal controlReadData  : std_logic_vector(7 downto 0) := (others => '0');
   signal lastreadbyte     : std_logic_vector(7 downto 0) := (others => '0');
   signal paletteindex     : integer range 0 to 7;
   signal dma_active_1     : std_logic := '0';
   signal cpu_idle_1       : std_logic := '0';
   
   -- control - drawing exchange
   signal everonscreen     : std_logic := '0';
   -- signal enable_sizing    : std_logic; unused
   signal enable_stretch   : std_logic := '0';
   signal enable_tilt      : std_logic := '0';
   type tPenIndex is array(0 to 15) of std_logic_vector(3 downto 0);
   signal PenIndex : tPenIndex := (others => (others => '0'));
   
   -- drawing control stage
   type tdrawstate is
   (
      DRAWDONE,
      DRAWSTART,
      INITQUADRANT,
      CHECKRENDER,
      RENDERPREPARE,
      RENDERLOOPSTART,
      RENDER,
      RENDERLOOPEND,
      RENDERLINESTART,
      RENDERLINEEND,
      RENDERX,
      RENDERPIXEL,
      NEXTQUADRANT,
      WAITPIPELINE,
      WAITCOLLIDEDATA,
      COLLIDEDEPOT,
      COLLIDEDEPOTDONE
   );
   signal drawstate : tdrawstate;
   
   signal screen_h_start : signed(15 downto 0);
   signal screen_h_end   : signed(15 downto 0) := (others => '0');
   signal screen_v_start : signed(15 downto 0);
   signal screen_v_end   : signed(15 downto 0) := (others => '0');   
   signal world_h_mid    : signed(15 downto 0) := (others => '0');
   signal world_v_mid    : signed(15 downto 0) := (others => '0');
   
   signal quadrantloop   : integer range 0 to 4;
   signal quadrant       : integer range 0 to 3;
   signal superclip      : std_logic := '0';
   signal rendernext     : std_logic := '0';
   signal onscreen       : std_logic := '0';
   signal hsign          : integer range -1 to 1;
   signal vsign          : integer range -1 to 1;
   signal vquadoff       : integer range -1 to 1;
   signal hquadoff       : integer range -1 to 1;
   signal voff_work      : signed(15 downto 0) := (others => '0');
   signal hoff_work      : signed(15 downto 0) := (others => '0');
   signal hoff_write     : signed(15 downto 0) := (others => '0');
   signal vloop          : unsigned(7 downto 0) := (others => '0');
   signal hloop          : unsigned(7 downto 0) := (others => '0');
   signal HSIZACUM       : unsigned(15 downto 0) := (others => '0');
   signal pixel_height   : integer range 0 to 255;
   signal pixel_width    : integer range 0 to 255;
   signal LINE_END       : std_logic := '0';
   
   -- pixelfetch pipeline
   signal lineinit           : std_logic := '0';
   signal linerequest        : std_logic := '0';
   signal LineGetPixel       : std_logic := '0';
                             
   signal LineShiftReg       : std_logic_vector(11 downto 0) := (others => '0');
   signal LineShiftRegCount  : integer range 0 to 12;
   signal LineRepeatCount    : integer range 0 to 2047;  
   signal LinePixel          : std_logic_vector(3 downto 0) := (others => '0');    
   signal LineType           : integer range 0 to 3;       
   signal LinePacketBitsLeft : integer range 0 to 2047;
   signal LineFetchtype3     : std_logic := '0';
   signal Lineinitdone       : std_logic := '0';
   
   type tlinestate is
   (
      LINESTART,
      LINEREADOFFSET,
      LINEREAD,
      LINECHECK,
      LINEREADY
   );
   signal linestate : tlinestate;

   -- pixelwrite
   signal ProcessPixel         : std_logic := '0';
   signal PixelNewData         : std_logic_vector(7 downto 0) := (others => '0');
   signal PixelNewAddress      : unsigned(15 downto 0) := (others => '0');
   signal PixelLastAddress     : unsigned(15 downto 0) := (others => '0');
   signal ColliNewAddress      : unsigned(15 downto 0) := (others => '0');
   signal ColliLastAddress     : unsigned(15 downto 0) := (others => '0');
   signal pixelnewHLwe         : std_logic_vector(1 downto 0) := (others => '0');
   signal collinewHLwe         : std_logic_vector(1 downto 0) := (others => '0');
   signal ignoreFirst          : std_logic := '1';
   signal flushPixel           : std_logic := '0';
   
   signal ProcessPixel_1       : std_logic := '0';
   signal PixelByte            : std_logic_vector(7 downto 0) := (others => '0');
   signal pixelHLwe            : std_logic_vector(1 downto 0) := (others => '0');
   signal colliHLwe            : std_logic_vector(1 downto 0) := (others => '0');
   signal colliHLre            : std_logic_vector(1 downto 0) := (others => '0');
   
   signal LineBaseAddress      : unsigned(15 downto 0) := (others => '0');
   signal LineCollisionAddress : unsigned(15 downto 0) := (others => '0');
   
   -- data read/write
   signal ReadFifo_Din         : std_logic_vector(7 downto 0) := (others => '0');
   signal ReadFifo_Wr          : std_logic := '0';
   signal ReadFifo_NearFull    : std_logic;
   signal ReadFifo_Dout        : std_logic_vector(7 downto 0);
   signal ReadFifo_Rd          : std_logic := '0';
   signal ReadFifo_Empty       : std_logic;
   
   signal WriteFifo_Din        : std_logic_vector(44 downto 0) := (others => '0');
   signal WriteFifo_Wr         : std_logic := '0';
   signal WriteFifo_NearFull   : std_logic;
   signal WriteFifo_Dout       : std_logic_vector(44 downto 0);
   signal WriteFifo_Rd         : std_logic := '0';
   signal WriteFifo_Empty      : std_logic;
   
   signal WFifo_pixeladdr      : unsigned(15 downto 0) := (others => '0');
   signal WFifo_colliaddr      : unsigned(15 downto 0) := (others => '0');
   signal WFifo_pixeldata      : std_logic_vector(7 downto 0) := (others => '0');
   signal WFifo_pixelXor       : std_logic := '0';
   signal WFifo_pixelwe        : std_logic_vector(1 downto 0) := (others => '0');
   signal WFifo_colliwe        : std_logic_vector(1 downto 0) := (others => '0');
   
   type tmemstate is
   (
      MEMIDLE,
      MEMREADWAIT,
      MEMREAD,
      MEMWRITEMODIFYWAIT,
      MEMWRITEMODIFY,
      MEMCOLLSTART,
      MEMCOLLREADWAIT,
      MEMWRITECOLL
   );
   signal memstate : tmemstate;
   
   signal dataaddress   : unsigned(15 downto 0) := (others => '0');
   signal readaddress   : unsigned(15 downto 0) := (others => '0');
   signal readcounter   : integer range 0 to 3;
   signal RAMPixelwrite : std_logic := '0';
   signal RAMPixeldata  : std_logic_vector(7 downto 0) := (others => '0');
   signal Collision     : unsigned(3 downto 0) := (others => '0');
   
   -- fps counter
   signal secondcounter : integer range 0 to 63999999 := 0;
   signal fpscountBCD   : unsigned(7 downto 0) := (others => '0');
   
   -- savestates
   type t_ss_wired_or is array(0 to 5) of std_logic_vector(63 downto 0);
   signal ss_wired_or : t_ss_wired_or;
   
   type t_ss_gpuregs is array(0 to REG_SAVESTATE_GPUREGS.size - 1) of std_logic_vector(REG_SAVESTATE_GPUREGS.upper downto REG_SAVESTATE_GPUREGS.lower);
   signal SS_GPUREGS      : t_ss_gpuregs;
   signal SS_GPUREGS_BACK : t_ss_gpuregs;

begin 

   gss_gpuregs : for i in 0 to (REG_SAVESTATE_GPUREGS.size - 1) generate 
   begin
      iSS_GPUREGS : entity work.eReg_SS generic map ( REG_SAVESTATE_GPUREGS, i ) port map (clk, SSBUS_Din, SSBUS_Adr, SSBUS_wren, SSBUS_rst, ss_wired_or(i), SS_GPUREGS_BACK(i), SS_GPUREGS(i)); 
   end generate;

   process (ss_wired_or)
      variable wired_or : std_logic_vector(63 downto 0);
   begin
      wired_or := ss_wired_or(0);
      for i in 1 to (ss_wired_or'length - 1) loop
         wired_or := wired_or or ss_wired_or(i);
      end loop;
      SSBUS_Dout <= wired_or;
   end process;

   -- gpu regs
   iReg_TMPADRL   : entity work.eReg generic map ( TMPADRL    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(0 ), TMPADR  ( 7 downto 0) , Reg_TMPADRL   , gpureg_we(0 ));  
   iReg_TMPADRH   : entity work.eReg generic map ( TMPADRH    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(1 ), TMPADR  (15 downto 8) , Reg_TMPADRH   , gpureg_we(1 ));  
   iReg_TILTACUML : entity work.eReg generic map ( TILTACUML  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(2 ), TILTACUM( 7 downto 0) , Reg_TILTACUML , gpureg_we(2 ));  
   iReg_TILTACUMH : entity work.eReg generic map ( TILTACUMH  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(3 ), TILTACUM(15 downto 8) , Reg_TILTACUMH , gpureg_we(3 ));  
   iReg_HOFFL     : entity work.eReg generic map ( HOFFL      ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(4 ), HOFF    ( 7 downto 0) , Reg_HOFFL     , gpureg_we(4 ));  
   iReg_HOFFH     : entity work.eReg generic map ( HOFFH      ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(5 ), HOFF    (15 downto 8) , Reg_HOFFH     , gpureg_we(5 ));  
   iReg_VOFFL     : entity work.eReg generic map ( VOFFL      ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(6 ), VOFF    ( 7 downto 0) , Reg_VOFFL     , gpureg_we(6 ));  
   iReg_VOFFH     : entity work.eReg generic map ( VOFFH      ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(7 ), VOFF    (15 downto 8) , Reg_VOFFH     , gpureg_we(7 ));  
   iReg_VIDBASL   : entity work.eReg generic map ( VIDBASL    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(8 ), VIDBAS  ( 7 downto 0) , Reg_VIDBASL   , gpureg_we(8 ));  
   iReg_VIDBASH   : entity work.eReg generic map ( VIDBASH    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(9 ), VIDBAS  (15 downto 8) , Reg_VIDBASH   , gpureg_we(9 ));  
   iReg_COLLBASL  : entity work.eReg generic map ( COLLBASL   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(10), COLLBAS ( 7 downto 0) , Reg_COLLBASL  , gpureg_we(10));  
   iReg_COLLBASH  : entity work.eReg generic map ( COLLBASH   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(11), COLLBAS (15 downto 8) , Reg_COLLBASH  , gpureg_we(11));  
   iReg_VIDADRL   : entity work.eReg generic map ( VIDADRL    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(12), VIDADR  ( 7 downto 0) , Reg_VIDADRL   , gpureg_we(12));  
   iReg_VIDADRH   : entity work.eReg generic map ( VIDADRH    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(13), VIDADR  (15 downto 8) , Reg_VIDADRH   , gpureg_we(13));  
   iReg_COLLADRL  : entity work.eReg generic map ( COLLADRL   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(14), COLLADR ( 7 downto 0) , Reg_COLLADRL  , gpureg_we(14));  
   iReg_COLLADRH  : entity work.eReg generic map ( COLLADRH   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(15), COLLADR (15 downto 8) , Reg_COLLADRH  , gpureg_we(15));  
   iReg_SCBNEXTL  : entity work.eReg generic map ( SCBNEXTL   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(16), SCBNEXT ( 7 downto 0) , Reg_SCBNEXTL  , gpureg_we(16));  
   iReg_SCBNEXTH  : entity work.eReg generic map ( SCBNEXTH   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(17), SCBNEXT (15 downto 8) , Reg_SCBNEXTH  , gpureg_we(17));  
   iReg_SPRDLINEL : entity work.eReg generic map ( SPRDLINEL  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(18), SPRDLINE( 7 downto 0) , Reg_SPRDLINEL , gpureg_we(18));  
   iReg_SPRDLINEH : entity work.eReg generic map ( SPRDLINEH  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(19), SPRDLINE(15 downto 8) , Reg_SPRDLINEH , gpureg_we(19));  
   iReg_HPOSSTRTL : entity work.eReg generic map ( HPOSSTRTL  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(20), HPOSSTRT( 7 downto 0) , Reg_HPOSSTRTL , gpureg_we(20));  
   iReg_HPOSSTRTH : entity work.eReg generic map ( HPOSSTRTH  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(21), HPOSSTRT(15 downto 8) , Reg_HPOSSTRTH , gpureg_we(21));  
   iReg_VPOSSTRTL : entity work.eReg generic map ( VPOSSTRTL  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(22), VPOSSTRT( 7 downto 0) , Reg_VPOSSTRTL , gpureg_we(22));  
   iReg_VPOSSTRTH : entity work.eReg generic map ( VPOSSTRTH  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(23), VPOSSTRT(15 downto 8) , Reg_VPOSSTRTH , gpureg_we(23));  
   iReg_SPRHSIZL  : entity work.eReg generic map ( SPRHSIZL   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(24), SPRHSIZ ( 7 downto 0) , Reg_SPRHSIZL  , gpureg_we(24));  
   iReg_SPRHSIZH  : entity work.eReg generic map ( SPRHSIZH   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(25), SPRHSIZ (15 downto 8) , Reg_SPRHSIZH  , gpureg_we(25));  
   iReg_SPRVSIZL  : entity work.eReg generic map ( SPRVSIZL   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(26), SPRVSIZ ( 7 downto 0) , Reg_SPRVSIZL  , gpureg_we(26));  
   iReg_SPRVSIZH  : entity work.eReg generic map ( SPRVSIZH   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(27), SPRVSIZ (15 downto 8) , Reg_SPRVSIZH  , gpureg_we(27));  
   iReg_STRETCHL  : entity work.eReg generic map ( STRETCHL   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(28), STRETCH ( 7 downto 0) , Reg_STRETCHL  , gpureg_we(28));  
   iReg_STRETCHH  : entity work.eReg generic map ( STRETCHH   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(29), STRETCH (15 downto 8) , Reg_STRETCHH  , gpureg_we(29));  
   iReg_TILTL     : entity work.eReg generic map ( TILTL      ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(30), TILT    ( 7 downto 0) , Reg_TILTL     , gpureg_we(30));  
   iReg_TILTH     : entity work.eReg generic map ( TILTH      ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(31), TILT    (15 downto 8) , Reg_TILTH     , gpureg_we(31));  
   iReg_SPRDOFFL  : entity work.eReg generic map ( SPRDOFFL   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(32), SPRDOFF ( 7 downto 0) , Reg_SPRDOFFL  , gpureg_we(32));  
   iReg_SPRDOFFH  : entity work.eReg generic map ( SPRDOFFH   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(33), SPRDOFF (15 downto 8) , Reg_SPRDOFFH  , gpureg_we(33));  
   iReg_SPRVPOSL  : entity work.eReg generic map ( SPRVPOSL   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(34), SPRVPOS ( 7 downto 0) , Reg_SPRVPOSL  , gpureg_we(34));  
   iReg_SPRVPOSH  : entity work.eReg generic map ( SPRVPOSH   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(35), SPRVPOS (15 downto 8) , Reg_SPRVPOSH  , gpureg_we(35));  
   iReg_COLLOFFL  : entity work.eReg generic map ( COLLOFFL   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(36), COLLOFF ( 7 downto 0) , Reg_COLLOFFL  , gpureg_we(36));  
   iReg_COLLOFFH  : entity work.eReg generic map ( COLLOFFH   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(37), COLLOFF (15 downto 8) , Reg_COLLOFFH  , gpureg_we(37));  
   iReg_VSIZACUML : entity work.eReg generic map ( VSIZACUML  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(38), VSIZACUM( 7 downto 0) , Reg_VSIZACUML , gpureg_we(38));  
   iReg_VSIZACUMH : entity work.eReg generic map ( VSIZACUMH  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(39), VSIZACUM(15 downto 8) , Reg_VSIZACUMH , gpureg_we(39));  
   iReg_HSIZOFFL  : entity work.eReg generic map ( HSIZOFFL   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(40), HSIZOFF ( 7 downto 0) , Reg_HSIZOFFL  , gpureg_we(40));  
   iReg_HSIZOFFH  : entity work.eReg generic map ( HSIZOFFH   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(41), HSIZOFF (15 downto 8) , Reg_HSIZOFFH  , gpureg_we(41));  
   iReg_VSIZOFFL  : entity work.eReg generic map ( VSIZOFFL   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(42), VSIZOFF ( 7 downto 0) , Reg_VSIZOFFL  , gpureg_we(42));  
   iReg_VSIZOFFH  : entity work.eReg generic map ( VSIZOFFH   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(43), VSIZOFF (15 downto 8) , Reg_VSIZOFFH  , gpureg_we(43));  
   iReg_SCBADRL   : entity work.eReg generic map ( SCBADRL    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(44), SCBADR  ( 7 downto 0) , Reg_SCBADRL   , gpureg_we(44));  
   iReg_SCBADRH   : entity work.eReg generic map ( SCBADRH    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(45), SCBADR  (15 downto 8) , Reg_SCBADRH   , gpureg_we(45));  
   iReg_PROCADRL  : entity work.eReg generic map ( PROCADRL   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(46), PROCADR ( 7 downto 0) , Reg_PROCADRL  , gpureg_we(46));  
   iReg_PROCADRH  : entity work.eReg generic map ( PROCADRH   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(47), PROCADR (15 downto 8) , Reg_PROCADRH  , gpureg_we(47));  
   
   iReg_SPRCTL0   : entity work.eReg generic map ( SPRCTL0    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(48), x"FF" , Reg_SPRCTL0  , SPRCTL0_written);  
   iReg_SPRCTL1   : entity work.eReg generic map ( SPRCTL1    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(49), x"FF" , Reg_SPRCTL1  , SPRCTL1_written);  
   iReg_SPRCOLL   : entity work.eReg generic map ( SPRCOLL    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(50), x"FF" , Reg_SPRCOLL  , SPRCOLL_written);  

   -- control regs

   iReg_CPUSLEEP  : entity work.eReg generic map ( CPUSLEEP  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(51), Reg_CPUSLEEP  , Reg_CPUSLEEP , Reg_CPUSLEEP_written);  
   iReg_SPRGO     : entity work.eReg generic map ( SPRGO     ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(52), Reg_SPRGO_BACK, Reg_SPRGO    , Reg_SPRGO_written);  
   iReg_SUZYBUSEN : entity work.eReg generic map ( SUZYBUSEN ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(53), Reg_SUZYBUSEN , Reg_SUZYBUSEN);  
   iReg_SPRSYS    : entity work.eReg generic map ( SPRSYS    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(54), Reg_SPRSYS_BACK , Reg_SPRSYS);  
   
   Reg_SPRGO_BACK   <= Reg_SPRGO(7 downto 1) & SPRITE_GO;
   Reg_SPRSYS_BACK  <= "000" & Reg_SPRSYS(4 downto 3) & '0' & Reg_SPRSYS(1) & cpu_sleep_intern; -- todo bit 2 is unsafe access, what to do with it?
   EVER_ON          <= Reg_SPRGO(2);
   SPRSYS_VStretch  <= Reg_SPRSYS(4);
   SPRSYS_NoCollide <= Reg_SPRSYS(5);
   
   SPRCTL0_Type          <= Reg_SPRCTL0_INT(2 downto 0);
   SPRCTL0_Vflip         <= Reg_SPRCTL0_INT(4);
   SPRCTL0_Hflip         <= Reg_SPRCTL0_INT(5);
   SPRCTL0_PixelBits     <= to_integer(unsigned(Reg_SPRCTL0_INT(7 downto 6))) + 1;  
                         
   SPRCTL1_StartLeft     <= Reg_SPRCTL1_INT(0);
   SPRCTL1_StartUp       <= Reg_SPRCTL1_INT(1);
   SPRCTL1_SkipSprite    <= Reg_SPRCTL1_INT(2);
   SPRCTL1_ReloadPalette <= Reg_SPRCTL1_INT(3);
   SPRCTL1_ReloadDepth   <= Reg_SPRCTL1_INT(5 downto 4);
   SPRCTL1_Literal       <= Reg_SPRCTL1_INT(7);
                         
   SPRCOLL_Number        <= Reg_SPRCOLL_INT(3 downto 0);
   SPRCOLL_Collide       <= Reg_SPRCOLL_INT(5);
   
   screen_h_start <= signed(HOFF);
   screen_v_start <= signed(VOFF);
   
   process (reg_wired_or)
      variable wired_or : std_logic_vector(7 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      RegBus_Dout <= wired_or;
   end process;
   
   -- fps counter
   process (clk)
   begin
      if rising_edge(clk) then
         if (gpureg_we(9) = '1' and VIDBAS(15 downto 8) /= Reg_VIDBASH) then -- VIDBASH write/change
            if (fpscountBCD(3 downto 0) < 9) then
               fpscountBCD(3 downto 0) <= fpscountBCD(3 downto 0) + 1;
            else
               if (fpscountBCD(7 downto 4) < 9) then
                  fpscountBCD(3 downto 0) <= x"0";
                  fpscountBCD(7 downto 4) <= fpscountBCD(7 downto 4) + 1;
               end if;
            end if;
         end if;
         
         if (secondcounter < 63999999) then
            secondcounter <= secondcounter + 1;
         else
            secondcounter  <= 0;
            fpscountBCDout <= fpscountBCD;
            fpscountBCD    <= (others => '0');
         end if;

      end if;
   end process;
   
   RAM_address    <= to_integer(controladdress) when (linerequest = '0') else to_integer(dataaddress);
   RAM_wren       <= controlWE when (linerequest = '0') else RAMPixelwrite;
   RAM_dataWrite  <= controlWriteData when (linerequest = '0') else RAMPixeldata;
   
   cpu_sleep      <= cpu_sleep_intern;
   
   gpu_idle       <= '1' when (controlstate = CONTROLIDLE and Reg_CPUSLEEP_written = '0') else '0';
   
   process (clk)
   begin
      if rising_edge(clk) then
         if (reset = '1') then
            cpu_sleep_intern <= '0';
         elsif (ce = '1') then
            
            if ((irqrequest_in = '1' or irqpending = '1') and irqdisabled = '0') then
               cpu_sleep_intern <= '0';
            end if;
            
            if (irqfinish = '1' and controlstate /= CONTROLIDLE) then
               cpu_sleep_intern <= '1';
            end if;
                
            if (controlstate = CONTROLIDLE) then
               cpu_sleep_intern <= '0';
               if ((is_simu = '0' or DISABLEDRAW = '0') and load_savestate = '0' and Reg_CPUSLEEP_written = '1' and Reg_SUZYBUSEN(0) = '1' and SPRITE_GO = '1') then
                  cpu_sleep_intern <= '1';
               end if;
            end if;
         end if;
      end if;
   end process;
   
   SS_GPUREGS_BACK(0)(15 downto  0) <= TMPADR  ;
   SS_GPUREGS_BACK(0)(31 downto 16) <= TILTACUM;
   SS_GPUREGS_BACK(0)(47 downto 32) <= HOFF    ;
   SS_GPUREGS_BACK(0)(63 downto 48) <= VOFF    ;
   SS_GPUREGS_BACK(1)(15 downto  0) <= VIDBAS  ;
   SS_GPUREGS_BACK(1)(31 downto 16) <= COLLBAS ;
   SS_GPUREGS_BACK(1)(47 downto 32) <= VIDADR  ;
   SS_GPUREGS_BACK(1)(63 downto 48) <= COLLADR ;
   SS_GPUREGS_BACK(2)(15 downto  0) <= SCBNEXT ;
   SS_GPUREGS_BACK(2)(31 downto 16) <= SPRDLINE;
   SS_GPUREGS_BACK(2)(47 downto 32) <= HPOSSTRT;
   SS_GPUREGS_BACK(2)(63 downto 48) <= VPOSSTRT;
   SS_GPUREGS_BACK(3)(15 downto  0) <= SPRHSIZ ;
   SS_GPUREGS_BACK(3)(31 downto 16) <= SPRVSIZ ;
   SS_GPUREGS_BACK(3)(47 downto 32) <= STRETCH ;
   SS_GPUREGS_BACK(3)(63 downto 48) <= TILT    ;
   SS_GPUREGS_BACK(4)(15 downto  0) <= SPRDOFF ;
   SS_GPUREGS_BACK(4)(31 downto 16) <= SPRVPOS ;
   SS_GPUREGS_BACK(4)(47 downto 32) <= COLLOFF ;
   SS_GPUREGS_BACK(4)(63 downto 48) <= VSIZACUM;
   SS_GPUREGS_BACK(5)(15 downto  0) <= HSIZOFF ;
   SS_GPUREGS_BACK(5)(31 downto 16) <= VSIZOFF ;
   SS_GPUREGS_BACK(5)(47 downto 32) <= SCBADR  ;
   SS_GPUREGS_BACK(5)(63 downto 48) <= PROCADR ;
   
   process (clk)
      variable read16          : std_logic_vector(15 downto 0);
      variable modquad         : integer range 0 to 3;
      variable tmpInt          : integer;
      variable shiftregCheckPx : std_logic_vector(3 downto 0);
      variable shiftregpixels  : std_logic_vector(3 downto 0);
      variable LineType_new    : integer range 0 to 3;
   begin
      if rising_edge(clk) then
      
         -- precalc for timing
         screen_h_end   <= screen_h_start + SCREEN_WIDTH;
         screen_v_end   <= screen_v_start + SCREEN_HEIGHT;
      
         if (reset = '1') then
      
            SPRITE_GO        <= '0';
            controlstate     <= CONTROLIDLE;
            drawstate        <= DRAWDONE;
            linerequest      <= '0';
            
            TMPADR   <= SS_GPUREGS(0)(15 downto  0);
            TILTACUM <= SS_GPUREGS(0)(31 downto 16);
            HOFF     <= SS_GPUREGS(0)(47 downto 32);
            VOFF     <= SS_GPUREGS(0)(63 downto 48);
            VIDBAS   <= SS_GPUREGS(1)(15 downto  0);
            COLLBAS  <= SS_GPUREGS(1)(31 downto 16);
            VIDADR   <= SS_GPUREGS(1)(47 downto 32);
            COLLADR  <= SS_GPUREGS(1)(63 downto 48);
            SCBNEXT  <= SS_GPUREGS(2)(15 downto  0);
            SPRDLINE <= SS_GPUREGS(2)(31 downto 16);
            HPOSSTRT <= SS_GPUREGS(2)(47 downto 32);
            VPOSSTRT <= SS_GPUREGS(2)(63 downto 48);
            SPRHSIZ  <= SS_GPUREGS(3)(15 downto  0);
            SPRVSIZ  <= SS_GPUREGS(3)(31 downto 16);
            STRETCH  <= SS_GPUREGS(3)(47 downto 32);
            TILT     <= SS_GPUREGS(3)(63 downto 48);
            SPRDOFF  <= SS_GPUREGS(4)(15 downto  0);
            SPRVPOS  <= SS_GPUREGS(4)(31 downto 16);
            COLLOFF  <= SS_GPUREGS(4)(47 downto 32);
            VSIZACUM <= SS_GPUREGS(4)(63 downto 48);
            HSIZOFF  <= SS_GPUREGS(5)(15 downto  0);
            VSIZOFF  <= SS_GPUREGS(5)(31 downto 16);
            SCBADR   <= SS_GPUREGS(5)(47 downto 32);
            PROCADR  <= SS_GPUREGS(5)(63 downto 48);
            
         else 

            if (Reg_SPRGO_written = '1') then
               SPRITE_GO <= Reg_SPRGO(0);
            end if;
            
            if (gpureg_we(0 ) = '1') then TMPADR   <= x"00" & Reg_TMPADRL  ;  end if; if (gpureg_we(1 ) = '1') then TMPADR  (15 downto 8) <= Reg_TMPADRH;   end if;
            if (gpureg_we(2 ) = '1') then TILTACUM <= x"00" & Reg_TILTACUML;  end if; if (gpureg_we(3 ) = '1') then TILTACUM(15 downto 8) <= Reg_TILTACUMH; end if;
            if (gpureg_we(4 ) = '1') then HOFF     <= x"00" & Reg_HOFFL;      end if; if (gpureg_we(5 ) = '1') then HOFF    (15 downto 8) <= Reg_HOFFH;     end if;
            if (gpureg_we(6 ) = '1') then VOFF     <= x"00" & Reg_VOFFL;      end if; if (gpureg_we(7 ) = '1') then VOFF    (15 downto 8) <= Reg_VOFFH;     end if;
            if (gpureg_we(8 ) = '1') then VIDBAS   <= x"00" & Reg_VIDBASL;    end if; if (gpureg_we(9 ) = '1') then VIDBAS  (15 downto 8) <= Reg_VIDBASH;   end if;
            if (gpureg_we(10) = '1') then COLLBAS  <= x"00" & Reg_COLLBASL;   end if; if (gpureg_we(11) = '1') then COLLBAS (15 downto 8) <= Reg_COLLBASH;  end if;
            if (gpureg_we(12) = '1') then VIDADR   <= x"00" & Reg_VIDADRL;    end if; if (gpureg_we(13) = '1') then VIDADR  (15 downto 8) <= Reg_VIDADRH;   end if;
            if (gpureg_we(14) = '1') then COLLADR  <= x"00" & Reg_COLLADRL;   end if; if (gpureg_we(15) = '1') then COLLADR (15 downto 8) <= Reg_COLLADRH;  end if;
            if (gpureg_we(16) = '1') then SCBNEXT  <= x"00" & Reg_SCBNEXTL;   end if; if (gpureg_we(17) = '1') then SCBNEXT (15 downto 8) <= Reg_SCBNEXTH;  end if;
            if (gpureg_we(18) = '1') then SPRDLINE <= x"00" & Reg_SPRDLINEL;  end if; if (gpureg_we(19) = '1') then SPRDLINE(15 downto 8) <= Reg_SPRDLINEH; end if;
            if (gpureg_we(20) = '1') then HPOSSTRT <= x"00" & Reg_HPOSSTRTL;  end if; if (gpureg_we(21) = '1') then HPOSSTRT(15 downto 8) <= Reg_HPOSSTRTH; end if;
            if (gpureg_we(22) = '1') then VPOSSTRT <= x"00" & Reg_VPOSSTRTL;  end if; if (gpureg_we(23) = '1') then VPOSSTRT(15 downto 8) <= Reg_VPOSSTRTH; end if;
            if (gpureg_we(24) = '1') then SPRHSIZ  <= x"00" & Reg_SPRHSIZL;   end if; if (gpureg_we(25) = '1') then SPRHSIZ (15 downto 8) <= Reg_SPRHSIZH;  end if;
            if (gpureg_we(26) = '1') then SPRVSIZ  <= x"00" & Reg_SPRVSIZL;   end if; if (gpureg_we(27) = '1') then SPRVSIZ (15 downto 8) <= Reg_SPRVSIZH;  end if;
            if (gpureg_we(28) = '1') then STRETCH  <= x"00" & Reg_STRETCHL;   end if; if (gpureg_we(29) = '1') then STRETCH (15 downto 8) <= Reg_STRETCHH;  end if;
            if (gpureg_we(30) = '1') then TILT     <= x"00" & Reg_TILTL;      end if; if (gpureg_we(31) = '1') then TILT    (15 downto 8) <= Reg_TILTH;     end if;
            if (gpureg_we(32) = '1') then SPRDOFF  <= x"00" & Reg_SPRDOFFL;   end if; if (gpureg_we(33) = '1') then SPRDOFF (15 downto 8) <= Reg_SPRDOFFH;  end if;
            if (gpureg_we(34) = '1') then SPRVPOS  <= x"00" & Reg_SPRVPOSL;   end if; if (gpureg_we(35) = '1') then SPRVPOS (15 downto 8) <= Reg_SPRVPOSH;  end if;
            if (gpureg_we(36) = '1') then COLLOFF  <= x"00" & Reg_COLLOFFL;   end if; if (gpureg_we(37) = '1') then COLLOFF (15 downto 8) <= Reg_COLLOFFH;  end if;
            if (gpureg_we(38) = '1') then VSIZACUM <= x"00" & Reg_VSIZACUML;  end if; if (gpureg_we(39) = '1') then VSIZACUM(15 downto 8) <= Reg_VSIZACUMH; end if;
            if (gpureg_we(40) = '1') then HSIZOFF  <= x"00" & Reg_HSIZOFFL;   end if; if (gpureg_we(41) = '1') then HSIZOFF (15 downto 8) <= Reg_HSIZOFFH;  end if;
            if (gpureg_we(42) = '1') then VSIZOFF  <= x"00" & Reg_VSIZOFFL;   end if; if (gpureg_we(43) = '1') then VSIZOFF (15 downto 8) <= Reg_VSIZOFFH;  end if;
            if (gpureg_we(44) = '1') then SCBADR   <= x"00" & Reg_SCBADRL;    end if; if (gpureg_we(45) = '1') then SCBADR  (15 downto 8) <= Reg_SCBADRH;   end if;
            if (gpureg_we(46) = '1') then PROCADR  <= x"00" & Reg_PROCADRL;   end if; if (gpureg_we(47) = '1') then PROCADR (15 downto 8) <= Reg_PROCADRH;  end if;
            
            if (SPRCTL0_written = '1') then Reg_SPRCTL0_INT <= Reg_SPRCTL0; end if;
            if (SPRCTL1_written = '1') then Reg_SPRCTL1_INT <= Reg_SPRCTL1; end if;
            if (SPRCOLL_written = '1') then Reg_SPRCOLL_INT <= Reg_SPRCOLL; end if;
            
            if (ce = '1') then
            
               lineinit     <= '0';
               LineGetPixel <= '0';
               ProcessPixel <= '0';
               flushPixel   <= '0';
               
               dma_active_1 <= dma_active;
               cpu_idle_1  <= cpu_idle;
               
               if (dma_active = '0' and cpu_idle = '1') then
                  controlWE <= '0';
               end if;
            
               -- PaintSprites
               case (controlstate) is
               
                  when CONTROLIDLE =>
                     everonscreen <= '0';
                     if ((is_simu = '0' or DISABLEDRAW = '0') and load_savestate = '0' and Reg_CPUSLEEP_written = '1' and Reg_SUZYBUSEN(0) = '1' and SPRITE_GO = '1') then
                        controlstate     <= CHECKSPRITE;
                     end if;
                     
                  when CHECKSPRITE =>
                     controladdress   <= unsigned(SCBNEXT);
                     TMPADR           <= SCBNEXT;
                     SCBADR           <= SCBNEXT;
                     if (SCBNEXT(15 downto 8) = x"00") then
                        SPRITE_GO        <= '0';
                        controlstate     <= CONTROLIDLE;
                     else
                        paletteindex <= 0;
                        controlstate     <= WAITCPU;
                        controlstep      <= READCTL0;
                        bytecount        <= 0;
                     end if;
                     
                  when WAITCPU =>
                     controlstate <= WAITBYTE;
                     
                  when WAITBYTE =>
                     if (dma_active_1 = '0' and cpu_idle_1 = '1') then
                        bytecount       <= bytecount + 1;
                        controlstate    <= READBYTES;
                        controladdress  <= controladdress + 1;
                        controlReadData <= RAM_dataRead;
                     end if;
                     
                  when READBYTES =>
                     lastreadbyte <= controlReadData;
                     read16       := controlReadData & lastreadbyte;
                     
                     controlstate    <= WAITBYTE; -- default
                     
                     case (controlstep) is
                        when READCTL0 =>
                           controlstep     <= READCTL1;
                           bytecount       <= 0;
                           Reg_SPRCTL0_INT <= controlReadData;
                              
                        when READCTL1 =>
                           controlstep     <= READCOLL;
                           bytecount       <= 0;
                           Reg_SPRCTL1_INT <= controlReadData;
                           
                        when READCOLL =>
                           controlstep     <= READSCBNEXT;
                           bytecount       <= 0;
                           Reg_SPRCOLL_INT <= controlReadData;
                     
                        when READSCBNEXT =>
                           if (bytecount = 2) then
                              SCBNEXT   <= read16;
                              bytecount <= 0;
                              if (SPRCTL1_SkipSprite = '0') then
                                 controlstep <= READSTARTADDR;
                              else
                                 controlstate <= CHECKSPRITE;
                              end if;
                           end if;
                        
                        when READSTARTADDR =>
                           if (bytecount = 2) then
                              SPRDLINE     <= read16;
                              bytecount    <= 0;
                              controlstep  <= READHSTART;
                           end if;
                        
                        when READHSTART =>
                           if (bytecount = 2) then
                              HPOSSTRT     <= read16;
                              bytecount    <= 0;
                              controlstep  <= READVSTART;
                           end if;
                           
                        when READVSTART =>
                           if (bytecount = 2) then
                              VPOSSTRT       <= read16;
                              bytecount      <= 0;
                              --enable_sizing  <= '0'; unused
                              enable_stretch <= '0';
                              enable_tilt    <= '0';
                              if (SPRCTL1_ReloadDepth = "00") then
                                 controlstep <= READPALETTE;
                              else
                                 controlstep <= READHSIZ;
                              end if;
                           end if;
                        
                        when READHSIZ =>
                           if (bytecount = 2) then
                              SPRHSIZ       <= read16;
                              bytecount     <= 0;
                              --enable_sizing <= '1'; unused
                              controlstep   <= READVSIZ;
                           end if;
                        
                        when READVSIZ =>
                           if (bytecount = 2) then
                              SPRVSIZ        <= read16;
                              bytecount      <= 0;
                              if (SPRCTL1_ReloadDepth = "01") then
                                 controlstep <= READPALETTE;
                              else
                                 controlstep <= READSTRETCH;
                              end if;
                           end if;
                           
                        when READSTRETCH =>
                           if (bytecount = 2) then
                              STRETCH        <= read16;
                              bytecount      <= 0;
                              enable_stretch <= '1';
                              if (SPRCTL1_ReloadDepth = "10") then
                                 controlstep <= READPALETTE;
                              else
                                 controlstep <= READTILT;
                              end if;
                           end if;
                           
                        when READTILT =>
                           if (bytecount = 2) then
                              TILT           <= read16;
                              bytecount      <= 0;
                              enable_tilt    <= '1';
                              controlstep <= READPALETTE;
                           end if;   
                           
                        when READPALETTE =>
                           if (SPRCTL1_ReloadPalette = '0') then
                              bytecount      <= 0;
                              PenIndex(paletteindex * 2 + 0) <= controlReadData(7 downto 4);
                              PenIndex(paletteindex * 2 + 1) <= controlReadData(3 downto 0);
                              if (paletteindex = 7) then
                                 controlstate <= CONTROLDRAW;
                                 drawstate    <= DRAWSTART;
                              else
                                 paletteindex <= paletteindex + 1;
                              end if;
                           else 
                              controlstate <= CONTROLDRAW;
                              drawstate    <= DRAWSTART;
                           end if;

                     end case;
                     
                  when CONTROLDRAW =>
                     if (drawstate = DRAWDONE) then
                        controlstate <= CHECKSPRITE;
                     end if;
                     
               end case;
               
               case (drawstate) is
                  
                  when DRAWDONE =>
                     null;
                     
                  when DRAWSTART =>
                     drawstate    <= INITQUADRANT;
                     quadrantloop <= 0;
                     
                     lineinit    <= '1';
                     linerequest <= '1';
               
                     world_h_mid <= screen_h_start + to_signed(16#8000#, 16) + (SCREEN_WIDTH / 2);
                     world_v_mid <= screen_v_start + to_signed(16#8000#, 16) + (SCREEN_HEIGHT / 2);
               
                     superclip <= '0';
                     
                     if (SPRCTL1_StartLeft = '1') then
                        if (SPRCTL1_StartUp = '1') then quadrant <= 2; else quadrant <= 3; end if;
                     else
                        if (SPRCTL1_StartUp = '1') then quadrant <= 1; else quadrant <= 0; end if;
                     end if;
               
                     -- Check ref is inside screen area
                     if (signed(HPOSSTRT) < screen_h_start or signed(HPOSSTRT) >= screen_h_end or signed(VPOSSTRT) < screen_v_start or signed(VPOSSTRT) >= screen_v_end) then
                        superclip <= '1';
                     end if;
                  
                  when INITQUADRANT =>
                     drawstate <= CHECKRENDER;
                     rendernext    <= '0';
               
                     if (quadrant = 0 or quadrant = 1) then
                        if (SPRCTL0_Hflip = '0') then hsign <= 1; else hsign <= -1; end if;
                     else
                        if (SPRCTL0_Hflip = '0') then hsign <= -1; else hsign <= 1; end if;
                     end if;
                     
                     if (quadrant = 0 or quadrant = 3) then
                        if (SPRCTL0_Vflip = '0') then vsign <= 1; else vsign <= -1; end if;
                     else
                        if (SPRCTL0_Vflip = '0') then vsign <= -1; else vsign <= 1; end if;
                     end if;
               
                     if (superclip = '1') then
                        modquad := quadrant;
                        if (SPRCTL0_Vflip = '1') then
                           case (modquad) is
                              when 0 => modquad := 1;
                              when 1 => modquad := 0;
                              when 2 => modquad := 3;
                              when 3 => modquad := 2;
                           end case;
                        end if;
                        if (SPRCTL0_Hflip = '1') then
                           case (modquad) is
                              when 0 => modquad := 3;
                              when 1 => modquad := 2;
                              when 2 => modquad := 1;
                              when 3 => modquad := 0;
                           end case;
                        end if;
                        case (modquad) is
                           when 3 => if ((signed(HPOSSTRT) >= screen_h_start or signed(HPOSSTRT) < world_h_mid) and (signed(VPOSSTRT) <  screen_v_end   or signed(VPOSSTRT) > world_v_mid)) then rendernext <= '1'; end if;
                           when 2 => if ((signed(HPOSSTRT) >= screen_h_start or signed(HPOSSTRT) < world_h_mid) and (signed(VPOSSTRT) >= screen_v_start or signed(VPOSSTRT) < world_v_mid)) then rendernext <= '1'; end if;
                           when 1 => if ((signed(HPOSSTRT) <  screen_h_end   or signed(HPOSSTRT) > world_h_mid) and (signed(VPOSSTRT) >= screen_v_start or signed(VPOSSTRT) < world_v_mid)) then rendernext <= '1'; end if;
                           when 0 => if ((signed(HPOSSTRT) <  screen_h_end   or signed(HPOSSTRT) > world_h_mid) and (signed(VPOSSTRT) <  screen_v_end   or signed(VPOSSTRT) > world_v_mid)) then rendernext <= '1'; end if;
                        end case;
                     else
                        rendernext <= '1';
                     end if;
                  
                  when CHECKRENDER =>
                     if (rendernext = '1') then
                        drawstate <= RENDERPREPARE;
                     else
                        if (lineinit = '0' and linestate = LINEREADY) then -- speedup possible!
                           lineinit <= '1';
                           SPRDLINE <= std_logic_vector(unsigned(SPRDLINE) + unsigned(SPRDOFF));
                           if (SPRDOFF = x"0001") then drawstate <= NEXTQUADRANT; end if;
                           if (SPRDOFF = x"0000") then 
                              drawstate   <= WAITPIPELINE; 
                           end if;
                        end if;
                     end if;
                  
                  when RENDERPREPARE =>
                     drawstate <=RENDERLOOPSTART;
                     voff_work <= signed(VPOSSTRT) - screen_v_start;
                     TILTACUM  <= (others => '0');
                     VSIZACUM  <= (others => '0');
                     if (vsign = 1) then
                        VSIZACUM <= VSIZOFF;
                     end if;
               
                     if (quadrantloop = 0) then
                        vquadoff <= vsign;
                     elsif (vsign /= vquadoff) then 
                        voff_work <= signed(VPOSSTRT) - screen_v_start + vsign;
                     end if;
                  
                  when RENDERLOOPSTART =>
                     if (Lineinitdone = '1' and lineinit = '0') then
                        drawstate    <= RENDER;
                        vloop        <= (others => '0');
                        pixel_height <= to_integer((unsigned(VSIZACUM) + unsigned(SPRVSIZ))) / 256;
                        VSIZACUM     <= std_logic_vector((unsigned(VSIZACUM) + unsigned(SPRVSIZ)) mod 256);
                  
                        if (SPRDOFF = x"0001") then
                           SPRDLINE  <= std_logic_vector(unsigned(SPRDOFF) + unsigned(SPRDLINE));
                           lineinit <= '1';
                           drawstate <= NEXTQUADRANT;
                        end if;
                        
                        if (SPRDOFF = x"0000") then
                           quadrantloop <= 4;
                           drawstate    <= NEXTQUADRANT;
                        end if;
                     end if;
                  
                  when RENDER =>
                     drawstate <= RENDERLINESTART;
                     if (vloop >= pixel_height) then drawstate <= RENDERLOOPEND; end if;
                     if (vsign =  1 and voff_work >= SCREEN_HEIGHT) then drawstate <= RENDERLOOPEND; end if;
                     if (vsign = -1 and voff_work < 0)              then drawstate <= RENDERLOOPEND; end if;
                  
                  when RENDERLOOPEND =>
                     drawstate <= RENDERLOOPSTART;
                     if (SPRSYS_VStretch = '1') then 
                        SPRVSIZ <= std_logic_vector(unsigned(SPRVSIZ) + to_unsigned(to_integer(unsigned(STRETCH)) * pixel_height, 16));
                     end if;
                     SPRDLINE <= std_logic_vector(unsigned(SPRDLINE) + unsigned(SPRDOFF));
                     lineinit <= '1';
                  
                  when RENDERLINESTART =>
                     if (voff_work >= 0 and voff_work < SCREEN_HEIGHT) then
                        tmpInt                := to_integer(unsigned(HPOSSTRT)) + to_integer(signed(TILTACUM(15 downto 8)));
                        HPOSSTRT              <= std_logic_vector(to_unsigned(tmpInt, 16));
                        TILTACUM(15 downto 8) <= (others => '0');
                        hoff_work             <= to_signed(tmpInt, 16) - screen_h_start;
               
                        HSIZACUM <= (others => '0');
                        if (hsign = 1) then
                           HSIZACUM <= unsigned(HSIZOFF);
                        end if;
               
                        if (quadrantloop = 0) then
                           hquadoff <= hsign;
                        elsif (hsign /= hquadoff) then
                           hoff_work <= to_signed(tmpInt, 16) - screen_h_start + hsign;
                        end if;
                        
                        lineinit <= '1';
                        onscreen  <= '0';
                        drawstate <= RENDERX;
                     else
                        drawstate <= RENDERLINEEND;
                     end if;
                  
                  when RENDERLINEEND =>
                     drawstate <= RENDER;
                     
                     flushPixel <= '1';
                     voff_work  <= voff_work + vsign;
               
                     if (enable_stretch = '1') then
                        SPRHSIZ <= std_logic_vector(unsigned(SPRHSIZ) + unsigned(STRETCH));
                     end if;
                     
                     if (enable_tilt = '1') then
                        TILTACUM <= std_logic_vector(unsigned(TILTACUM) + unsigned(TILT));
                     end if;
                     vloop <= vloop + 1;
                  
                  when RENDERX => -- combine with renderpixel to render 1 pixel in 1 clock instead of 2 - also needs modification in LineGetPixel statemachine 
                     if (lineinit = '0' and linestate = LINEREADY and LineGetPixel = '0') then
                        LineGetPixel <= '1';
                        
                        shiftregCheckPx := "0000";
                        case (SPRCTL0_PixelBits) is
                           when 1 => shiftregCheckPx(0         ) := LineShiftReg(          11);
                           when 2 => shiftregCheckPx(1 downto 0) := LineShiftReg(11 downto 10);
                           when 3 => shiftregCheckPx(2 downto 0) := LineShiftReg(11 downto  9);
                           when 4 => shiftregCheckPx(3 downto 0) := LineShiftReg(11 downto  8);
                        end case;
                        
                        if (LINE_END = '1' or (LineType = 1 and SPRCTL0_PixelBits >= LineRepeatCount and shiftregCheckPx = x"0")) then -- both old and new LINE_END = '1'
                           drawstate <= RENDERLINEEND;
                        else
                           drawstate   <= RENDERPIXEL;
                           hloop       <= x"01";
                           HSIZACUM    <= (unsigned(HSIZACUM) + unsigned(SPRHSIZ)) mod 256;
                           pixel_width <= to_integer(unsigned(HSIZACUM) + unsigned(SPRHSIZ)) / 256;
                           if ((to_integer(unsigned(HSIZACUM) + unsigned(SPRHSIZ)) / 256) = 0) then
                              drawstate <= RENDERX;
                           end if;
                        end if;
                     end if;
                  
                  when RENDERPIXEL =>
                     if (WriteFifo_NearFull = '0') then
                        if (hloop >= pixel_width) then
                           drawstate  <= RENDERX;
                        end if;
                        
                        if (hoff_work >= 0 and hoff_work < SCREEN_WIDTH) then
                           ProcessPixel <= '1';
                           hoff_write   <= hoff_work;
                           onscreen     <= '1';
                           everonscreen <= '1';
                        elsif (onscreen = '1') then 
                           drawstate <= RENDERLINEEND;
                        end if;
                        hoff_work <= hoff_work + hsign;
                        hloop <= hloop + 1;
                     end if;
                  
                  when NEXTQUADRANT =>
                     if (quadrantloop < 3) then
                        quadrantloop <= quadrantloop + 1;
                        drawstate    <= INITQUADRANT;
                        if (quadrant < 3) then
                           quadrant <= quadrant + 1;
                        else
                           quadrant <= 0;
                        end if;
                     else
                        drawstate   <= WAITPIPELINE;
                     end if;
                     
                  when WAITPIPELINE =>
                     if (memstate = MEMIDLE and WriteFifo_Empty = '1' and RAMPixelwrite = '0') then
                        drawstate      <= WAITCOLLIDEDATA;
                        linerequest    <= '0';
                        controladdress <= unsigned(SCBADR) + unsigned(COLLOFF);
                     end if;
                     
                  when WAITCOLLIDEDATA =>
                     drawstate      <= COLLIDEDEPOT;
                  
                  when COLLIDEDEPOT =>
                     if (dma_active_1 = '0' and cpu_idle_1 = '1') then
                     
                        drawstate   <= DRAWDONE;
                    
                        -- what happens with bit 4..6 ?
                    
                        controlWriteData <= controlReadData;
                        if (EVER_ON = '1') then
                           if (everonscreen = '0') then controlWriteData(7) <= '1'; end if;
                           controlWE   <= '1';
                           drawstate   <= COLLIDEDEPOTDONE;
                        end if;  
                    
                        -- write back collision depot
                        if (SPRCOLL_Collide = '0' and SPRSYS_NoCollide = '0') then
                           if (SPRCTL0_Type = "010" or SPRCTL0_Type = "011" or SPRCTL0_Type = "100" or SPRCTL0_Type = "110" or SPRCTL0_Type = "111") then
                              controlWriteData(7 downto 4) <= x"0";
                              controlWriteData(3 downto 0) <= std_logic_vector(Collision);
                              if (EVER_ON = '1'and everonscreen = '0') then 
                                 controlWriteData(7) <= '1'; 
                              end if;
                              controlWE                    <= '1';
                              drawstate                    <= COLLIDEDEPOTDONE;
                           end if;
                        end if;
                        
                     end if;
                     
                  when COLLIDEDEPOTDONE =>
                     if (controlWE = '0' or (dma_active = '0' and cpu_idle = '1')) then
                        drawstate   <= DRAWDONE;
                     end if;

               end case;
               
               -- line fetching
               if (lineinit = '1') then
                  linestate          <= LINESTART;
                  LineShiftRegCount  <= 0;
                  LineRepeatCount    <= 0;
                  LinePixel          <= (others => '0');
                  LineType           <= 0;    
                  LINE_END           <= '0';
                  Lineinitdone       <= '0';
               elsif (linerequest = '1') then
                  case (linestate) is
                        
                     when LINESTART =>
                        linestate      <= LINEREADOFFSET;
                        
                     when LINEREADOFFSET =>
                        if (ReadFifo_Empty = '0') then
                           Lineinitdone <= '1';
                           SPRDOFF      <= x"00" & ReadFifo_Dout;
                           if (ReadFifo_Dout /= x"00") then
                              LinePacketBitsLeft <= (to_integer(unsigned(ReadFifo_Dout)) - 1) * 8;
                           end if;
                           linestate          <= LINEREAD;
                           if (SPRCTL1_Literal = '1') then
                              LineType        <= 1; -- line_abs_literal
                              if (ReadFifo_Dout /= x"00") then
                                 LineRepeatCount <= ((to_integer(unsigned(ReadFifo_Dout)) - 1) * 8);
                              end if;
                           end if;
                        end if;
                        
                     when LINEREAD =>
                        if (ReadFifo_Empty = '0') then
                           case LineShiftRegCount is
                              when 0 => LineShiftReg <=                              ReadFifo_Dout & "0000";
                              when 1 => LineShiftReg <= LineShiftReg(11)           & ReadFifo_Dout & "000";
                              when 2 => LineShiftReg <= LineShiftReg(11 downto 10) & ReadFifo_Dout & "00";
                              when 3 => LineShiftReg <= LineShiftReg(11 downto 9)  & ReadFifo_Dout & '0';
                              when 4 => LineShiftReg <= LineShiftReg(11 downto 8)  & ReadFifo_Dout;
                              when others => null;
                           end case;
                           LineShiftRegCount <= LineShiftRegCount + 8;
                           if (LineRepeatCount = 0) then
                              linestate <= LINECHECK;
                           else
                              linestate <= LINEREADY;
                           end if;
                        end if;
                        
                     when LINECHECK => 
                        if (LineRepeatCount = 0) then
                        
                           LineType_new := LineType;
                        
                           if (LineType /= 1) then -- line_abs_literal
                              if (LineShiftReg(11) = '1' and LinePacketBitsLeft > 0) then 
                                 LineType_new := 2; -- line_literal
                              else 
                                 LineType_new := 3; -- line_packed
                              end if;
                           end if;
                           
                           LineType <= LineType_new;
                        
                           linestate <= LINEREADY;
                        
                           if (LineType_new = 2 or LineType_new = 3) then
                              if (LinePacketBitsLeft > 4) then 
                                 LineRepeatCount    <= (to_integer(unsigned(LineShiftReg(10 downto 7))) + 1) * SPRCTL0_PixelBits;
                                 LineShiftReg       <= LineShiftReg(6 downto 0) & "00000";
                                 LineShiftRegCount  <= LineShiftRegCount - 5;
                                 LinePacketBitsLeft <= LinePacketBitsLeft - 5;
                                 if (LineShiftRegCount - 4 < 5) then
                                    linestate      <= LINEREAD;
                                 end if;
                              end if;
                           end if;
                        
                           case (LineType_new) is
                              when 0 => 
                                 LinePixel <= "0000";
                              
                              when 1 => 
                                 LinePixel <= "0000";
                                 LINE_END <= '1';
                              
                              when 2 => null;
   
                              when 3 =>
                                 if (LineShiftReg(10 downto 7) = "0000" or LinePacketBitsLeft < 4) then
                                    LINE_END <= '1';
                                 else
                                    LineFetchtype3 <= '1';
                                    
                                 end if;
                           end case;
                           
                        elsif (LineShiftRegCount < 5) then
                        
                           linestate      <= LINEREAD;
                           
                        else
                        
                           linestate <= LINEREADY;
                         
                        end if;
                     
                     when LINEREADY =>
                        if (LineGetPixel = '1') then

                           if (LINE_END = '0') then
                              if (LineRepeatCount > SPRCTL0_PixelBits) then
                                 LineRepeatCount <= LineRepeatCount - SPRCTL0_PixelBits;
                              else
                                 LineRepeatCount <= 0;
                                 linestate       <= LINECHECK;
                              end if;
                        
                              if (LineType = 1 or LineType = 2 or LineFetchtype3 = '1') then
                                 case (SPRCTL0_PixelBits) is
                                    when 1 => LineShiftReg <= LineShiftReg(10 downto 0) & '0';
                                    when 2 => LineShiftReg <= LineShiftReg( 9 downto 0) & "00";
                                    when 3 => LineShiftReg <= LineShiftReg( 8 downto 0) & "000";
                                    when 4 => LineShiftReg <= LineShiftReg( 7 downto 0) & "0000";
                                 end case;
                                 LineShiftRegCount  <= LineShiftRegCount - SPRCTL0_PixelBits;
                                 if (LinePacketBitsLeft >= SPRCTL0_PixelBits) then
                                    LinePacketBitsLeft <= LinePacketBitsLeft - SPRCTL0_PixelBits;
                                 end if;
                                 if (LineShiftRegCount - SPRCTL0_PixelBits < 5) then
                                    linestate      <= LINEREAD;
                                 end if;
                              end if;
                              
                              shiftregpixels := "0000";
                              case (SPRCTL0_PixelBits) is
                                 when 1 => shiftregpixels(0         ) := LineShiftReg(          11);
                                 when 2 => shiftregpixels(1 downto 0) := LineShiftReg(11 downto 10);
                                 when 3 => shiftregpixels(2 downto 0) := LineShiftReg(11 downto  9);
                                 when 4 => shiftregpixels(3 downto 0) := LineShiftReg(11 downto  8);
                              end case;
                        
                              if (LineType = 1) then
                                 LinePixel <= shiftregpixels;
                                 if (SPRCTL0_PixelBits >= LineRepeatCount and shiftregpixels = x"0") then
                                    LinePixel <= "0000";
                                    LINE_END  <= '1';
                                 else
                                    LinePixel <= PenIndex(to_integer(unsigned(shiftregpixels)));
                                 end if;  
                              elsif (LineType = 2 or LineFetchtype3 = '1') then
                                 LinePixel <= PenIndex(to_integer(unsigned(shiftregpixels)));
                              end if;
                              
                              if (LineFetchtype3 = '1') then
                                 LineFetchtype3 <= '0';
                              end if;
                              
                           end if;
                           
                        end if;

                  end case;
               end if;
            
               LineBaseAddress      <= to_unsigned(to_integer(unsigned(VIDBAS) ) + to_integer(voff_work * (SCREEN_WIDTH / 2)), 32)(15 downto 0);
               if (to_integer(unsigned(COLLBAS)) + to_integer(voff_work * (SCREEN_WIDTH / 2)) >= 0) then
                  LineCollisionAddress <= to_unsigned(to_integer(unsigned(COLLBAS)) + to_integer(voff_work * (SCREEN_WIDTH / 2)), 32)(15 downto 0);
               end if;
                   
               WriteFifo_Wr <= '0';
               
               if (lineinit = '1') then
                  ignoreFirst <= '1';
                  PixelByte   <= (others => '0');
                  pixelHLwe   <= (others => '0');
                  colliHLwe   <= (others => '0');
               end if;
               
               -- stage 0
               ProcessPixel_1 <= ProcessPixel;
               if (ProcessPixel = '1') then
                  PixelNewAddress  <= to_unsigned(to_integer(LineBaseAddress) + (to_integer(unsigned(hoff_write)) / 2), 16);
                  ColliNewAddress  <= to_unsigned(to_integer(LineCollisionAddress) + (to_integer(unsigned(hoff_write)) / 2), 16);
                  PixelLastAddress <= PixelNewAddress;
                  ColliLastAddress <= ColliNewAddress;
                  
                  PixelNewData     <= (others => '0');
                  if (hoff_write mod 2 = 1) then 
                     PixelNewData(3 downto 0)  <= LinePixel;
                  else
                     PixelNewData(7 downto 4)  <= LinePixel;
                  end if;
                  
                  pixelnewHLwe     <= (others => '0');
                  collinewHLwe     <= (others => '0');
                  case (to_integer(unsigned(SPRCTL0_Type))) is
                     when 0 => -- BACKGROUND SHADOW
                        pixelnewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                        collinewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                        
                     when 1 => -- BACKGROUND NOCOLLIDE
                        pixelnewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                     
                     when 2 => -- BOUNDARY_SHADOW
                        if (LinePixel /= x"0" and LinePixel /= x"E" and LinePixel /= x"F") then
                           pixelnewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                        end if;
                        if (LinePixel /= x"0" and LinePixel /= x"E") then
                           collinewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                        end if;
                     
                     when 3 => -- BOUNDARY
                        if (LinePixel /= x"0" and LinePixel /= x"F") then
                           pixelnewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                        end if;
                        if (LinePixel /= x"0") then
                           collinewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                        end if;
                        
                     when 4 => -- NORMAL
                        if (LinePixel /= x"0") then
                           pixelnewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                        end if;
                        if (LinePixel /= x"0") then
                           collinewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                        end if;
                     
                     when 5 => -- NOCOLLIDE
                        if (LinePixel /= x"0") then
                           pixelnewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                        end if;
                        
                     when 6 => -- XOR SHADOW
                        if (LinePixel /= x"0") then
                           pixelnewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                           -- todo xor
                        end if;
                        if (LinePixel /= x"0" and LinePixel /= x"E") then
                           collinewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                        end if;
                        
                     when 7 => -- SHADOW
                        if (LinePixel /= x"0") then
                           pixelnewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                        end if;
                        if (LinePixel /= x"0" and LinePixel /= x"E") then
                           collinewHLwe(1 - to_integer((hoff_write mod 2))) <= '1';
                        end if;
                        
                     when others => null;
                  end case;
                  
                  if (SPRCOLL_Collide = '1' or SPRSYS_NoCollide = '1') then
                     collinewHLwe <= (others => '0');
                  end if;
               
               end if;
               
               -- stage 1
               if (flushPixel = '1' and ignoreFirst = '0') then
                  if (pixelHLwe /= "00" or collinewHLwe /= "00") then
                     WriteFifo_Wr  <= '1';
                     WriteFifo_Din(15 downto  0) <= std_logic_vector(PixelNewAddress);
                     WriteFifo_Din(23 downto 16) <= PixelByte;
                     WriteFifo_Din(25 downto 24) <= pixelHLwe;
                     if (SPRCTL0_Type = "110") then WriteFifo_Din(26) <= '1'; else WriteFifo_Din(26) <= '0'; end if;
                     WriteFifo_Din(28 downto 27) <= colliHLwe;
                     WriteFifo_Din(44 downto 29) <= std_logic_vector(ColliNewAddress);
                  end if;
               elsif (ProcessPixel_1 = '1') then
                  if (PixelNewAddress /= PixelLastAddress and ignoreFirst = '0') then
                     if (pixelHLwe /= "00" or colliHLwe /= "00") then
                        WriteFifo_Wr  <= '1';
                        WriteFifo_Din(15 downto  0) <= std_logic_vector(PixelLastAddress);
                        WriteFifo_Din(23 downto 16) <= PixelByte;
                        WriteFifo_Din(25 downto 24) <= pixelHLwe;
                        if (SPRCTL0_Type = "110") then WriteFifo_Din(26) <= '1'; else WriteFifo_Din(26) <= '0'; end if;
                        WriteFifo_Din(28 downto 27) <= colliHLwe;
                        WriteFifo_Din(44 downto 29) <= std_logic_vector(ColliLastAddress);
                     end if;
                     
                     PixelByte                   <= PixelNewData;
                     pixelHLwe                   <= pixelnewHLwe;
                     colliHLwe                   <= collinewHLwe;
                  else
                     ignoreFirst <= '0';
                     PixelByte   <= PixelByte or PixelNewData;
                     pixelHLwe   <= pixelHLwe or pixelnewHLwe;
                     colliHLwe   <= colliHLwe or collinewHLwe;
                  end if;
               end if;
               
            end if; -- ce

         end if;
      end if;
   end process;
   
   ReadFifo_Rd <= (not ReadFifo_Empty) when (linestate = LINEREADOFFSET or linestate = LINEREAD) else '0';
  
   iReadFifo: entity work.SyncFifoFallThrough
   generic map
   (
      SIZE             => 16, -- needs space of 8, but 8 only delivers 7 places
      DATAWIDTH        => 8,
      NEARFULLDISTANCE => 4
   )
   port map
   ( 
      clk      => clk,
      ce       => ce,
      reset    => lineinit,
      Din      => ReadFifo_Din,     
      Wr       => ReadFifo_Wr,     
      Full     => open,    
      NearFull => ReadFifo_NearFull,
      Dout     => ReadFifo_Dout,    
      Rd       => ReadFifo_Rd,      
      Empty    => ReadFifo_Empty   
   );
   
   iWriteFifo: entity work.SyncFifoFallThrough
   generic map
   (
      SIZE             => 8,
      DATAWIDTH        => 45,
      NEARFULLDISTANCE => 4
   )
   port map
   ( 
      clk      => clk,
      ce       => ce,
      reset    => reset,
      Din      => WriteFifo_Din,     
      Wr       => WriteFifo_Wr,     
      Full     => open,    
      NearFull => WriteFifo_NearFull,
      Dout     => WriteFifo_Dout,    
      Rd       => WriteFifo_Rd,      
      Empty    => WriteFifo_Empty   
   );
   
   WFifo_pixeladdr <= unsigned(WriteFifo_Dout(15 downto 0));
   WFifo_pixeldata <= WriteFifo_Dout(23 downto 16);
   WFifo_pixelwe   <= WriteFifo_Dout(25 downto 24);
   WFifo_pixelXor  <= WriteFifo_Dout(26);
   WFifo_colliwe   <= WriteFifo_Dout(28 downto 27);
   WFifo_colliaddr <= unsigned(WriteFifo_Dout(44 downto 29));
  
   process (clk)
      variable newcoll : unsigned(3 downto 0);
   begin
      if rising_edge(clk) then
         
         if (reset = '1') then
      
            memstate <= MEMIDLE;

         elsif (ce = '1') then
         
            ReadFifo_Wr   <= '0';
            WriteFifo_Rd  <= '0';
         
            if (lineinit = '1') then
               readaddress <= unsigned(SPRDLINE);
            end if;
            
            if (dma_active = '0' and cpu_idle = '1') then
               RAMPixelwrite <= '0';
            end if;
            
            if (drawstate = DRAWSTART) then
               Collision <= (others => '0');
            end if;
         
            case (memstate) is
           
               when MEMIDLE =>
                  if (linerequest = '1' and (RAMPixelwrite = '0' or (dma_active = '0' and cpu_idle = '1'))) then
                     if (lineinit = '1') then
                        memstate <= MEMIDLE; -- wait
                     elsif (ReadFifo_NearFull = '0') then
                        memstate    <= MEMREADWAIT;
                        readcounter <= 0;
                        dataaddress <= readaddress;
                     elsif (WriteFifo_Empty = '0' and WriteFifo_Rd = '0') then 
                        dataaddress   <= WFifo_pixeladdr;
                        if (WFifo_pixelwe = "11" and WFifo_pixelXor = '0') then -- if both bytes are to be written and not xor mode
                           RAMPixeldata  <= WFifo_pixeldata;
                           RAMPixelwrite <= '1';
                           if (WFifo_colliwe = "00") then -- no collision
                              WriteFifo_Rd  <= '1';
                           else
                              memstate <= MEMCOLLSTART;
                           end if;
                        elsif (WFifo_pixelwe = "00" and WFifo_colliwe /= "00") then -- only collision data
                           dataaddress <= WFifo_colliaddr;
                           if (SPRCTL0_Type = "000" and WFifo_colliwe = "11") then -- both collision nibble in write only mode, can write directly
                              memstate <= MEMWRITECOLL;
                           else
                              memstate <= MEMCOLLREADWAIT;
                           end if;
                        else -- data with readwrite, maybe collision later
                           memstate <= MEMWRITEMODIFYWAIT;
                        end if;

                     end if;
                  end if;
            
               when MEMREADWAIT =>
                  if (lineinit = '1') then
                     memstate <= MEMIDLE;
                  else
                     memstate <= MEMREAD;
                  end if;
               
               when MEMREAD =>
                  if (lineinit = '1') then
                     memstate <= MEMIDLE;
                  elsif (dma_active_1 = '0' and cpu_idle_1 = '1') then
                     ReadFifo_Din <= RAM_dataRead;
                     ReadFifo_Wr  <= '1';
                     dataaddress <= dataaddress + 1;
                     readaddress <= readaddress + 1;
                     if (readcounter < 3) then
                        memstate    <= MEMREADWAIT;
                        readcounter <= readcounter + 1;
                     else
                        memstate <= MEMIDLE;
                     end if;
                  end if; 
                  
               when MEMWRITEMODIFYWAIT =>
                  memstate <= MEMWRITEMODIFY;
                  
               when MEMWRITEMODIFY =>
                  if (dma_active_1 = '0' and cpu_idle_1 = '1') then
                     RAMPixeldata  <= RAM_dataRead;
                     if (WFifo_pixelXor = '1') then -- xor mode
                        if (WFifo_pixelwe(0) = '1') then RAMPixeldata(3 downto 0) <= WFifo_pixeldata(3 downto 0) xor RAM_dataRead(3 downto 0); end if;
                        if (WFifo_pixelwe(1) = '1') then RAMPixeldata(7 downto 4) <= WFifo_pixeldata(7 downto 4) xor RAM_dataRead(7 downto 4); end if;
                     else
                        if (WFifo_pixelwe(0) = '1') then RAMPixeldata(3 downto 0) <= WFifo_pixeldata(3 downto 0); end if;
                        if (WFifo_pixelwe(1) = '1') then RAMPixeldata(7 downto 4) <= WFifo_pixeldata(7 downto 4); end if;
                     end if;
                     RAMPixelwrite <= '1';
                     if (WFifo_colliwe = "00") then -- no collision -> done
                        memstate      <= MEMIDLE;
                        WriteFifo_Rd  <= '1';
                     else
                        memstate      <= MEMCOLLSTART;
                     end if;
                  end if;
                  
               when MEMCOLLSTART =>
                  if (RAMPixelwrite = '0' or (dma_active = '0' and cpu_idle = '1')) then
                     dataaddress <= WFifo_colliaddr;
                     if (SPRCTL0_Type = "000" and WFifo_colliwe = "11") then -- both collision nibble in write only mode, can write directly
                        memstate <= MEMWRITECOLL;
                     else
                        memstate <= MEMCOLLREADWAIT;
                     end if;
                  end if;
            
               when MEMCOLLREADWAIT =>
                  memstate <= MEMWRITECOLL;
               
               when MEMWRITECOLL =>
                  if (dma_active_1 = '0' and cpu_idle_1 = '1') then
                     if (SPRCTL0_Type /= "000") then
                        newcoll := Collision;
                        if (WFifo_colliwe(0) = '1' and unsigned(RAM_dataRead(3 downto 0)) > newcoll) then newcoll := unsigned(RAM_dataRead(3 downto 0)); end if;
                        if (WFifo_colliwe(1) = '1' and unsigned(RAM_dataRead(7 downto 4)) > newcoll) then newcoll := unsigned(RAM_dataRead(7 downto 4)); end if;
                        Collision <= newcoll;
                     end if;
                     RAMPixeldata  <= RAM_dataRead;
                     if (WFifo_colliwe(0) = '1') then RAMPixeldata(3 downto 0) <= SPRCOLL_Number; end if;
                     if (WFifo_colliwe(1) = '1') then RAMPixeldata(7 downto 4) <= SPRCOLL_Number; end if;
                     RAMPixelwrite <= '1';
                     WriteFifo_Rd  <= '1';
                     memstate      <= MEMIDLE;
                  end if;
            
            end case;
         
         end if;
         
      end if;
   end process;
   
-- synthesis translate_off
   process
      file outfile: text;
      file outfile_irp: text;
      variable f_status: FILE_OPEN_STATUS;
      variable line_out : line;
      variable pixelcount : integer;
      variable spritecount : unsigned(7 downto 0);
      variable cpu_sleep_intern_1 : std_logic := '0';
   begin
   
      file_open(f_status, outfile, "pixels_sim", write_mode);
      file_close(outfile);
      file_open(f_status, outfile, "pixels_sim", append_mode); 
      
      write(line_out, string'("A    C  S"));
      writeline(outfile, line_out);
      
      pixelcount := 0;
      spritecount := (others => '0');
      
      while (true) loop
         wait until rising_edge(clk);
         
         if (ce = '1') then
         
            if (cpu_sleep_intern = '0' and cpu_sleep_intern_1 = '1') then
               file_close(outfile);
               file_open(f_status, outfile, "pixels_sim", append_mode); 
            end if;
         
            if (drawstate = DRAWSTART) then
               spritecount := spritecount + 1;
            end if;
         
            --if (ProcessPixel_1 = '1' and pixelnewHLwe /= "00") then
            --   write(line_out, to_hstring(PixelNewAddress) & " ");
            --   write(line_out, to_hstring(LinePixel) & " ");
            if (RAMPixelwrite = '1' and dma_active = '0' and cpu_idle = '1') then
               write(line_out, to_hstring(dataaddress) & " ");
               write(line_out, to_hstring(RAMPixeldata) & " ");
               write(line_out, to_hstring(spritecount) & " ");
               
               writeline(outfile, line_out);
            
               pixelcount  := pixelcount + 1;
               
            end if;
            
            cpu_sleep_intern_1 := cpu_sleep_intern;
            
         end if;
            
      end loop;
      
   end process;
-- synthesis translate_on

end architecture;





