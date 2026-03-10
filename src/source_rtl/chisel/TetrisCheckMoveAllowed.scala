import chisel3._
import chisel3.util._

class TetrisCheckMoveAllowed(
    colorBitsPerBlock: Int = 2,
    boardWidthInBlocks: Int = 10,
    rowLenInBits: Int = 20
) extends Module {
  require((boardWidthInBlocks * colorBitsPerBlock) <= rowLenInBits, "Inconsistent configuration")

  val shapeRowBits         = 4
  val compressedRowBits    = boardWidthInBlocks + shapeRowBits
  val shapeXCoordBits      = log2Ceil(rowLenInBits / colorBitsPerBlock)

  val io = IO(new Bundle {
    val startCheck            = Input(Bool())
    val shapeRowData          = Input(UInt(shapeRowBits.W))
    val boardRowData          = Input(UInt(rowLenInBits.W))
    val shapeXCoord           = Input(UInt(shapeXCoordBits.W))
    val rowIndexIsOutOfRange  = Input(Bool())

    val rowIndex              = Output(UInt(2.W))
    val moveAllowed           = Output(Bool())
    val checkDone             = Output(Bool())
  })

  // Registers with Q/D pattern
  val rowIndexQ        = RegInit(0.U(2.W))
  val checkIsRunningQ  = RegInit(false.B)
  val doneQ            = RegInit(false.B)

  io.rowIndex  := rowIndexQ
  io.checkDone := doneQ

  // Compress the board row: OR-reduce each ColorBitsPerBlock-wide block into 1 bit,
  // then pad with 1s beyond the board width
  val compressedBoardRow = Wire(UInt(compressedRowBits.W))
  val compressedBits = VecInit(Seq.tabulate(compressedRowBits) { i =>
    if (i < boardWidthInBlocks) {
      // OR-reduce the color bits for block i
      io.boardRowData((i * colorBitsPerBlock) + (colorBitsPerBlock - 1), (i * colorBitsPerBlock)).orR
    } else {
      true.B
    }
  })
  compressedBoardRow := compressedBits.asUInt

  // Check if shape_x_coord is outside the valid range
  val shapeXCoordOutsideRange = (io.shapeXCoord +& shapeRowBits.U) > compressedRowBits.U

  val shapeXCoord = Mux(shapeXCoordOutsideRange, 0.U, io.shapeXCoord)

  val runningOrAssertingDone = checkIsRunningQ || doneQ

  val fullShapeRow = ((1 << shapeRowBits) - 1).U(shapeRowBits.W)

  // Dynamic bit-slice: compressed_board_row[shape_x_coord +: ShapeRowBits]
  // Generate per-bit mux trees to avoid dynamic shifts
  val windowBits = VecInit(Seq.tabulate(shapeRowBits) { b =>
    // For each bit b of the window, select compressed_board_row[shape_x_coord + b]
    val candidates = (0 until compressedRowBits).map { pos =>
      if (pos >= b) {
        Mux(shapeXCoord === (pos - b).U, compressedBoardRow(pos), false.B)
      } else {
        false.B
      }
    }
    candidates.reduce(_ || _)
  })
  val boardBitsWindow = Mux(runningOrAssertingDone && !io.rowIndexIsOutOfRange,
    windowBits.asUInt, fullShapeRow)

  io.moveAllowed := Mux(runningOrAssertingDone,
    !shapeXCoordOutsideRange && (boardBitsWindow & io.shapeRowData) === 0.U,
    false.B)

  // Next-state logic
  val rowIndexD       = WireDefault(Mux(checkIsRunningQ, rowIndexQ, 0.U))
  val doneD           = WireDefault(false.B)
  val checkIsRunningD = WireDefault(
    Mux(io.startCheck, true.B, Mux(doneD, false.B, checkIsRunningQ)))

  when(checkIsRunningQ) {
    doneD := (rowIndexQ === 3.U) || !io.moveAllowed

    when(!doneD) {
      rowIndexD := rowIndexQ +& 1.U
    }
  }

  // Register updates
  rowIndexQ       := rowIndexD
  checkIsRunningQ := checkIsRunningD
  doneQ           := doneD
}
