`default_nettype none  // Don't allow undeclared nets

`include "HelperMacros.svh"

module TetrisShapeDataProvider #(
    parameter int unsigned ShapeCount = 7
) (
    input logic [$clog2(7)-1:0] shape_selector_i,
    input logic [1:0] shape_rotation_selector_i,
    input logic [1:0] shape_data_row_index_i,

    output logic [3:0] shape_row_data_o,

    output logic [1:0] current_shape_last_rotation_id_o
);
  logic [7:0] shape_data[2];

  always_comb begin
    `ASSERT(ShapeCount <= 7, "Inconsistent configuration");

    shape_row_data_o = '0;
    current_shape_last_rotation_id_o = '0;
    shape_data[0] = '0;
    shape_data[1] = '0;

    case (shape_selector_i)
      /*--------------------
      TetrisChape_I

      # # # #
      @ @ @ @
      # # # #
      # # # #

      @ # # #
      @ # # #
      @ # # #
      @ # # #
      --------------------*/
      3'd0: begin
        current_shape_last_rotation_id_o = 1;
        if (shape_rotation_selector_i == '0) begin
          shape_data[0] = 8'b11110000;
          shape_data[1] = 8'b00000000;
        end
        if (shape_rotation_selector_i == 1) begin
          shape_data[0] = 8'b00010001;
          shape_data[1] = 8'b00010001;
        end
      end

      /*--------------------
      TetrisChape_T

      # # # #
      @ @ @ #
      # @ # #
      # # # #

      # @ # #
      @ @ # #
      # @ # #
      # # # #

      # @ # #
      @ @ @ #
      # # # #
      # # # #

      @ # # #
      @ @ # #
      @ # # #
      # # # #
      --------------------*/
      3'd1: begin
        current_shape_last_rotation_id_o = 3;
        if (shape_rotation_selector_i == '0) begin
          shape_data[0] = 8'b01110000;
          shape_data[1] = 8'b00000010;
        end
        if (shape_rotation_selector_i == 1) begin
          shape_data[0] = 8'b00110010;
          shape_data[1] = 8'b00000010;
        end
        if (shape_rotation_selector_i == 2) begin
          shape_data[0] = 8'b01110010;
          shape_data[1] = 8'b00000000;
        end
        if (shape_rotation_selector_i == 3) begin
          shape_data[0] = 8'b00110001;
          shape_data[1] = 8'b00000001;
        end
      end

      /*--------------------
      TetrisChape_J

      # # # #
      @ @ @ #
      @ # # #
      # # # #

      @ @ # #
      # @ # #
      # @ # #
      # # # #

      # # @ #
      @ @ @ #
      # # # #
      # # # #

      @ # # #
      @ # # #
      @ @ # #
      # # # #
      --------------------*/

      3'd2: begin
        current_shape_last_rotation_id_o = 3;
        if (shape_rotation_selector_i == '0) begin
          shape_data[0] = 8'b01110000;
          shape_data[1] = 8'b00000001;
        end
        if (shape_rotation_selector_i == 1) begin
          shape_data[0] = 8'b00100011;
          shape_data[1] = 8'b00000010;
        end
        if (shape_rotation_selector_i == 2) begin
          shape_data[0] = 8'b01110100;
          shape_data[1] = 8'b00000000;
        end
        if (shape_rotation_selector_i == 3) begin
          shape_data[0] = 8'b00010001;
          shape_data[1] = 8'b00000011;
        end
      end

      /*--------------------
      TetrisChape_L

      @ # # #
      @ @ @ #
      # # # #
      # # # #

      @ @ # #
      @ # # #
      @ # # #
      # # # #

      # # # #
      @ @ @ #
      # # @ #
      # # # #

      # @ # #
      # @ # #
      @ @ # #
      # # # #
      --------------------*/
      3'd3: begin
        current_shape_last_rotation_id_o = 3;
        if (shape_rotation_selector_i == '0) begin
          shape_data[0] = 8'b01110001;
          shape_data[1] = 8'b00000000;
        end
        if (shape_rotation_selector_i == 1) begin
          shape_data[0] = 8'b00010011;
          shape_data[1] = 8'b00000001;
        end
        if (shape_rotation_selector_i == 2) begin
          shape_data[0] = 8'b01110000;
          shape_data[1] = 8'b00000100;
        end
        if (shape_rotation_selector_i == 3) begin
          shape_data[0] = 8'b00100010;
          shape_data[1] = 8'b00000011;
        end
      end

      /*--------------------
      TetrisChape_Z

      # # # #
      @ @ # #
      # @ @ #
      # # # #

      # @ # #
      @ @ # #
      @ # # #
      # # # #
      --------------------*/
      3'd4: begin
        current_shape_last_rotation_id_o = 1;
        if (shape_rotation_selector_i == '0) begin
          shape_data[0] = 8'b00110000;
          shape_data[1] = 8'b00000110;
        end
        if (shape_rotation_selector_i == 1) begin
          shape_data[0] = 8'b00110010;
          shape_data[1] = 8'b00000001;
        end
      end

      /*--------------------
      TetrisChape_S

      # # # #
      # @ @ #
      @ @ # #
      # # # #

      @ # # #
      @ @ # #
      # @ # #
      # # # #
      --------------------*/
      3'd5: begin
        current_shape_last_rotation_id_o = 1;
        if (shape_rotation_selector_i == '0) begin
          shape_data[0] = 8'b01100000;
          shape_data[1] = 8'b00000011;
        end
        if (shape_rotation_selector_i == 1) begin
          shape_data[0] = 8'b00110001;
          shape_data[1] = 8'b00000010;
        end
      end

      /*--------------------
      TetrisChape_O

      @ @ # #
      @ @ # #
      # # # #
      # # # #
      --------------------*/
      3'd6: begin
        current_shape_last_rotation_id_o = 0;
        if (shape_rotation_selector_i == '0) begin
          shape_data[0] = 8'b00110011;
          shape_data[1] = 8'b00000000;
        end
      end

      default: begin
      end
    endcase

    if (shape_data_row_index_i <= 3) begin
      if (shape_data_row_index_i == 0) begin
        shape_row_data_o = shape_data[0][3:0];
      end else if (shape_data_row_index_i == 1) begin
        shape_row_data_o = shape_data[0][7:4];
      end else if (shape_data_row_index_i == 2) begin
        shape_row_data_o = shape_data[1][3:0];
      end else if (shape_data_row_index_i == 3) begin
        shape_row_data_o = shape_data[1][7:4];
      end
    end
  end
endmodule
