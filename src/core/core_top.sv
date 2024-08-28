`default_nettype none

module core_top (

  //
  // physical connections
  //

  ///////////////////////////////////////////////////
  // clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

  input   wire            clk_74a, // mainclk1
  input   wire            clk_74b, // mainclk1 

  ///////////////////////////////////////////////////
  // cartridge interface
  // switches between 3.3v and 5v mechanically
  // output enable for multibit translators controlled by pic32

  // GBA AD[15:8]
  inout   wire    [7:0]   cart_tran_bank2,
  output  wire            cart_tran_bank2_dir,

  // GBA AD[7:0]
  inout   wire    [7:0]   cart_tran_bank3,
  output  wire            cart_tran_bank3_dir,

  // GBA A[23:16]
  inout   wire    [7:0]   cart_tran_bank1,
  output  wire            cart_tran_bank1_dir,

  // GBA [7] PHI#
  // GBA [6] WR#
  // GBA [5] RD#
  // GBA [4] CS1#/CS#
  //     [3:0] unwired
  inout   wire    [7:4]   cart_tran_bank0,
  output  wire            cart_tran_bank0_dir,

  // GBA CS2#/RES#
  inout   wire            cart_tran_pin30,
  output  wire            cart_tran_pin30_dir,
  // when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
  // the goal is that when unconfigured, the FPGA weak pullups won't interfere.
  // thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
  // and general IO drive this pin.
  output  wire            cart_pin30_pwroff_reset,

  // GBA IRQ/DRQ
  inout   wire            cart_tran_pin31,
  output  wire            cart_tran_pin31_dir,

  // infrared
  input   wire            port_ir_rx,
  output  wire            port_ir_tx,
  output  wire            port_ir_rx_disable, 

  // GBA link port
  inout   wire            port_tran_si,
  output  wire            port_tran_si_dir,
  inout   wire            port_tran_so,
  output  wire            port_tran_so_dir,
  inout   wire            port_tran_sck,
  output  wire            port_tran_sck_dir,
  inout   wire            port_tran_sd,
  output  wire            port_tran_sd_dir,
   
  ///////////////////////////////////////////////////
  // cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

  output  wire    [21:16] cram0_a,
  inout   wire    [15:0]  cram0_dq,
  input   wire            cram0_wait,
  output  wire            cram0_clk,
  output  wire            cram0_adv_n,
  output  wire            cram0_cre,
  output  wire            cram0_ce0_n,
  output  wire            cram0_ce1_n,
  output  wire            cram0_oe_n,
  output  wire            cram0_we_n,
  output  wire            cram0_ub_n,
  output  wire            cram0_lb_n,

  output  wire    [21:16] cram1_a,
  inout   wire    [15:0]  cram1_dq,
  input   wire            cram1_wait,
  output  wire            cram1_clk,
  output  wire            cram1_adv_n,
  output  wire            cram1_cre,
  output  wire            cram1_ce0_n,
  output  wire            cram1_ce1_n,
  output  wire            cram1_oe_n,
  output  wire            cram1_we_n,
  output  wire            cram1_ub_n,
  output  wire            cram1_lb_n,

  ///////////////////////////////////////////////////
  // sdram, 512mbit 16bit

  output  wire    [12:0]  dram_a,
  output  wire    [1:0]   dram_ba,
  inout   wire    [15:0]  dram_dq,
  output  wire    [1:0]   dram_dqm,
  output  wire            dram_clk,
  output  wire            dram_cke,
  output  wire            dram_ras_n,
  output  wire            dram_cas_n,
  output  wire            dram_we_n,

  ///////////////////////////////////////////////////
  // sram, 1mbit 16bit

  output  wire    [16:0]  sram_a,
  inout   wire    [15:0]  sram_dq,
  output  wire            sram_oe_n,
  output  wire            sram_we_n,
  output  wire            sram_ub_n,
  output  wire            sram_lb_n,

  ///////////////////////////////////////////////////
  // vblank driven by dock for sync in a certain mode

  input   wire            vblank,

  ///////////////////////////////////////////////////
  // i/o to 6515D breakout usb uart

  output  wire            dbg_tx,
  input   wire            dbg_rx,

  ///////////////////////////////////////////////////
  // i/o pads near jtag connector user can solder to

  output  wire            user1,
  input   wire            user2,

  ///////////////////////////////////////////////////
  // RFU internal i2c bus 

  inout   wire            aux_sda,
  output  wire            aux_scl,

  ///////////////////////////////////////////////////
  // RFU, do not use
  output  wire            vpll_feed,

  //
  // logical connections
  //

  ///////////////////////////////////////////////////
  // video, audio output to scaler
  output  wire    [23:0]  video_rgb,
  output  wire            video_rgb_clock,
  output  wire            video_rgb_clock_90,
  output  wire            video_de,
  output  wire            video_skip,
  output  wire            video_vs,
  output  wire            video_hs,
      
  output  wire            audio_mclk,
  input   wire            audio_adc,
  output  wire            audio_dac,
  output  wire            audio_lrck,

  ///////////////////////////////////////////////////
  // bridge bus connection
  // synchronous to clk_74a
  output  wire            bridge_endian_little,
  input   wire    [31:0]  bridge_addr,
  input   wire            bridge_rd,
  output  reg     [31:0]  bridge_rd_data,
  input   wire            bridge_wr,
  input   wire    [31:0]  bridge_wr_data,

  ///////////////////////////////////////////////////
  // controller data
  // 
  // key bitmap:
  //   [0]    dpad_up
  //   [1]    dpad_down
  //   [2]    dpad_left
  //   [3]    dpad_right
  //   [4]    face_a
  //   [5]    face_b
  //   [6]    face_x
  //   [7]    face_y
  //   [8]    trig_l1
  //   [9]    trig_r1
  //   [10]   trig_l2
  //   [11]   trig_r2
  //   [12]   trig_l3
  //   [13]   trig_r3
  //   [14]   face_select
  //   [15]   face_start
  //   [31:28] type
  // joy values - unsigned
  //   [ 7: 0] lstick_x
  //   [15: 8] lstick_y
  //   [23:16] rstick_x
  //   [31:24] rstick_y
  // trigger values - unsigned
  //   [ 7: 0] ltrig
  //   [15: 8] rtrig
  //
  input   wire    [31:0]  cont1_key,
  input   wire    [31:0]  cont2_key,
  input   wire    [31:0]  cont3_key,
  input   wire    [31:0]  cont4_key,
  input   wire    [31:0]  cont1_joy,
  input   wire    [31:0]  cont2_joy,
  input   wire    [31:0]  cont3_joy,
  input   wire    [31:0]  cont4_joy,
  input   wire    [15:0]  cont1_trig,
  input   wire    [15:0]  cont2_trig,
  input   wire    [15:0]  cont3_trig,
  input   wire    [15:0]  cont4_trig
);

// not using the IR port, so turn off both the LED, and
// disable the receive circuit to save power
assign port_ir_tx = 0;
assign port_ir_rx_disable = 1;

// bridge endianness
assign bridge_endian_little = 0;

// cart is unused, so set all level translators accordingly
// directions are 0:IN, 1:OUT
assign cart_tran_bank3[7:2]    = 6'hzz;
assign cart_tran_bank3[0]      = 1'hz;
assign cart_tran_bank3_dir     = 1'b1; // Set to output for rumble cart
assign cart_tran_bank2         = 8'hzz;
assign cart_tran_bank2_dir     = 1'b0;
assign cart_tran_bank1         = 8'hzz;
assign cart_tran_bank1_dir     = 1'b0;
assign cart_tran_bank0[7]      = 1'hz;
assign cart_tran_bank0[5:4]    = 2'hz;
assign cart_tran_bank0_dir     = 1'b1; // Set to output for rumble cart
assign cart_tran_pin30         = 1'b0; // reset or cs2, we let the hw control it by itself
assign cart_tran_pin30_dir     = 1'bz;
assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
assign cart_tran_pin31         = 1'bz;      // input
assign cart_tran_pin31_dir     = 1'b0;  // input

assign port_tran_sd     = 1'bz;
assign port_tran_sd_dir = 1'b0;     // SD is input and not used
assign video_skip       = 1'b0;

// tie off the rest of the pins we are not using
assign cram0_a     = 'h0;
assign cram0_dq    = {16{1'bZ}};
assign cram0_clk   = 0;
assign cram0_adv_n = 1;
assign cram0_cre   = 0;
assign cram0_ce0_n = 1;
assign cram0_ce1_n = 1;
assign cram0_oe_n  = 1;
assign cram0_we_n  = 1;
assign cram0_ub_n  = 1;
assign cram0_lb_n  = 1;

assign cram1_a     = 'h0;
assign cram1_dq    = {16{1'bZ}};
assign cram1_clk   = 0;
assign cram1_adv_n = 1;
assign cram1_cre   = 0;
assign cram1_ce0_n = 1;
assign cram1_ce1_n = 1;
assign cram1_oe_n  = 1;
assign cram1_we_n  = 1;
assign cram1_ub_n  = 1;
assign cram1_lb_n  = 1;

assign sram_a      = 'h0;
assign sram_dq     = {16{1'bZ}};
assign sram_oe_n   = 1;
assign sram_we_n   = 1;
assign sram_ub_n   = 1;
assign sram_lb_n   = 1;

assign dbg_tx      = 1'bZ;
assign user1       = 1'bZ;
assign aux_scl     = 1'bZ;
assign vpll_feed   = 1'bZ;

//
// host/target command handler
//
wire            reset_n;                // driven by host commands, can be used as core-wide reset
wire    [31:0]  cmd_bridge_rd_data;
    
// bridge host commands
// synchronous to clk_74a
wire            status_boot_done  = pll_core_locked_s; 
wire            status_setup_done = pll_core_locked_s; // rising edge triggers a target command
wire            status_running    = reset_n;           // we are running as soon as reset_n goes high

wire            dataslot_requestread;
wire    [15:0]  dataslot_requestread_id;
wire            dataslot_requestread_ack = 1;
wire            dataslot_requestread_ok  = 1;

wire            dataslot_requestwrite;
wire    [15:0]  dataslot_requestwrite_id;
wire    [31:0]  dataslot_requestwrite_size;
wire            dataslot_requestwrite_ack = 1;
wire            dataslot_requestwrite_ok  = 1;

wire            dataslot_update;
wire    [15:0]  dataslot_update_id;
wire    [31:0]  dataslot_update_size;

wire            dataslot_allcomplete;

wire     [31:0] rtc_epoch_seconds;
wire     [31:0] rtc_date_bcd;
wire     [31:0] rtc_time_bcd;
wire            rtc_valid;

wire            savestate_supported   = 0;
wire    [31:0]  savestate_addr        = 0;
wire    [31:0]  savestate_size        = 0;
wire    [31:0]  savestate_maxloadsize = 0;

wire            savestate_start;
wire            savestate_start_ack;
wire            savestate_start_busy;
wire            savestate_start_ok;
wire            savestate_start_err;

wire            savestate_load;
wire            savestate_load_ack;
wire            savestate_load_busy;
wire            savestate_load_ok;
wire            savestate_load_err;

wire            osnotify_inmenu;

// bridge target commands
// synchronous to clk_74a

reg             target_dataslot_read;       
reg             target_dataslot_write;
reg             target_dataslot_getfile;    // require additional param/resp structs to be mapped
reg             target_dataslot_openfile;   // require additional param/resp structs to be mapped

wire            target_dataslot_ack;        
wire            target_dataslot_done;
wire    [2:0]   target_dataslot_err;

reg     [15:0]  target_dataslot_id;
reg     [31:0]  target_dataslot_slotoffset;
reg     [31:0]  target_dataslot_bridgeaddr;
reg     [31:0]  target_dataslot_length;

wire    [31:0]  target_buffer_param_struct; // to be mapped/implemented when using some Target commands
wire    [31:0]  target_buffer_resp_struct;  // to be mapped/implemented when using some Target commands
    
// bridge data slot access
// synchronous to clk_74a

wire    [9:0]   datatable_addr;
wire            datatable_wren;
wire    [31:0]  datatable_data;
wire    [31:0]  datatable_q;

wire            bw_en;

core_bridge_cmd icb (
  .clk                        ( clk_74a                    ),
  .reset_n                    ( reset_n                    ),

  .bridge_endian_little       ( bridge_endian_little       ),
  .bridge_addr                ( bridge_addr                ),
  .bridge_rd                  ( bridge_rd                  ),
  .bridge_rd_data             ( cmd_bridge_rd_data         ),
  .bridge_wr                  ( bridge_wr                  ),
  .bridge_wr_data             ( bridge_wr_data             ),
  
  .status_boot_done           ( status_boot_done           ),
  .status_setup_done          ( status_setup_done          ),
  .status_running             ( status_running             ),

  .dataslot_requestread       ( dataslot_requestread       ),
  .dataslot_requestread_id    ( dataslot_requestread_id    ),
  .dataslot_requestread_ack   ( dataslot_requestread_ack   ),
  .dataslot_requestread_ok    ( dataslot_requestread_ok    ),

  .dataslot_requestwrite      ( dataslot_requestwrite      ),
  .dataslot_requestwrite_id   ( dataslot_requestwrite_id   ),
  .dataslot_requestwrite_size ( dataslot_requestwrite_size ),
  .dataslot_requestwrite_ack  ( dataslot_requestwrite_ack  ),
  .dataslot_requestwrite_ok   ( dataslot_requestwrite_ok   ),

  .dataslot_update            ( dataslot_update            ),
  .dataslot_update_id         ( dataslot_update_id         ),
  .dataslot_update_size       ( dataslot_update_size       ),
  
  .dataslot_allcomplete       ( dataslot_allcomplete       ),

  .rtc_epoch_seconds          ( rtc_epoch_seconds          ),
  .rtc_date_bcd               ( rtc_date_bcd               ),
  .rtc_time_bcd               ( rtc_time_bcd               ),
  .rtc_valid                  ( rtc_valid                  ),
  
  .savestate_supported        ( savestate_supported        ),
  .savestate_addr             ( savestate_addr             ),
  .savestate_size             ( savestate_size             ),
  .savestate_maxloadsize      ( savestate_maxloadsize      ),

  .savestate_start            ( savestate_start            ),
  .savestate_start_ack        ( savestate_start_ack        ),
  .savestate_start_busy       ( savestate_start_busy       ),
  .savestate_start_ok         ( savestate_start_ok         ),
  .savestate_start_err        ( savestate_start_err        ),

  .savestate_load             ( savestate_load             ),
  .savestate_load_ack         ( savestate_load_ack         ),
  .savestate_load_busy        ( savestate_load_busy        ),
  .savestate_load_ok          ( savestate_load_ok          ),
  .savestate_load_err         ( savestate_load_err         ),

  .osnotify_inmenu            ( osnotify_inmenu            ),
  
  .target_dataslot_read       ( target_dataslot_read       ),
  .target_dataslot_write      ( target_dataslot_write      ),
  .target_dataslot_getfile    ( target_dataslot_getfile    ),
  .target_dataslot_openfile   ( target_dataslot_openfile   ),
  
  .target_dataslot_ack        ( target_dataslot_ack        ),
  .target_dataslot_done       ( target_dataslot_done       ),
  .target_dataslot_err        ( target_dataslot_err        ),

  .target_dataslot_id         ( target_dataslot_id         ),
  .target_dataslot_slotoffset ( target_dataslot_slotoffset ),
  .target_dataslot_bridgeaddr ( target_dataslot_bridgeaddr ),
  .target_dataslot_length     ( target_dataslot_length     ),

  .target_buffer_param_struct ( target_buffer_param_struct ),
  .target_buffer_resp_struct  ( target_buffer_resp_struct  ),
  
  .datatable_addr             ( datatable_addr             ),
  .datatable_wren             ( datatable_wren             ),
  .datatable_data             ( datatable_data             ),
  .datatable_q                ( datatable_q                ),

  .bw_en                      ( bw_en                      )

);

//! ------------------------------------------------------------------------
//! Reset Handler (Thanks boogerman!)
//! ------------------------------------------------------------------------
reg  [31:0] reset_counter;
reg         reset_timer;
reg         core_reset   = 0;

always_ff @(posedge clk_74a) begin
  if(reset_timer) begin
    reset_counter <= 32'd8000;
    core_reset    <= 0;
  end
  else begin
    if (reset_counter == 32'h0) begin
      core_reset <= 0;
    end
    else begin
      reset_counter <= reset_counter - 1;
      core_reset    <= 1;
    end
  end
end

// for bridge write data, we just broadcast it to all bus devices
// for bridge read data, we have to mux it
// add your own devices here
always_comb begin
  casex(bridge_addr)
    //32'h2xxxxxxx: begin bridge_rd_data = save_rd_data;                end
    //32'h4xxxxxxx: begin bridge_rd_data = save_state_bridge_read_data; end
    32'hF8xxxxxx: begin bridge_rd_data = cmd_bridge_rd_data;          end
    32'hF1000000: begin bridge_rd_data = int_bridge_read_data;        end
    32'hF2000000: begin bridge_rd_data = int_bridge_read_data;        end
    default:      begin bridge_rd_data = 0;                           end
  endcase
end

reg [31:0] run_settings  = 32'h0;
logic [31:0] int_bridge_read_data;

always_ff @(posedge clk_74a) begin
  reset_timer <= 0; //! Always default this to zero

  if(bridge_wr) begin
    case (bridge_addr)
      32'hF0000000: begin /*         RESET ONLY          */ reset_timer <= 1; end //! Reset Core Command
      32'hF2000000: begin run_settings   <= bridge_wr_data;                   end //! Runtime settings
    endcase
  end

  if(bridge_rd) begin
    case (bridge_addr)
      //32'hF1000000: begin int_bridge_read_data  <= boot_settings;  end //! System Settings
      32'hF2000000: begin int_bridge_read_data  <= run_settings;   end //! Runtime settings
    endcase
  end
end

logic clk_sys, clk_ram, clk_ram_90, clk_vid, clk_vid_90;
logic pll_core_locked, pll_core_locked_s, reset_n_s, external_reset_s;
logic [31:0] cont1_key_s, cont2_key_s, cont3_key_s, cont4_key_s;
logic [31:0] run_settings_s;

synch_3               s01 (pll_core_locked, pll_core_locked_s,  clk_ram);
synch_3               s02 (reset_n,         reset_n_s,          clk_sys);
synch_3               s03 (core_reset,      external_reset_s,   clk_sys);
synch_3 #(.WIDTH(32)) s04 (cont1_key,       cont1_key_s,        clk_sys);
synch_3 #(.WIDTH(32)) s05 (cont2_key,       cont2_key_s,        clk_sys);
synch_3 #(.WIDTH(32)) s06 (cont3_key,       cont3_key_s,        clk_sys);
synch_3 #(.WIDTH(32)) s07 (cont4_key,       cont4_key_s,        clk_sys);
synch_3 #(.WIDTH(32)) s09 (run_settings,    run_settings_s,     clk_sys);

logic turbo_en, fps_overlay, ff_snd_en, ff_en, buff_vid, sync60hz, yc_timing, en240p;
logic [1:0] speed_select, flickerblend, orient_sel;

always_comb begin
  turbo_en       = run_settings_s[0];
  fps_overlay    = run_settings_s[1];
  ff_snd_en      = run_settings_s[2];
  ff_en          = run_settings_s[3];
  buff_vid       = run_settings_s[4];
  speed_select   = run_settings_s[6:5];
  flickerblend   = run_settings_s[8:7];
  sync60hz       = run_settings_s[9];
  orient_sel     = run_settings_s[12:11];
  en240p         = run_settings_s[21];
end

mf_pllbase mp1
(
  .refclk   ( clk_74a         ),
  .rst      ( 0               ),
  
  .outclk_0 ( clk_ram         ),
  .outclk_1 ( clk_sys         ),
  .outclk_2 ( clk_vid         ),
  .outclk_3 ( clk_vid_90      ),
  
  .locked   ( pll_core_locked )
);

logic ioctl_wr, ioctl_wait;
logic [24:0] ioctl_addr;
logic [15:0] ioctl_dout;

data_loader #(
  .ADDRESS_MASK_UPPER_4   ( 4'h1  ),
  .OUTPUT_WORD_SIZE       ( 2     ),
  .WRITE_MEM_CLOCK_DELAY  ( 20    )
) data_loader (
  .clk_74a              ( clk_74a               ),
  .clk_memory           ( clk_sys               ),

  .bridge_wr            ( bridge_wr             ),
  .bridge_endian_little ( bridge_endian_little  ),
  .bridge_addr          ( bridge_addr           ),
  .bridge_wr_data       ( bridge_wr_data        ),

  .write_en             ( ioctl_wr              ),
  .write_addr           ( ioctl_addr            ),
  .write_data           ( ioctl_dout            )
);

reg ioctl_download = 0;

always_ff @(posedge clk_74a) begin
  if      (dataslot_requestwrite) ioctl_download <= 1;
  else if (dataslot_allcomplete)  ioctl_download <= 0;
end

///////////////////////////////////////////////////

wire [15:0] cart_addr;
wire cart_rd;
wire cart_wr;
reg cart_ready = 0;

wire cart_download = ioctl_download && (dataslot_requestwrite_id == 8'h01);
wire bios_download = ioctl_download && (dataslot_requestwrite_id == 8'h00);

wire sdram_ack;

wire [19:0] rom_addr;
wire [15:0] rom_din = 0;
wire [15:0] rom_dout;
wire  [7:0] rom_byte = rom_addr[0] ? rom_dout[15:8] : rom_dout[7:0];
wire rom_req;
wire rom_ack;

sdram sdram
(
  .init(~pll_core_locked),
  .clk(clk_sys),

  .SDRAM_DQ(dram_dq),    // 16 bit bidirectional data bus
  .SDRAM_A(dram_a),     // 13 bit multiplexed address bus
  .SDRAM_DQML(dram_dqm[1]),  // two byte masks
  .SDRAM_DQMH(dram_dqm[0]),  // 
  .SDRAM_BA(dram_ba),    // two banks
  .SDRAM_nCS(),   // a single chip select
  .SDRAM_nWE(dram_we_n),   // write enable
  .SDRAM_nRAS(dram_ras_n),  // row address select
  .SDRAM_nCAS(dram_cas_n),  // columns address select
  .SDRAM_CKE(dram_cke),   // clock enable
  .SDRAM_CLK(dram_clk),   // clock for chip

  .ch1_addr(ioctl_addr[24:1]),
  .ch1_din(ioctl_dout),
  .ch1_req(ioctl_wr),
  .ch1_rnw(cart_download ? 1'b0 : 1'b1),
  .ch1_ready(sdram_ack),
  .ch1_dout(),

  // 32bit
  .ch2_addr(0),
  .ch2_din(0),
  .ch2_rnw(1),
  .ch2_req(0),
  .ch2_dout(),
  .ch2_ready(),

   // 16 bit
  .ch3_addr(rom_addr[19:1]),
  .ch3_din(rom_din),
  .ch3_dout(rom_dout),
  .ch3_req(~cart_download & rom_req),
  .ch3_rnw(1),
  .ch3_ready(rom_ack)
);

always @(posedge clk_sys) begin
  if(cart_download) begin
    if(ioctl_wr)  ioctl_wait <= 1;
    if(sdram_ack) ioctl_wait <= 0;
  end
  else ioctl_wait <= 0;
end

reg old_download;
reg [19:0] max_addr;
always @(posedge clk_sys) begin
  old_download <= cart_download;
  if (old_download & ~cart_download) begin
      max_addr   <= ioctl_addr[19:0];
      cart_ready <= 1;
   end
end

wire [15:0] Lynx_AUDIO_L;
wire [15:0] Lynx_AUDIO_R;

wire reset = (~reset_n_s | external_reset_s | cart_download);

reg paused;
always_ff @(posedge clk_sys) begin
   paused <= syncpaused; // no pause when rewind capture is on
end

reg [8:0]  bios_wraddr;
reg [7:0]  bios_wrdata;
reg [7:0]  bios_wrdata_next;
reg        bios_wr;
reg        bios_wr_next;
always @(posedge clk_sys) begin
  bios_wr      <= 0;
  bios_wr_next <= 0;
  if(bios_download & ioctl_wr) begin
    bios_wrdata       <= ioctl_dout[7:0];
    bios_wrdata_next  <= ioctl_dout[15:8];
      bios_wraddr       <= ioctl_addr[8:0];
      bios_wr           <= 1;
      bios_wr_next      <= 1;
  end else if (bios_wr_next) begin
      bios_wrdata       <= bios_wrdata_next;
      bios_wraddr       <= bios_wraddr + 1'd1;
      bios_wr           <= 1;
  end
end

LynxTop LynxTop (
  .clk              ( clk_sys),
  .reset_in         ( reset  ),
  .pause_in         ( paused ),
   
  // rom
  .rom_addr         ( rom_addr ),
  .rom_byte         ( rom_byte ),
  .rom_req          ( rom_req  ),
  .rom_ack          ( rom_ack  ),  
   
  .romsize          (max_addr),
  .romwrite_data    (ioctl_dout),
  .romwrite_addr    (ioctl_addr[19:0]),
  .romwrite_wren    (cart_download & ioctl_wr),
   
  // bios
  .bios_wraddr      (bios_wraddr),
  .bios_wrdata      (bios_wrdata),
  .bios_wr          (bios_wr    ),
   
  // Video 
  .pixel_out_addr   (pixel_addr),        // integer range 0 to 16319; -- address for framebuffer
  .pixel_out_data   (pixel_data),        // RGB data for framebuffer
  .pixel_out_we     (pixel_we),          // new pixel for framebuffer
      
  // audio 
  .audio_l          (Lynx_AUDIO_L),
  .audio_r          (Lynx_AUDIO_R),
  
  //settings
  .fastforward      ( fast_forward ),
  .turbo            ( turbo_en    ),
  .speedselect      ( speed_select ),
  .fpsoverlay_on    ( fps_overlay   ),
   
  // joystick
  .JoyUP            ((orientation == 2) ? cont1_key_s[2] : (orientation == 1) ? cont1_key_s[3] : cont1_key_s[0]),
  .JoyDown          ((orientation == 2) ? cont1_key_s[3] : (orientation == 1) ? cont1_key_s[2] : cont1_key_s[1]),
  .JoyLeft          ((orientation == 2) ? cont1_key_s[1] : (orientation == 1) ? cont1_key_s[0] : cont1_key_s[2]),
  .JoyRight         ((orientation == 2) ? cont1_key_s[0] : (orientation == 1) ? cont1_key_s[1] : cont1_key_s[3]),
  .Option1          (cont1_key_s[6]),
  .Option2          (cont1_key_s[7]),
  .KeyB             (cont1_key_s[5]),
  .KeyA             (cont1_key_s[4]),
  .KeyPause         (cont1_key_s[15]),
   
  // savestates
  .increaseSSHeaderCount(0),
  .save_state       (0),
  .load_state       (0),
  .savestate_number (0),
  
  .SAVE_out_Din     (),            // data read from savestate
  .SAVE_out_Dout    (0),           // data written to savestate
  .SAVE_out_Adr     (),           // all addresses are DWORD addresses!
  .SAVE_out_rnw     (),            // read = 1, write = 0
  .SAVE_out_ena     (),            // one cycle high for each action
  .SAVE_out_be      (),            
  .SAVE_out_done    (0),            // should be one cycle high when write is done or read value is valid
  
  .rewind_on        (0),
  .rewind_active    (0),
   
  .cheat_clear(0),
  .cheats_enabled(0),
  .cheat_on(0),
  .cheat_in(0),
  .cheats_active()
);

wire [15:0] audio_l, audio_r;

assign audio_l = (fast_forward && ~ff_snd_en) ? 16'd0 : Lynx_AUDIO_L;
assign audio_r = (fast_forward && ~ff_snd_en) ? 16'd0 : Lynx_AUDIO_R;

audio_mixer #(
  .DW     ( 16  ),
  .STEREO ( 1   )
) audio_mixer (
  .clk_74b      ( clk_74b     ),
  .clk_audio    ( clk_sys     ),

  .vol_att      ( 0           ),
  .mix          ( 0           ),

  .is_signed    ( 1           ),
  .core_l       ( audio_l     ),
  .core_r       ( audio_r     ),

  .audio_mclk   ( audio_mclk  ),
  .audio_lrck   ( audio_lrck  ),
  .audio_dac    ( audio_dac   )
);

////////////////////////////  VIDEO  ////////////////////////////////////

wire [13:0] pixel_addr;
wire [11:0] pixel_data;
wire        pixel_we;

wire buffervideo = buff_vid | flickerblend[1]; // OSD option for buffer or flickerblend on

reg [11:0] vram1[16320];
reg [11:0] vram2[16320];
reg [11:0] vram3[16320];
reg [1:0] buffercnt_write    = 0;
reg [1:0] buffercnt_readnext = 0;
reg [1:0] buffercnt_read     = 0;
reg [1:0] buffercnt_last     = 0;
reg       syncpaused         = 0;

always @(posedge clk_sys) begin
   if (buffervideo) begin
      if(pixel_we && pixel_addr == 16319) begin
         buffercnt_readnext <= buffercnt_write;
         if (buffercnt_write < 2) begin
            buffercnt_write <= buffercnt_write + 1'd1;
         end else begin
            buffercnt_write <= 0;
         end
      end
   end else begin
      buffercnt_write    <= 0;
      buffercnt_readnext <= 0;
   end
   
   if(pixel_we) begin
      if (buffercnt_write == 0) vram1[pixel_addr] <= pixel_data;
      if (buffercnt_write == 1) vram2[pixel_addr] <= pixel_data;
      if (buffercnt_write == 2) vram3[pixel_addr] <= pixel_data;
   end
   
   if (y > 150) begin
      syncpaused <= 0;
   end else if (sync60hz && pixel_we && pixel_addr == 16319) begin
      syncpaused <= 1;
   end

end

reg  [11:0] rgb0;
reg  [11:0] rgb1;
reg  [11:0] rgb2;

always @(posedge clk_sys) begin
   rgb0 <= vram1[px_addr];
   rgb1 <= vram2[px_addr];
   rgb2 <= vram3[px_addr];
end 

wire [13:0] px_addr;

wire [11:0] rgb_last = (buffercnt_last == 0) ? rgb0 :
                       (buffercnt_last == 1) ? rgb1 :
                       rgb2;

wire [11:0] rgb_now = (buffercnt_read == 0) ? rgb0 :
                      (buffercnt_read == 1) ? rgb1 :
                      rgb2;
  
wire [4:0] r2_5 = rgb_now[11:8] + rgb_last[11:8];
wire [4:0] g2_5 = rgb_now[ 7:4] + rgb_last[ 7:4];
wire [4:0] b2_5 = rgb_now[ 3:0] + rgb_last[ 3:0];  
                                
wire [5:0] r3_6 = rgb0[11:8] + rgb1[11:8] + rgb2[11:8];
wire [5:0] g3_6 = rgb0[ 7:4] + rgb1[ 7:4] + rgb2[ 7:4];
wire [5:0] b3_6 = rgb0[ 3:0] + rgb1[ 3:0] + rgb2[ 3:0];

wire [7:0] r3_8 = {r3_6, r3_6[5:4]};
wire [7:0] g3_8 = {g3_6, g3_6[5:4]};
wire [7:0] b3_8 = {b3_6, b3_6[5:4]};

wire [23:0] r3_mul24 = r3_8 * 16'D21845; 
wire [23:0] g3_mul24 = g3_8 * 16'D21845; 
wire [23:0] b3_mul24 = b3_8 * 16'D21845; 

wire [23:0] r3_div24 = r3_mul24 / 16'D16384; 
wire [23:0] g3_div24 = g3_mul24 / 16'D16384; 
wire [23:0] b3_div24 = b3_mul24 / 16'D16384; 
                  
reg hs, vs, hbl, vbl, ce_pix;
reg [7:0] r,g,b;
reg [1:0] orientation;
reg [1:0] videomode;
reg [8:0] x,y;
reg [3:0] div;
reg hbl_1;
reg evenline;

always @(posedge clk_sys) begin

   if (div < 8) div <= div + 1'd1; else div <= 0; // 64mhz / 9 => 7,11Mhz Pixelclock

  ce_pix <= 0;
  if(!div) begin
    ce_pix <= 1;

      if (flickerblend == 0) begin // flickerblend off
         r <= {rgb_now[11:8], rgb_now[11:8]};
         g <= {rgb_now[7:4] , rgb_now[7:4] };
         b <= {rgb_now[3:0] , rgb_now[3:0] };
      end else if (flickerblend == 1) begin // flickerblend 2 frames
         r <= {r2_5, r2_5[4:2]};
         g <= {g2_5, g2_5[4:2]};
         b <= {b2_5, b2_5[4:2]};
      end else begin // flickerblend 3 frames
         r <= r3_div24[7:0];
         g <= g3_div24[7:0];
         b <= b3_div24[7:0];
      end

      if (videomode == 0) begin
         if(x == 160)     hbl <= 1;
         if(y == 120)     vbl <= 0;
         if(y >= 120+102) vbl <= 1;
      end else if (videomode == 1 || videomode == 2) begin
         if(x == 102)     hbl <= 1;
         if(y == 62)      vbl <= 0;
         if(y >= 62+160)  vbl <= 1;
      end else if (videomode == 3) begin
         if(x == 320)                     hbl <= 1;
         if(y == 40)      vbl <= 0;
         if(y >= 40+204)  vbl <= 1;
      end
      
    if(x == 000) begin 
         hbl <= 0;
      end  
       
    if(x == 350) begin
      hs <= 1;
      if(y == 1)   vs <= 1;
      if(y == 4)   vs <= 0;
    end

    if(x == 350+32) hs  <= 0;

  end

  if(ce_pix) begin
   
      hbl_1 <= hbl;

      if (videomode == 0) begin
         if(vbl) px_addr <= 0;
         else begin 
            if(!hbl) px_addr <= px_addr + 1'd1;
         end
      end else if (videomode == 1) begin
         if(!hbl) begin 
            px_addr <= px_addr - 8'd160;
         end else begin
            px_addr <= (8'd101 * 8'd160) + (y - 6'd61);
         end
      end else if (videomode == 2) begin
         if(!hbl) begin 
            px_addr <= px_addr + 8'd160;
         end else begin
            px_addr <= 8'd220 - y;
         end
      end else if (videomode == 3) begin
         if(vbl) begin
            px_addr  <= 0;
            evenline <= 1'b0;
         end else if(!hbl) begin 
            if (x[0] == 1'b1) begin
               px_addr <= px_addr + 1'd1;
            end
         end else if (hbl && ~hbl_1) begin
            evenline <= ~evenline;
            if (~evenline) px_addr <= px_addr - 8'd160;
         end
      end

    x <= x + 1'd1;
    if(x == 10'd444) begin  // (445x270 for standard video, 452x265 for improved Analog Timing for Composite)
      x <= 0;
      if (~&y) y <= y + 1'd1;
      if (y >= 9'd269) begin
        y              <= 0;
        buffercnt_read <= buffercnt_readnext;
        buffercnt_last <= buffercnt_read;
        
        orientation    <= orient_sel;
        
        if (en240p) begin
           videomode = 3; // 320*204, 60Hz
        end else begin
           videomode = 0;
           //if (orient_sel == 0) videomode = 0; // 160*102, 60Hz
           //if (orient_sel == 1) videomode = 1; // 102*160, 60Hz
           //if (orient_sel == 2) videomode = 2; // 102*160, 60Hz, 180 degree rotated
        end
      end
    end
  end
end

// Video
reg video_de_reg;
reg video_hs_reg;
reg video_vs_reg;
reg [23:0] video_rgb_reg;

reg hs_prev;
reg [2:0] hs_delay;
reg vs_prev;
reg de_prev;

wire de = ~(hbl || vbl);

always_ff @(posedge clk_vid) begin
  video_hs_reg  <= 0;
  video_de_reg  <= 0;
  video_rgb_reg <= 24'h0;

  if (de) begin
    video_de_reg  <= 1;

    video_rgb_reg <= {r, g, b};
  end else if (de_prev && ~de) begin
    video_rgb_reg <= 24'h0;
  end

  if (hs_delay > 0) begin
    hs_delay <= hs_delay - 3'h1;
  end

  if (hs_delay == 1) begin
    video_hs_reg <= 1;
  end

  if (~hs_prev && hs) begin
    // HSync went high. Delay by 3 cycles to prevent overlapping with VSync
    hs_delay <= 7;
  end

  // Set VSync to be high for a single cycle on the rising edge of the VSync coming out of the core
  video_vs_reg  <= ~vs_prev && vs;
  hs_prev       <= hs;
  vs_prev       <= vs;
  de_prev       <= de;
end

assign video_rgb_clock    = clk_vid;
assign video_rgb_clock_90 = clk_vid_90;
assign video_de           = video_de_reg;
assign video_hs           = video_hs_reg;
assign video_vs           = video_vs_reg;
//assign video_rgb          = video_rgb_reg;

wire [7:0] lum;
assign lum = (21 * video_rgb_reg[23:16] + 72 * video_rgb_reg[15:8] + 7 * video_rgb_reg[7:0]) / 100;

always_comb begin
  if(~video_de_reg) begin
    if(en240p) begin
      video_rgb[23:13] = 3;
      video_rgb[12:3]  = 0;
      video_rgb[2:0]   = 0;
    end else begin
      if(orient_sel == 1) begin
        video_rgb[23:13] = 1;
        video_rgb[12:3]  = 0;
        video_rgb[2:0]   = 0;
      end else if(orient_sel == 2) begin
        video_rgb[23:13] = 2;
        video_rgb[12:3]  = 0;
        video_rgb[2:0]   = 0;
      end else begin
        video_rgb[23:13] = 0;
        video_rgb[12:3]  = 0;
        video_rgb[2:0]   = 0;
      end
    end

  end else begin
    if (bw_en) begin
      video_rgb = {lum, lum, lum};
    end else begin
      video_rgb = video_rgb_reg;
    end
  end
end

///////////////////////////// Fast Forward Latch /////////////////////////////////

reg fast_forward;
reg ff_latch;

wire fastforward = cont1_key_s[9] && !ioctl_download && ff_en;
wire ff_on;

always @(posedge clk_sys) begin : ffwd
  reg last_ffw;
  reg ff_was_held;
  longint ff_count;

  last_ffw <= fastforward;

  if (fastforward)
    ff_count <= ff_count + 1;

  if (~last_ffw & fastforward) begin
    ff_latch <= 0;
    ff_count <= 0;
  end

  if ((last_ffw & ~fastforward)) begin // 64mhz clock, 0.2 seconds
    ff_was_held <= 0;

    if (ff_count < 6400000 && ~ff_was_held) begin
      ff_was_held <= 1;
      ff_latch <= 1;
    end
  end

  fast_forward <= (fastforward | ff_latch);
end


endmodule
