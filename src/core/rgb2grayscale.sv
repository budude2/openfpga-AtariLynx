//------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2024, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Multiplier-based RGB to Grayscale Converter using ITU-R 601-2 Luma Transform
//
// Copyright (c) 2024, Marcus Andrade <marcus@opengateware.org>
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
// For RGB to Grayscale conversion, ITU-R 601-2 luma transform is performed
// which is Y = R * 0.2989 + G * 0.5870 + B * 0.1140
//------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

(* altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *)
module rgb2grayscale
    #(
         parameter int         DW = 8
     )(
         input  logic          clk,     //! System clock
         input  logic          enable,  //! Enable to activate Grayscale Image

         input  logic [DW-1:0] r_in,    //! Red
         input  logic [DW-1:0] g_in,    //! Green
         input  logic [DW-1:0] b_in,    //! Blue
         input  logic          hs_in,   //! Horizontal Sync
         input  logic          vs_in,   //! Vertical Sync
         input  logic          hb_in,   //! Horizontal Blank
         input  logic          vb_in,   //! Vertical Blank

         output logic [DW-1:0] r_out,   //! Red
         output logic [DW-1:0] g_out,   //! Green
         output logic [DW-1:0] b_out,   //! Blue
         output logic          hs_out,  //! Horizontal Sync
         output logic          vs_out,  //! Vertical Sync
         output logic          hb_out,  //! Horizontal Blank
         output logic          vb_out,  //! Vertical Blank
         output logic          de_out   //! Horizontal Blank
     );

    logic [8+DW-1:0] r_y, g_y, b_y; // Y Carries Luma
    logic [8+DW-1:0] r,   y,   b;
    logic            hs_d, vs_d;
    logic            hb_d, vb_d, de_d;

    //!-------------------------------------------------------------------------
    //! 1st Stage
    //!-------------------------------------------------------------------------
    always_ff @(posedge clk) begin : multiplyStage
        hs_d <= hs_in;
        vs_d <= vs_in;
        hb_d <= hb_in;
        vb_d <= vb_in;
        de_d <= ~(hb_in | vb_in);
        if(enable) begin
            // Perform the ITU-R 601-2 luma transform
            // The weights 0.299, 0.587, and 0.114 are approximated by the fractions 76/256, 150/256, and 29/256, respectively.
            // These fractions are chosen based on their closeness to the original weights when scaled to 256 allowing
            // the use of shift operations instead of division for efficiency.
            r_y <= r_in * 8'd76;
            g_y <= g_in * 8'd150;
            b_y <= b_in * 8'd29;
        end
        else begin
            // Passthrough
            r_y[8+DW-1:8] <= r_in;
            g_y[8+DW-1:8] <= g_in;
            b_y[8+DW-1:8] <= b_in;
        end
    end

    //!-------------------------------------------------------------------------
    //! 2nd Stage
    //!-------------------------------------------------------------------------
    always_ff @(posedge clk) begin : addStage
        hs_out <= hs_d;
        vs_out <= vs_d;
        hb_out <= hb_d;
        vb_out <= vb_d;
        de_out <= de_d;
        if(enable) begin
            y <= r_y + g_y + b_y;
        end
        else begin
            // Passthrough
            r <= r_y;
            y <= g_y;
            b <= b_y;
        end
    end

    // Extract the 8-bit grayscale value from the shifted result
    // and output on all RGB channels to create a BW image
    assign {r_out, g_out, b_out} = (enable) ? {3{y[8+DW-1:8]}} : {r[8+DW-1:8], y[8+DW-1:8], b[8+DW-1:8]};

endmodule
