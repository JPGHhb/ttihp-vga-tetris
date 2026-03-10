import chisel3._
import chisel3.util._

class TetrisScoreDisplay(
    colorBitsToUse: Int = 2,
    digitSizeInPx: Int = 32
) extends RawModule {
  val scoreDigitCount = TetrisTypes.ScoreDigitCount
  require(colorBitsToUse == 3 || colorBitsToUse == 2,
    "ColorBitsToUse is expected to be 2 or 3 bits")
  require(isPow2(digitSizeInPx),
    "DigitSizeInPx is expected to be power of 2")

  val coordBits = 10

  val boardHorizStart = (16 * 16) + 16 + 4
  val boardHorizEnd   = boardHorizStart + scoreDigitCount * digitSizeInPx
  val boardVertStart  = digitSizeInPx
  val boardVertEnd    = boardVertStart + digitSizeInPx

  val numOfRealRowFields    = 3
  val numOfLogicalRowFields = 4
  val numOfRealRows         = 5

  val coordBitsPerDigit = log2Ceil(digitSizeInPx)

  require(boardHorizStart % numOfLogicalRowFields == 0,
    "BoardHorizStart is expected to be divisible by NumOfLogicalRowFields")
  require(boardHorizStart >= digitSizeInPx,
    "Prerequisite (BoardHorizStart >= DigitSizeInPx) not met")

  val io = IO(new Bundle {
    val reset          = Input(Bool())
    val pixelPosIsValid = Input(Bool())
    val pxX            = Input(UInt(coordBits.W))
    val pxY            = Input(UInt(coordBits.W))
    val score          = Input(TetrisTypes.ScoreType)

    val vgaR           = Output(UInt(colorBitsToUse.W))
    val vgaG           = Output(UInt(colorBitsToUse.W))
    val vgaB           = Output(UInt(colorBitsToUse.W))
  })

  val scoreXCoord = (io.pxX - boardHorizStart.U(coordBits.W))(coordBits - 1, 0)
  val scoreYCoord = (io.pxY - boardVertStart.U(coordBits.W))(coordBits - 1, 0)

  val scoreDigitIndexBits = log2Ceil(scoreDigitCount)
  val scoreDigitIndex = scoreXCoord(coordBitsPerDigit + scoreDigitIndexBits - 1, coordBitsPerDigit)

  val digitXCoord = scoreXCoord(coordBitsPerDigit - 1, 0)
  val digitYCoord = scoreYCoord(coordBitsPerDigit - 1, 0)

  // Font bitmap: 10 digits x 5 rows, each row is 3 bits
  val fontBitmap = VecInit(Seq(
    // @ @ @
    // @   @
    // @   @
    // @   @
    // @ @ @
    VecInit(Seq("b111".U(3.W), "b101".U(3.W), "b101".U(3.W), "b101".U(3.W), "b111".U(3.W))),
    
    // @ @
    //   @
    //   @
    //   @
    // @ @ @
    VecInit(Seq("b110".U(3.W), "b010".U(3.W), "b010".U(3.W), "b010".U(3.W), "b111".U(3.W))),

    // @ @ @
    //     @
    // @ @ @
    // @
    // @ @ @
    VecInit(Seq("b111".U(3.W), "b001".U(3.W), "b111".U(3.W), "b100".U(3.W), "b111".U(3.W))),

    // @ @ @
    //     @
    // @ @ @
    //     @
    // @ @ @
    VecInit(Seq("b111".U(3.W), "b001".U(3.W), "b111".U(3.W), "b001".U(3.W), "b111".U(3.W))),

    // @   @
    // @   @
    // @ @ @
    //     @
    //     @
    VecInit(Seq("b101".U(3.W), "b101".U(3.W), "b111".U(3.W), "b001".U(3.W), "b001".U(3.W))),

    // @ @ @
    // @
    // @ @ @
    //     @
    // @ @ @
    VecInit(Seq("b111".U(3.W), "b100".U(3.W), "b111".U(3.W), "b001".U(3.W), "b111".U(3.W))),

    // @ @ @
    // @
    // @ @ @
    // @   @
    // @ @ @
    VecInit(Seq("b111".U(3.W), "b100".U(3.W), "b111".U(3.W), "b101".U(3.W), "b111".U(3.W))),

    // @ @ @
    //     @
    //     @
    //     @
    //     @
    VecInit(Seq("b111".U(3.W), "b001".U(3.W), "b001".U(3.W), "b001".U(3.W), "b001".U(3.W))),

    // @ @ @
    // @   @
    // @ @ @
    // @   @
    // @ @ @
    VecInit(Seq("b111".U(3.W), "b101".U(3.W), "b111".U(3.W), "b101".U(3.W), "b111".U(3.W))),

    // @ @ @
    // @   @
    // @ @ @
    //     @
    // @ @ @
    VecInit(Seq("b111".U(3.W), "b101".U(3.W), "b111".U(3.W), "b001".U(3.W), "b111".U(3.W)))
  ))

  // font_bitmap_x_index = digit_x_coord / (2 * NumOfLogicalRowFields)
  val xDivBits = log2Ceil(2 * numOfLogicalRowFields)
  val fontBitmapXIndex = digitXCoord(xDivBits + 1, xDivBits)

  // font_bitmap_y_index = (digit_y_coord - (digit_y_coord >> 2)) >> 2
  // This approximates digit_y_coord / 5
  val fontBitmapYIndex = ((digitYCoord - (digitYCoord >> 2)) >> 2)(2, 0)

  val fontBitmapXIndexValid = fontBitmapXIndex <= (numOfRealRowFields - 1).U
  val fontBitmapYIndexValid = fontBitmapYIndex <= (numOfRealRows - 1).U

  val xWithinTheScore = (io.pxX >= boardHorizStart.U) & (io.pxX < boardHorizEnd.U)
  val yWithinTheScore = (io.pxY >= boardVertStart.U) & (io.pxY < boardVertEnd.U)
  val drawScore = xWithinTheScore & yWithinTheScore & fontBitmapXIndexValid & fontBitmapYIndexValid

  val scoreDigit = Wire(UInt(4.W))
  scoreDigit := 0.U
  when(drawScore) {
    scoreDigit := io.score((scoreDigitCount - 1).U - scoreDigitIndex)
  }

  val allOnes = ((1 << colorBitsToUse) - 1).U(colorBitsToUse.W)

  io.vgaR := 0.U
  io.vgaG := 0.U
  io.vgaB := 0.U

  val digitRow = Wire(UInt(3.W))
  digitRow := 0.U

  when(io.pixelPosIsValid & !io.reset) {
    when(drawScore) {
      digitRow := fontBitmap(scoreDigit)(fontBitmapYIndex)

      when(digitRow(2.U - fontBitmapXIndex)) {
        // Yellow color
        io.vgaR := allOnes
        io.vgaG := allOnes
        io.vgaB := 0.U
      }
    }
  }
}
