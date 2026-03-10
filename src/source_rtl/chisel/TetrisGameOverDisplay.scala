import chisel3._
import chisel3.util._

class TetrisGameOverDisplay(
    colorBitsToUse: Int = 2,
    pixelSize: Int = 4,
    textTopLeftX: Int = 0,
    textTopLeftY: Int = 0
) extends RawModule {
  require(isPow2(pixelSize),
    "PixelSize must be a power of 2")
  require(textTopLeftX % pixelSize == 0,
    "TextTopLeftX must be divisible by PixelSize")
  require(textTopLeftY % pixelSize == 0,
    "TextTopLeftY must be divisible by PixelSize")

  val textLineBits = 23

  val gameOverTextLines = VecInit(Seq(
    "b11111010001011111011111".U(textLineBits.W),
    "b00001011011010001000001".U(textLineBits.W),
    "b01111010101011111011001".U(textLineBits.W),
    "b00001010001010001010001".U(textLineBits.W),
    "b11111010001010001011111".U(textLineBits.W),
    "b00000000000000000000000".U(textLineBits.W),
    "b11111011111010001011111".U(textLineBits.W),
    "b10001000001010001010001".U(textLineBits.W),
    "b11111001111001010010001".U(textLineBits.W),
    "b01001000001001010010001".U(textLineBits.W),
    "b10001011111000100011111".U(textLineBits.W)
  ))

  val coordBits = 10

  val maxXCoord = textLineBits - 1
  val maxYCoord = gameOverTextLines.length - 1

  val textWidthInPixels  = (maxXCoord + 1) * pixelSize
  val textHeightInPixels = (maxYCoord + 1) * pixelSize

  val pixelSizeLog2 = log2Ceil(pixelSize)

  val xBits = log2Ceil(maxXCoord + 1)
  val yBits = log2Ceil(maxYCoord + 1)

  val textHorizStart = textTopLeftX
  val textHorizEnd   = textHorizStart + textWidthInPixels
  val textVertStart  = textTopLeftY
  val textVertEnd    = textVertStart + textHeightInPixels

  val io = IO(new Bundle {
    val reset          = Input(Bool())
    val pixelPosIsValid = Input(Bool())
    val pxX            = Input(UInt(coordBits.W))
    val pxY            = Input(UInt(coordBits.W))

    val vgaR           = Output(UInt(colorBitsToUse.W))
    val vgaG           = Output(UInt(colorBitsToUse.W))
    val vgaB           = Output(UInt(colorBitsToUse.W))
    val pixelDataValid = Output(Bool())
  })

  val textCoordStartX = (io.pxX - textHorizStart.U(coordBits.W))(coordBits - 1, 0)
  val textCoordStartY = (io.pxY - textVertStart.U(coordBits.W))(coordBits - 1, 0)

  val textCoordX = textCoordStartX(xBits - 1 + pixelSizeLog2, pixelSizeLog2)
  val textCoordY = textCoordStartY(yBits - 1 + pixelSizeLog2, pixelSizeLog2)

  val xCoordIsValid = textCoordX <= maxXCoord.U
  val yCoordIsValid = textCoordY <= maxYCoord.U

  val inTextDrawingArea = (io.pxX >= textHorizStart.U) & (io.pxX <= textHorizEnd.U) &
                          (io.pxY >= textVertStart.U) & (io.pxY <= textVertEnd.U)

  val allOnes = ((1 << colorBitsToUse) - 1).U(colorBitsToUse.W)

  io.vgaR := 0.U
  io.vgaG := 0.U
  io.vgaB := 0.U
  io.pixelDataValid := false.B

  when(io.pixelPosIsValid & !io.reset) {
    when(inTextDrawingArea & xCoordIsValid & yCoordIsValid) {
      when(gameOverTextLines(textCoordY)(textCoordX)) {
        io.pixelDataValid := true.B
        io.vgaR := allOnes
      }
    }
  }
}
