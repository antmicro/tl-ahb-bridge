// Copyright 2022 Antmicro
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0


module TileLinkUL_err_check
  import TileLinkUL_pkg::*;
(
  input clk_i,
  input rst_ni,

  input tl_m2s_t tl_i,

  output logic err_o
);

  logic opcode_allowed, a_config_allowed;

  logic op_full, op_partial, op_get;
  assign op_full    = (tl_i.a_opcode == PutFullData);
  assign op_partial = (tl_i.a_opcode == PutPartialData);
  assign op_get     = (tl_i.a_opcode == Get);

  // opcode check
  assign opcode_allowed = (tl_i.a_opcode == PutFullData)
                        | (tl_i.a_opcode == PutPartialData)
                        | (tl_i.a_opcode == Get);

  // a channel configuration check
  logic addr_sz_chk;    // address and size alignment check
  logic mask_chk;       // inactive lane a_mask check
  logic fulldata_chk;   // PutFullData should have size match to mask

  logic [Default_pkg::TL_DBW-1:0] mask;

  localparam int SubAW = $clog2(Default_pkg::TL_DBW);

  assign mask = (1 << tl_i.a_address[SubAW-1:0]);

  always_comb begin
    addr_sz_chk  = 1'b0;
    mask_chk     = 1'b0;
    fulldata_chk = 1'b0; // Only valid when opcode is PutFullData

    if (tl_i.a_valid) begin
      unique case (tl_i.a_size)
        'h0: begin // 1 Byte
          addr_sz_chk  = 1'b1;
          mask_chk     = op_get ? |(tl_i.a_mask & mask) & ~|(tl_i.a_mask & ~mask)
                                : ~|(tl_i.a_mask & ~mask);
          fulldata_chk = 1'b0;
        end

        'h1: begin // 2 Byte
          addr_sz_chk  = ~tl_i.a_address[0];
          // check inactive lanes
          mask_chk     = op_get ? (tl_i.a_address[1]) ? &tl_i.a_mask[3:2] & ~|tl_i.a_mask[1:0]
                                                      : &tl_i.a_mask[1:0] & ~|tl_i.a_mask[3:2]
                                : (tl_i.a_address[1]) ? ~|(tl_i.a_mask & 4'b0011)  // if upper 2B are valid, check lower
                                                      : ~|(tl_i.a_mask & 4'b1100); // if lower 2B are valid, check upper
          fulldata_chk = 1'b0;
        end

        'h2: begin // 4 Byte
          addr_sz_chk  = ~|tl_i.a_address[SubAW-1:0];
          mask_chk     = op_get ? &tl_i.a_mask[3:0] : 1'b1;
          fulldata_chk = &tl_i.a_mask[3:0];
        end

        default: begin // else
          addr_sz_chk  = 1'b0;
          mask_chk     = 1'b0;
          fulldata_chk = 1'b0;
        end
      endcase
    end else begin
      addr_sz_chk  = 1'b0;
      mask_chk     = 1'b0;
      fulldata_chk = 1'b0;
    end
  end

  assign a_config_allowed = addr_sz_chk
                          & mask_chk
                          & (op_get | op_partial | fulldata_chk);

  // error calculation
  assign err_o = ~(opcode_allowed & a_config_allowed);
endmodule
