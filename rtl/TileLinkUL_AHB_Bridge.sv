// Copyright 2022 Antmicro
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Synchronous bridge from TL-UL(Slave) to AHB(Manager)

module TileLinkUL_AHB_Bridge
  import TileLinkUL_pkg::*;
  import AHB_pkg::*;
#(
  parameter                         int SinkIdWidth = 8,
  parameter [Default_pkg::TL_SINKW-1:0] SinkId = 0
) (
  input clk_i,
  input rst_ni,

  input h_manager_in_t   ahb_i,
  output h_manager_out_t ahb_o,

  input tl_m2s_t         tl_i,
  output tl_s2m_t        tl_o
);

  logic     err, tl_err, err_send;
  logic     d_ack;
  tl_m2s_t  bridge_input;
  tl_s2m_t  bridge_output, err_output;

  TileLinkUL_err_check u_err (
    .clk_i,
    .rst_ni,
    .tl_i,
    .err_o (tl_err)
  );

  assign err = tl_i.a_valid & (tl_err);
  assign d_ack = tl_i.d_ready & tl_o.d_valid & err_send;

  assign bridge_input = '{
    a_valid:   err ? 1'b0 : tl_i.a_valid,
    a_opcode:  tl_i.a_opcode,
    a_param:   tl_i.a_param,
    a_size:    tl_i.a_size,
    a_source:  tl_i.a_source,
    a_address: tl_i.a_address,
    a_mask:    tl_i.a_mask,
    a_data:    tl_i.a_data,
    d_ready:   err_send ? 1'b0 : tl_i.d_ready
  };

  assign tl_o = '{
    a_ready:    err ? 1'b1 : bridge_output.a_ready,
    d_valid:    err_send ? err_output.d_valid : bridge_output.d_valid,
    d_opcode:   err_send ? err_output.d_opcode : bridge_output.d_opcode,
    d_param:    err_send ? err_output.d_param : bridge_output.d_param,
    d_size:     err_send ? err_output.d_size : bridge_output.d_size,
    d_source:   err_send ? err_output.d_source : bridge_output.d_source,
    d_sink:     err_send ? err_output.d_sink : bridge_output.d_sink,
    d_data:     err_send ? err_output.d_data : bridge_output.d_data,
    d_error:    err_send ? err_output.d_error : bridge_output.d_error
  };

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      err_send <= 1'b0;
    end else if(err) begin
      err_send <= 1'b1;
    end else if(d_ack) begin
      err_send <= 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      err_output <= '0;
    end else if(err) begin
      err_output <= '{
        d_valid:  1'b1,
        d_size:   tl_i.a_size,
        d_opcode: tl_i.a_opcode == Get ? AccessAckData : AccessAck,
        d_source: tl_i.a_source,
        d_sink:   SinkId,
        d_error:  1'b1,
        default:  '0
      };
    end
  end

  generate
    if (Default_pkg::AHB_DW == Default_pkg::TL_DW) begin
      TileLinkUL_AHB_Same_Size_Bridge #(
        .SinkId
      ) bridge(
        .clk_i,
        .rst_ni,

        .ahb_i,
        .ahb_o,

        .tl_i(bridge_input),
        .tl_o(bridge_output)
      );
    end else begin
      $fatal("No bridge found for AHB data width and TL data width");
    end
  endgenerate

endmodule
