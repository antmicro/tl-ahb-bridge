// Copyright 2022 Antmicro
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//

module test_harness
  import Default_pkg::*;
  import TileLinkUL_pkg::*;
  import AHB_pkg::*;
(
  input  wire                             clk_i,
  input  wire                             rst_ni,

  input  wire                             a_valid,
  output wire                             a_ready,
  input  wire                 [2:0]       a_opcode,
  input  wire                 [2:0]       a_param,
  input  wire [Default_pkg::TL_SZW-1:0]   a_size,
  input  wire [Default_pkg::TL_SRCW-1:0]  a_source,
  input  wire  [Default_pkg::TL_AW-1:0]   a_address,
  input  wire [Default_pkg::TL_DBW-1:0]   a_mask,
  input  wire  [Default_pkg::TL_DW-1:0]   a_data,

  output wire                             d_valid,
  input  wire                             d_ready,
  output wire                 [2:0]       d_opcode,
  output wire                 [2:0]       d_param,
  output wire [Default_pkg::TL_SZW-1:0]   d_size,
  output wire [Default_pkg::TL_SRCW-1:0]  d_source,
  output wire [Default_pkg::TL_SINKW-1:0] d_sink,
  output wire  [Default_pkg::TL_DW-1:0]   d_data,
  output wire                             d_error,


  output wire   [Default_pkg::AHB_AW-1:0] haddr,
  output wire                       [2:0] hburst,
  output wire                             hmastlock,
  output wire                       [6:0] hprot,
  output wire                       [2:0] hsize,
  output wire                             hnonsec,
  output wire                             hexcl,
  output wire   [Default_pkg::AHB_NM-1:0] hmaster,
  output wire                       [1:0] htrans,
  output wire   [Default_pkg::AHB_DW-1:0] hwdata,
  output wire   [Default_pkg::AHB_DS-1:0] hwstrb,
  output wire                             hwrite,

  input  wire   [Default_pkg::AHB_DW-1:0] hrdata,
  input  wire                             hready,
  input  wire                             hresp,
  input  wire                             hexokay
);

  h_manager_out_t ahb_o;
  h_manager_in_t  ahb_i;

  tl_m2s_t        tl_i;
  tl_s2m_t        tl_o;

  assign tl_i = '{
    a_valid:    a_valid,
    a_opcode:   a_opcode,
    a_param:    a_param,
    a_size:     a_size,
    a_source:   a_source,
    a_address:  a_address,
    a_mask:     a_mask,
    a_data:     a_data,
    d_ready:    d_ready,
    default:    '0
  };

  assign a_ready  = tl_o.a_ready;
  assign d_valid  = tl_o.d_valid;
  assign d_opcode = tl_o.d_opcode;
  assign d_param  = tl_o.d_param;
  assign d_size   = tl_o.d_size;
  assign d_source = tl_o.d_source;
  assign d_sink   = tl_o.d_sink;
  assign d_data   = tl_o.d_data;
  assign d_error  = tl_o.d_error;

  assign ahb_i = '{
    h_rdata:    hrdata,
    h_ready:    hready,
    h_resp:     hresp,
    h_exokay:   hexokay
  };

  assign haddr     = ahb_o.h_address;
  assign hburst    = ahb_o.h_burst;
  assign hmastlock = ahb_o.h_mastlock;
  assign hprot     = ahb_o.h_prot;
  assign hsize     = ahb_o.h_size;
  assign hnonsec   = ahb_o.h_nonsec;
  assign hexcl     = ahb_o.h_excl;
  assign hmaster   = ahb_o.h_master;
  assign htrans    = ahb_o.h_trans;
  assign hwdata    = ahb_o.h_wdata;
  assign hwstrb    = ahb_o.h_wstrb;
  assign hwrite    = ahb_o.h_write;

  TileLinkUL_AHB_Bridge u_bridge (
    .clk_i,
    .rst_ni,

    .tl_i,
    .tl_o,

    .ahb_i,
    .ahb_o
  );
endmodule
