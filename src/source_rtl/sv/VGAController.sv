`default_nettype none

// `define USE_FAST_CLOCK

module VGAController #(
    parameter int ScreenWidth = 640,
    parameter int ScreenHeight = 480
) (
    input wire px_clk_i,  // Input clock: 25.175MHz
    input wire reset_i,   // reset

    output logic       h_sync_o,             // Horizontal Sync
    output logic       v_sync_o,             // Vertical Sync
    output logic [9:0] pixel_pos_x_o,        // X coordinate of a visible pixel (0 to screen width)
    output logic [9:0] pixel_pos_y_o,        // Y coordinate of a visible pixel (0 to screen height)
    output logic       pixel_pos_is_valid_o
);

  //
  // http://www.epanorama.net/faq/vga2rgb/calc.html
  //

  localparam int HPixels = ScreenWidth;  // H-PIX Number of pixels horisontally
  localparam int VPixels = ScreenHeight;  // V-PIX Number of pixels vertically

`ifdef USE_FAST_CLOCK
  // 31.5 MHz
  localparam int HPulse = 40;  // H-SYNC pulse width 96 * 40 ns (25 Mhz) = 3.84 uS
  localparam int HBackPorch = 128;  // H-BP back porch pulse width
  localparam int HFrontPorch = 24;  // H-FP front porch pulse width
  //localparam logic HPol = 1'b0;  // H-SYNC polarity

  localparam int VPulse = 3;  // V-SYNC pulse width
  localparam int VBackPorch = 28;  // V-BP back porch pulse width
  localparam int VFrontPorch = 9;  // V-FP front porch pulse width
  //localparam logic VPol = 1'b1;  // V-SYNC polarity
`else
  // 21.175 MHz
  localparam int HPulse = 96;  // H-SYNC pulse width
  localparam int HBackPorch = 48;  // H-BP back porch pulse width
  localparam int HFrontPorch = 16;  // H-FP front porch pulse width
  //localparam logic HPol = 1'b0;  // H-SYNC polarity

  localparam int VPulse = 2;  // V-SYNC pulse width
  localparam int VBackPorch = 33;  // V-BP back porch pulse width
  localparam int VFrontPorch = 10;  // V-FP front porch pulse width
  //localparam logic VPol = 1'b1;  // V-SYNC polarity
`endif  // USE_FAST_CLOCK

  localparam int HFrame = (HPulse + HBackPorch + HPixels + HFrontPorch);
  localparam int VFrame = (VPulse + VBackPorch + VPixels + VFrontPorch);

  localparam int VSyncPulseStart = (VPixels + VFrontPorch);
  localparam int VSyncPulseEnd = (VSyncPulseStart + VPulse);

  logic [9:0] horizontal_counter_q;
  logic [9:0] horizontal_counter_d;
  logic [9:0] vertical_counter_q;
  logic [9:0] vertical_counter_d;

  logic [9:0] pixel_pos_x_q;
  logic [9:0] pixel_pos_x_d;
  logic [9:0] pixel_pos_y_q;
  logic [9:0] pixel_pos_y_d;

  wire is_visible_horiz_pixel;
  wire is_visible_vert_pixel;

  assign pixel_pos_x_o = pixel_pos_x_q;
  assign pixel_pos_y_o = pixel_pos_y_q;

  always @(posedge px_clk_i) begin
    if (reset_i) begin
      horizontal_counter_q <= 0;
      vertical_counter_q <= 0;

      pixel_pos_x_q <= 0;
      pixel_pos_y_q <= 0;
    end else begin
      horizontal_counter_q <= horizontal_counter_d;
      vertical_counter_q <= vertical_counter_d;
      pixel_pos_x_q <= pixel_pos_x_d;
      pixel_pos_y_q <= pixel_pos_y_d;
    end
  end

  always_comb begin
    horizontal_counter_d = horizontal_counter_q + 1;
    vertical_counter_d = vertical_counter_q;
    pixel_pos_x_d = pixel_pos_x_q;
    pixel_pos_y_d = pixel_pos_y_q;

    if (pixel_pos_x_q < $bits(pixel_pos_x_q)'(HPixels - 1)) begin
      pixel_pos_x_d = pixel_pos_x_q + 1;
    end else if (horizontal_counter_q == $bits(horizontal_counter_q)'(HFrame - 1)) begin
      horizontal_counter_d = '0;
      pixel_pos_x_d = '0;

      if (vertical_counter_q == $bits(vertical_counter_q)'(VFrame - 1)) begin
        vertical_counter_d = '0;
        pixel_pos_y_d = '0;
      end else begin
        vertical_counter_d = vertical_counter_q + 1;

        if (pixel_pos_y_q < $bits(pixel_pos_y_q)'(VPixels - 1)) begin
          pixel_pos_y_d = pixel_pos_y_q + 1;
        end
      end
    end
  end

  assign is_visible_horiz_pixel = ((horizontal_counter_q < $bits(horizontal_counter_q)'(HPixels)));
  assign is_visible_vert_pixel = ((vertical_counter_q < $bits(vertical_counter_q)'(VPixels)));

  assign h_sync_o = reset_i || (horizontal_counter_q >= $bits(
      horizontal_counter_q
  )'(HPixels + HFrontPorch)) && (horizontal_counter_q < $bits(
      horizontal_counter_q
  )'(HPixels + HFrontPorch + HPulse)) ? 1'b0 : 1'b1;
  assign v_sync_o = reset_i || (vertical_counter_q >= $bits(
      vertical_counter_q
  )'(VSyncPulseStart)) && (vertical_counter_q < $bits(
      vertical_counter_q
  )'(VSyncPulseEnd)) ? 1'b0 : 1'b1;

  assign pixel_pos_is_valid_o = !reset_i && (is_visible_horiz_pixel && is_visible_vert_pixel);
endmodule

