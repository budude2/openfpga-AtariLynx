//------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Copyright (c) 2023, Marcus Andrade <marcus@opengateware.org>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
//------------------------------------------------------------------------------
// Generic Video Interface for the Analogue Pocket Display
//
// Note: APF scaler requires HSync and VSync to last for a single clock
//
// RGB palettes
//
// | RGB Format | Bit Depth | Number of Colors |
// | ---------- | --------- | ---------------- |
// | RGB111     | 3 bits    | 8                |
// | RGB222     | 6 bits    | 64               |
// | RGB233     | 8 bits    | 256              |
// | RGB332     | 8 bits    | 256              |
// | RGB333     | 9 bits    | 512              |
// | RGB444     | 12 bits   | 4,096            |
// | RGB555     | 15 bits   | 32,768           |
// | RGB565     | 16 bits   | 65,536           |
// | RGB666     | 18 bits   | 262,144          |
// | RGB888     | 24 bits   | 16,777,216       |
//
//------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module video_mixer
    #(
         parameter int          RW            = 8,     //! Bits Per Pixel Red
         parameter int          GW            = 8,     //! Bits Per Pixel Green
         parameter int          BW            = 8,     //! Bits Per Pixel Blue
         parameter int          DW            = 8,     //! I/O Controller Data Width
         parameter bit          EN_INTERLACED = 1'b1,  //! Enable Interlaced Video Support
         parameter logic [15:0] SMASK_IDX     = 16'd3  //! Shadow Mask Index
     ) (
         // Clocks and Reset
         input   wire          clk_sys,                //! System Clock
         input   wire          clk_vid,                //! Pixel Clock
         input   wire          clk_vid_90deg,          //! Pixel Clock 90º Phase Shift
         input   wire          reset,                  //! System Reset
         // DIP Switch for Configuration
         input   wire   [31:0] video_sw,               //! Video DIP Switch
         // Display Controls
         input   wire          grayscale_en,           //! Enable Grayscale Video Output
         input   wire          blackout_en,            //! Enable Screen Blackout (No Video Output)
         input   wire    [2:0] video_preset,           //! AP Video Preset Slot
         // Input Video from Core
         input   wire [RW-1:0] core_r,                 //! Core: Video Red
         input   wire [GW-1:0] core_g,                 //! Core: Video Green
         input   wire [BW-1:0] core_b,                 //! Core: Video Blue
         input   wire          core_hs,                //! Core: Horizontal Sync
         input   wire          core_vs,                //! Core: Vertical   Sync
         input   wire          core_hb,                //! Core: Horizontal Blank
         input   wire          core_vb,                //! Core: Vertical   Blank
         // Interlaced Video Controls
         input   wire          field,                  //! [0] Even        | [1] Odd
         input   wire          interlaced,             //! [0] Progressive | [1] Interlaced
         // Output to AP Scaler
         output logic   [23:0] video_rgb,              //! AP: RGB Color: R[23:16] G[15:8] B[7:0]
         output logic          video_hs,               //! AP: Horizontal Sync
         output logic          video_vs,               //! AP: Vertical   Sync
         output logic          video_de,               //! AP: Data Enable
         output  wire          video_skip,             //! AP: Pixel Skip
         output  wire          video_rgb_clock,        //! AP: Pixel Clock
         output  wire          video_rgb_clock_90,     //! AP: Pixel Clock with 90deg Phase Shift
         // I/O Controller
         input   wire   [15:0] ioctl_index,            //! Slot Index used for Filters
         input   wire          ioctl_download,         //! Filter Download is Active
         input   wire          ioctl_wr,               //! Write Enable
         input   wire   [27:0] ioctl_addr,             //! Data Address
         input   wire [DW-1:0] ioctl_data              //! Data Input
     );

    //--------------------------------------------------------------------------
    // Settings
    //--------------------------------------------------------------------------
    wire       mask_download = ioctl_download && (ioctl_index == SMASK_IDX);

    wire [3:0] scnl_sw  = video_sw[3:0]; //! Scanlines
    wire [3:0] smask_sw = video_sw[7:4]; //! Shadow Mask

    //--------------------------------------------------------------------------
    // Combine Colors to Create a Full RGB888 Color Space
    //--------------------------------------------------------------------------
    wire [7:0] R = blackout_en ? 8'h00 : RW == 8 ? core_r : {core_r, {8-RW{1'b0}}};
    wire [7:0] G = blackout_en ? 8'h00 : GW == 8 ? core_g : {core_g, {8-GW{1'b0}}};
    wire [7:0] B = blackout_en ? 8'h00 : BW == 8 ? core_b : {core_b, {8-BW{1'b0}}};

    //--------------------------------------------------------------------------
    // Convert RGB to Grayscale
    //--------------------------------------------------------------------------
    rgb2grayscale u_rgb2grayscale
    (
        .clk    ( clk_vid      ),
        .enable ( grayscale_en ),

        .r_in   ( R            ),
        .g_in   ( G            ),
        .b_in   ( B            ),
        .hs_in  ( core_hs      ),
        .vs_in  ( core_vs      ),
        .hb_in  ( core_hb      ),
        .vb_in  ( core_vb      ),

        .r_out  ( r_out        ),
        .g_out  ( g_out        ),
        .b_out  ( b_out        ),
        .hs_out ( hs_out       ),
        .vs_out ( vs_out       ),
        .de_out ( de_out       )
    );

    //--------------------------------------------------------------------------
    // APF Video Output
    //--------------------------------------------------------------------------
    wire [7:0] r_out,   g_out,   b_out;
    wire       hs_out,  vs_out,  de_out;
    logic      hs_last, vs_last, de_last; // Sync/DE Edge Detection
    reg  [2:0] vsync_d;                   // 3-cycle delay for VSync
    reg        hsync_d_trg;               // Flag to enable hsync after VSync delay

    always_ff @(posedge clk_vid) begin : apfVideoOutput
        if(reset) begin
            video_rgb   <= 24'h0;
            video_hs    <=  1'b0;
            video_vs    <=  1'b0;
            video_de    <=  1'b0;
            hs_last     <=  1'b0;
            vs_last     <=  1'b0;
            de_last     <=  1'b0;
            vsync_d     <=  3'b0;
            hsync_d_trg <=  1'b0;
        end
        else begin
            // Shift VSync delay register
            vsync_d <= {vsync_d[1:0], vs_out};

            // Enable HSync delay flag 3 cycles after VSync goes high
            if (vsync_d[2] && !hsync_d_trg) begin
                hsync_d_trg <= 1'b1;
            end
            else if (vs_out) begin
                hsync_d_trg <= 1'b0;  // Reset HSync delay trigger when VSync is high
            end

            video_rgb <= 24'h0;
            video_de  <= 1'b0;
            video_vs  <= ~vs_last && vs_out;

            // Handle HSync with 3-cycle delay after VSync
            video_hs <= (hsync_d_trg && (~hs_last && hs_out));

            // Handle frame feature bits during VS pulse
            if(~vs_last && vs_out && EN_INTERLACED) begin
                video_rgb <= { 20'h0, ~field, field, interlaced, 1'h0 };
            end
            else if(de_out) begin
                video_de  <= 1'b1;
                video_rgb <= { r_out, g_out, b_out };
            end
            // Handle end-of-line bits after the DE falling edge
            else if(de_last && ~de_out) begin
                video_rgb <= { 8'h0, video_preset, 13'h0 };
            end

            // Enforce 1 clock gap between HS and DE assertion
            if (video_hs && !hs_last && !de_last) begin
                video_de <= 1'b0;  // Ensure DE is not asserted immediately with HS
            end

            // Enforce 1 clock gap between DE deassertion and the next line's HS
            if (de_last && !de_out) begin
                video_hs <= 1'b0;  // Ensure HS does not assert immediately after DE deassertion
            end

            // Update last state registers
            hs_last <= hs_out;
            vs_last <= vs_out;
            de_last <= de_out;
        end
    end

    //--------------------------------------------------------------------------
    // Clock Output
    //--------------------------------------------------------------------------
    assign video_rgb_clock    = clk_vid;
    assign video_rgb_clock_90 = clk_vid_90deg;
    assign video_skip         = 1'b0;

endmodule
