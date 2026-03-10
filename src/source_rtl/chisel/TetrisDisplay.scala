import chisel3._
import chisel3.util._

class TetrisDisplay(
    screenWidth: Int = 640,
    screenHeight: Int = 480,
    colorBitsPerBlock: Int = 2,
    boardRowLenInBits: Int = 20,
    blockSizeInPx: Int = 16,
    boardWidthInBlocks: Int = 10,
    boardHeightInBlocks: Int = 20
) extends RawModule {
  require(colorBitsPerBlock == 3 || colorBitsPerBlock == 2,
    "ColorBitsPerBlock is expected to be 2 or 3 bits")
  require(isPow2(blockSizeInPx),
    "BlockSizeInPx is expected to be power of 2")

  val boardHorizStart = blockSizeInPx * blockSizeInPx
  require(isPow2(boardHorizStart),
    "BoardHorizStart is expected to be power of 2")
  require(boardHorizStart >= blockSizeInPx,
    "Prerequisite (BoardHorizStart >= BlockSizeInPx) not met")

  val boardHorizEnd  = boardHorizStart + boardWidthInBlocks * blockSizeInPx
  val boardVertStart = blockSizeInPx * 4
  val boardVertEnd   = boardVertStart + blockSizeInPx * boardHeightInBlocks

  val coordBitsPerBlock = log2Ceil(blockSizeInPx)
  val boardXCoordDataStartBits = log2Ceil(boardWidthInBlocks * colorBitsPerBlock)
  val boardXCoordBits = log2Ceil(boardWidthInBlocks)
  val boardYCoordBits = log2Ceil(boardHeightInBlocks)

  // VAL_8BIT_TO_VAL_COLOR_BITS(v, bit_count) = ceil((v/255.0)*((1 << bit_count)-1))
  def val8BitToColorBits(v: Int): Int =
    math.ceil((v.toDouble / 255.0) * ((1 << colorBitsPerBlock) - 1).toDouble).toInt

  val io = IO(new Bundle {
    val reset           = Input(Bool())
    val pixelPosIsValid = Input(Bool())
    val pxX             = Input(UInt(10.W))
    val pxY             = Input(UInt(10.W))
    val showGameOver    = Input(Bool())
    val score           = Input(TetrisTypes.ScoreType)

    val boardRowData    = Input(UInt(boardRowLenInBits.W))

    val coordsValid     = Output(Bool())
    val boardYCoord     = Output(UInt(boardYCoordBits.W))

    val vgaR            = Output(UInt(colorBitsPerBlock.W))
    val vgaG            = Output(UInt(colorBitsPerBlock.W))
    val vgaB            = Output(UInt(colorBitsPerBlock.W))
  })

  // --- TetrisScoreDisplay submodule ---
  val scoreDisplay = Module(new TetrisScoreDisplay(
    colorBitsToUse = colorBitsPerBlock,
    digitSizeInPx  = 32
  ))

  val boardXCoord = (io.pxX(9, coordBitsPerBlock) - (boardHorizStart >> coordBitsPerBlock).U)(boardXCoordBits - 1, 0)
  io.boardYCoord := (io.pxY(9, coordBitsPerBlock) - (boardVertStart >> coordBitsPerBlock).U)(boardYCoordBits - 1, 0)

  val xWithinTheBoard = (io.pxX >= boardHorizStart.U(10.W)) & (io.pxX < boardHorizEnd.U(10.W))
  val yWithinTheBoard = (io.pxY >= boardVertStart.U(10.W)) & (io.pxY < boardVertEnd.U(10.W))

  val drawBlockFrameHorizontal = (io.pxY(coordBitsPerBlock - 1, 0) === ((1 << coordBitsPerBlock) - 1).U) |
                                  (io.pxY(coordBitsPerBlock - 1, 0) === 0.U)
  val drawBlockFrameVertical   = io.pxX(coordBitsPerBlock - 1, 0) === ((1 << coordBitsPerBlock) - 1).U
  val drawBlockFrame = drawBlockFrameHorizontal | drawBlockFrameVertical

  val drawBoard = xWithinTheBoard & yWithinTheBoard & ~drawBlockFrame
  val tetrisScorePixelPosIsValid = io.pixelPosIsValid & ~drawBoard
  val gameOverPixelPosIsValid = io.pixelPosIsValid & io.showGameOver

  val drawBlockFrameInBoard = drawBlockFrame & xWithinTheBoard & yWithinTheBoard

  scoreDisplay.io.reset          := io.reset
  scoreDisplay.io.pixelPosIsValid := tetrisScorePixelPosIsValid
  scoreDisplay.io.pxX            := io.pxX
  scoreDisplay.io.pxY            := io.pxY
  scoreDisplay.io.score          := io.score

  // --- TetrisGameOverDisplay submodule ---
  val gameOverDisplay = Module(new TetrisGameOverDisplay(
    colorBitsToUse = colorBitsPerBlock,
    pixelSize      = 4,
    textTopLeftX   = boardHorizStart + 36,
    textTopLeftY   = boardVertStart + 140
  ))

  gameOverDisplay.io.reset          := io.reset
  gameOverDisplay.io.pixelPosIsValid := gameOverPixelPosIsValid
  gameOverDisplay.io.pxX            := io.pxX
  gameOverDisplay.io.pxY            := io.pxY

  // Compute board_x_coord_data_start
  val boardXCoordDataStart = Wire(UInt(boardXCoordDataStartBits.W))
  if (colorBitsPerBlock == 3) {
    boardXCoordDataStart := (boardXCoord << 1).asUInt +& boardXCoord
  } else {
    boardXCoordDataStart := (boardXCoord << 1).asUInt
  }

  // Extract color from board row data
  val color = Wire(UInt(colorBitsPerBlock.W))
  val colorBits = VecInit(Seq.tabulate(colorBitsPerBlock) { i =>
    val candidates = (0 until boardWidthInBlocks * colorBitsPerBlock).map { pos =>
      if (pos >= i) {
        Mux(boardXCoordDataStart === (pos - i).U, io.boardRowData(pos), false.B)
      } else {
        false.B
      }
    }
    candidates.reduce(_ | _)
  })
  color := colorBits.asUInt

  val drawBoardColors = drawBoard & ~drawBlockFrame
  io.coordsValid := drawBoardColors

  val drawScreenOutline = io.pxY === 0.U || io.pxX === 0.U ||
    io.pxY === (screenHeight - 1).U(10.W) || io.pxX === (screenWidth - 1).U(10.W)
  val drawTetrisBoardOutline =
    (((io.pxY === boardVertStart.U) || (io.pxY === boardVertEnd.U)) && (io.pxX >= boardHorizStart.U) && (io.pxX <= boardHorizEnd.U)) ||
    (((io.pxX === boardHorizStart.U) || (io.pxX === boardHorizEnd.U)) && (io.pxY >= boardVertStart.U) && (io.pxY <= boardVertEnd.U))
  val drawOutlines = drawScreenOutline || drawTetrisBoardOutline

  // Display VGA intermediate wires
  val displayVgaR = Wire(UInt(colorBitsPerBlock.W))
  val displayVgaG = Wire(UInt(colorBitsPerBlock.W))
  val displayVgaB = Wire(UInt(colorBitsPerBlock.W))

  displayVgaR := 0.U
  displayVgaG := 0.U
  displayVgaB := 0.U

  // Final outputs: mux between display, game over, and score
  val displayBoard    = drawBoard | drawBlockFrameInBoard | drawOutlines
  val displayGameOver = gameOverDisplay.io.pixelDataValid

  io.vgaR := Mux(displayBoard, Mux(displayGameOver, gameOverDisplay.io.vgaR, displayVgaR), scoreDisplay.io.vgaR)
  io.vgaG := Mux(displayBoard, Mux(displayGameOver, gameOverDisplay.io.vgaG, displayVgaG), scoreDisplay.io.vgaG)
  io.vgaB := Mux(displayBoard, Mux(displayGameOver, gameOverDisplay.io.vgaB, displayVgaB), scoreDisplay.io.vgaB)

  val allOnes = ((1 << colorBitsPerBlock) - 1).U(colorBitsPerBlock.W)

  when(io.pixelPosIsValid & !io.reset) {
    when(drawOutlines) {
      // Screen/board border: red
      displayVgaR := allOnes
      displayVgaG := 0.U
      displayVgaB := 0.U
    }.elsewhen(drawBoardColors) {

      if (colorBitsPerBlock == 2) {
        when(color === 1.U) {
          displayVgaR := "b11".U; displayVgaG := "b01".U; displayVgaB := "b00".U
        }.elsewhen(color === 2.U) {
          displayVgaR := "b00".U; displayVgaG := "b11".U; displayVgaB := "b01".U
        }.elsewhen(color === 3.U) {
          displayVgaR := "b01".U; displayVgaG := "b00".U; displayVgaB := "b11".U
        }
      } else {
        // colorBitsPerBlock == 3
        when(color === 1.U) {
          displayVgaR := val8BitToColorBits(0xaa).U; displayVgaG := val8BitToColorBits(0x00).U; displayVgaB := val8BitToColorBits(0x00).U
        }.elsewhen(color === 2.U) {
          displayVgaR := val8BitToColorBits(0x8b).U; displayVgaG := val8BitToColorBits(0xc5).U; displayVgaB := val8BitToColorBits(0x3f).U
        }.elsewhen(color === 3.U) {
          displayVgaR := val8BitToColorBits(0xec).U; displayVgaG := val8BitToColorBits(0x00).U; displayVgaB := val8BitToColorBits(0x8b).U
        }.elsewhen(color === 4.U) {
          displayVgaR := val8BitToColorBits(0xf6).U; displayVgaG := val8BitToColorBits(0x92).U; displayVgaB := val8BitToColorBits(0x1e).U
        }.elsewhen(color === 5.U) {
          displayVgaR := val8BitToColorBits(0x00).U; displayVgaG := val8BitToColorBits(0xad).U; displayVgaB := val8BitToColorBits(0xee).U
        }.elsewhen(color === 6.U) {
          displayVgaR := val8BitToColorBits(0x8b).U; displayVgaG := val8BitToColorBits(0xc5).U; displayVgaB := val8BitToColorBits(0x3f).U
        }.elsewhen(color === 7.U) {
          displayVgaR := val8BitToColorBits(0x1a).U; displayVgaG := val8BitToColorBits(0x73).U; displayVgaB := val8BitToColorBits(0xba).U
        }
      }
    }
  }
}
