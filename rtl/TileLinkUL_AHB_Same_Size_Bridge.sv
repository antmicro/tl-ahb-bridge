// Copyright 2022 Antmicro
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Synchronous bridge form TL-UL to AHB with same size of data link on both sides

module TileLinkUL_AHB_Same_Size_Bridge
  import TileLinkUL_pkg::*;
  import AHB_pkg::*;
#(
  parameter [Default_pkg::TL_SINKW-1:0] SinkId = 0
) (
  input clk_i,
  input rst_ni,

  input  h_manager_in_t  ahb_i,
  output h_manager_out_t ahb_o,

  input  tl_m2s_t        tl_i,
  output tl_s2m_t        tl_o
);

  typedef struct packed {
    logic    [Default_pkg::TL_AW-1:0] address;
    logic                             write;
    logic                             valid;
    logic   [Default_pkg::TL_SZW-1:0] size;      // TL-UL packet size, must be mirrored in resp
    logic  [Default_pkg::TL_SRCW-1:0] source;    // TL-UL a_source for pending transaction
  } tl_a_packet_ctrl_t;

  localparam tl_a_packet_ctrl_t TL_A_PACKET_CTRL_DEFAULT = '{
    default:  '0
  };

  typedef struct packed {
    logic  [Default_pkg::TL_DBW-1:0] a_wmask;
    logic   [Default_pkg::TL_DW-1:0] a_wdata;
  } tl_a_packet_t;

  localparam tl_a_packet_t TL_A_PACKET_DEFAULT = '{
    default:  '0
  };

  typedef struct packed {
    logic  [Default_pkg::TL_SZW-1:0] size;       // TL-UL packet size, must be mirrored in resp
    logic [Default_pkg::TL_SRCW-1:0] source;     // TL-UL a_source for pending transaction
    logic                            write;
  } ahb_i_ctrl_t;

  localparam ahb_i_ctrl_t AHB_I_CTRL_DEFAULT = '{
    default:  '0
  };

  typedef struct packed {
    logic [Default_pkg::AHB_DW-1:0] rdata;
    logic                           resp;

    logic  [Default_pkg::TL_SZW-1:0] size;       // TL-UL packet size, must be mirrored in resp
    logic [Default_pkg::TL_SRCW-1:0] source;     // TL-UL a_source for pending transaction
    logic                            write;
  } ahb_i_packet_t;

  localparam ahb_i_packet_t AHB_I_PACKET_DEFAULT = '{
    default:  '0
  };

  tl_a_packet_ctrl_t packet_ctrl;
  tl_a_packet_t      packet;

  logic [Default_pkg::AHB_DW-1:0] delayed;

//  tl_d_packet_t s4;

  logic pipeline_ready;

  logic s1_ack;

  logic s2_ready;      // Stage 2 is ready when there are no packets to be send or bus can perform addres phase

  logic        s3_ready;      // Stage 3 is ready when there are no transactions on the bus or bus has respons to pending transaction
  logic        s3_listen;     // Transaction is pending
  ahb_i_ctrl_t s3_ctrl;

  logic          s4_ready;
  logic          s4_send;
  ahb_i_packet_t s4_packet;
  logic          s4_ack;


  assign pipeline_ready = s2_ready & s3_ready & s4_ready;
  // Stage 1 -> Get TL-UL command

  assign s1_ack = tl_i.a_valid & (pipeline_ready | ahb_o.h_trans == Idle);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      packet <= TL_A_PACKET_DEFAULT;
    end else if(s1_ack) begin
      packet <= '{
                a_wmask:  tl_i.a_mask,
                a_wdata:  tl_i.a_data
      };
    end else if(pipeline_ready) begin
      packet <= TL_A_PACKET_DEFAULT;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      packet_ctrl <= TL_A_PACKET_CTRL_DEFAULT;
    end else if(s1_ack) begin
      packet_ctrl <= '{
        address:   tl_i.a_address,
        write:     tl_i.a_opcode != Get,
        valid:     1'b1,
        size:      tl_i.a_size,
        source:    tl_i.a_source
      };
    end else if(pipeline_ready) begin
      packet_ctrl <= TL_A_PACKET_CTRL_DEFAULT;
    end
  end

  // Stage 2 -> Operate AHB

  assign s2_ready = !packet_ctrl.valid | ahb_i.h_ready;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      s3_ctrl <= AHB_I_CTRL_DEFAULT;
    end else if (packet_ctrl.valid & ahb_i.h_ready) begin
      s3_ctrl <= '{
        size:   packet_ctrl.size,
        source: packet_ctrl.source,
        write:  packet_ctrl.write
      };
    end else if (pipeline_ready) begin
      s3_ctrl <= AHB_I_CTRL_DEFAULT;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      s3_listen <= 1'b0;
    end else if (packet_ctrl.valid & ahb_i.h_ready) begin
      s3_listen <= 1'b1;
    end else if (pipeline_ready) begin
      s3_listen <= 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      delayed <= '0;
    end else if (packet_ctrl.valid & ahb_i.h_ready) begin
      delayed <= packet.a_wdata;
    end else if (!packet_ctrl.valid & ahb_i.h_ready) begin
      delayed <= '0;
    end
  end

  always_comb begin
    if (packet_ctrl.valid) begin
      ahb_o = '{
        h_address:  packet_ctrl.address,
        h_burst:    Incr,
        h_mastlock: 1'b0,
        h_prot:     {DataAcs, UnPrivAcs, UnBuff, Strict, Allow, NoAlloc, Shared},
        h_size:     {'0, packet_ctrl.size},
        h_nonsec:   Secure,
        h_master:   '0,
        h_excl:     NonExclusive,
        h_trans:    NonSeq,
        h_wdata:    '0,
        h_wstrb:    packet.a_wmask,
        h_write:    packet_ctrl.write
      };
    end else begin
      ahb_o = AHB_MANAGER_OUT_DEFAULT;
    end
    ahb_o.h_wdata = delayed;
  end

  // Stage 3 -> Get last AHB response

  assign s3_ready = !s3_listen | ahb_i.h_ready;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      s4_send <= 1'b0;
    end else if (s3_listen & ahb_i.h_ready) begin
      s4_send <= 1'b1;
    end else if (pipeline_ready | s4_ack) begin
      s4_send <= 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      s4_packet <= AHB_I_PACKET_DEFAULT;
    end else if (s3_listen & ahb_i.h_ready) begin
      s4_packet <= '{
        rdata:  ahb_i.h_rdata,
        resp:   ahb_i.h_resp,
        size:   s3_ctrl.size,
        source: s3_ctrl.source,
        write:  s3_ctrl.write
      };
    end else if (pipeline_ready) begin
      s4_packet <= AHB_I_PACKET_DEFAULT;
    end
  end

  // Stage 4 -> Send TL-UL response

  assign s4_ready = !s4_send | s4_ack;
  assign s4_ack = s4_send & tl_i.d_ready;

  assign tl_o = '{
    a_ready:  s1_ack,
    d_valid:  s4_send,
    d_opcode: s4_packet.write ? AccessAckData : AccessAck,
    d_param:  '0,
    d_size:   s4_packet.size,
    d_source: s4_packet.source,
    d_sink:   SinkId,
    d_data:   s4_packet.rdata,
    d_error:  s4_packet.resp,
    default:  '0
  };
endmodule
