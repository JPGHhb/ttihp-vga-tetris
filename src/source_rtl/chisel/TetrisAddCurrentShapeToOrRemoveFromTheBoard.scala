import chisel3._
import chisel3.util._

class TetrisAddCurrentShapeToOrRemoveFromTheBoard(
    colorBitsPerBlock: Int = 2,
    boardWidthInBlocks: Int = 10,
    rowLenInBits: Int = 20
) extends Module {
  require(colorBitsPerBlock == 2 || colorBitsPerBlock == 3,
    "ColorBitsPerBlock != 3 && ColorBitsPerBlock != 2, please change calculation of the shape_x_coord")

  val shapeRowWidth        = 4
  val extendedRowLenInBits = rowLenInBits + 1
  val shapeXCoordBits      = log2Floor(boardWidthInBlocks) + 1
  val boardXCoordBits      = log2Ceil(extendedRowLenInBits)
  val numBlocksInABoardRow = boardWidthInBlocks
  val maxBoardXCoord       = numBlocksInABoardRow.U(boardXCoordBits.W)

  val io = IO(new Bundle {
    val start          = Input(Bool())
    val clearShape     = Input(Bool())
    val shapeRowData   = Input(UInt(shapeRowWidth.W))
    val shapeColor     = Input(UInt(colorBitsPerBlock.W))
    val boardRowDataIn = Input(UInt(rowLenInBits.W))
    val shapeXCoord    = Input(UInt(shapeXCoordBits.W))

    val reading        = Output(Bool())
    val writing        = Output(Bool())
    val boardRowDataOut = Output(UInt(rowLenInBits.W))
    val rowIndex       = Output(UInt(2.W))
    val done           = Output(Bool())
  })

  val stIdle :: stReading :: stWriting :: Nil = Enum(3)

  val stateQ        = RegInit(stIdle)
  val boardRowDataQ = RegInit(0.U(rowLenInBits.W))
  val rowIndexQ     = RegInit(0.U(2.W))
  val doneQ         = RegInit(false.B)
  val clearingQ     = RegInit(false.B)

  io.rowIndex        := rowIndexQ
  io.done            := doneQ
  io.reading         := stateQ === stReading
  io.writing         := stateQ === stWriting
  io.boardRowDataOut := boardRowDataQ

  val inIdleState    = stateQ === stIdle
  val inReadingState = stateQ === stReading
  val inWritingState = stateQ === stWriting

  // Compute shape_x_logical_coord and shape_x_coord
  val shapeXLogicalCoord = io.shapeXCoord +& 1.U
  val shapeXCoordOutsideRange = shapeXLogicalCoord > numBlocksInABoardRow.U

  val shapeXCoord = Wire(UInt(boardXCoordBits.W))
  if (colorBitsPerBlock == 3) {
    shapeXCoord := Mux(shapeXCoordOutsideRange, maxBoardXCoord,
      (io.shapeXCoord << 1).asUInt +& io.shapeXCoord)
  } else {
    shapeXCoord := Mux(shapeXCoordOutsideRange, maxBoardXCoord,
      (io.shapeXCoord << 1).asUInt)
  }

  // Precompute board_block_index and shape_block_valid for each shape block
  val boardBlockIndex = Wire(Vec(shapeRowWidth, UInt(boardXCoordBits.W)))
  val shapeBlockValid = Wire(Vec(shapeRowWidth, Bool()))
  for (i <- 0 until shapeRowWidth) {
    boardBlockIndex(i) := shapeXCoord +& (i * colorBitsPerBlock).U
    shapeBlockValid(i) := io.shapeRowData(i)
  }

  val boardExtendedRowDataIn = Cat(0.U(1.W), io.boardRowDataIn)

  // Next-state logic
  val rowIndexD     = WireDefault(rowIndexQ)
  val doneD         = WireDefault(false.B)
  val stateD        = WireDefault(stateQ)
  val clearingD     = WireDefault(Mux(doneQ, false.B, clearingQ))
  val boardRowDataD = WireDefault(boardRowDataQ)

  when(io.start) {
    stateD    := stReading
    rowIndexD := 0.U
    clearingD := io.clearShape
  }

  when(!inIdleState) {
    when(inReadingState) {
      // Overlay or clear each shape block onto the board row
      // Mirrors SV: board_row_data_d[board_block_index[i]+:ColorBitsPerBlock] = ...
      // For each output bit position, check if any shape block writes to it.
      // This generates per-bit mux trees and avoids dynamic shifts entirely.
      val newBits = Mux(clearingQ, 0.U(colorBitsPerBlock.W), io.shapeColor)

      val resultBits = VecInit(Seq.tabulate(extendedRowLenInBits) { pos =>
        // Start with the board input bit at this position
        val default = boardExtendedRowDataIn(pos)
        // Check each shape block (later blocks take priority, matching SV loop order)
        (0 until shapeRowWidth).foldLeft(default) { case (prev, i) =>
          // Which color bit offset (b) within block i would land at this position?
          // pos == boardBlockIndex(i) + b  =>  b = pos - boardBlockIndex(i)
          // Valid when b is in [0, colorBitsPerBlock) and the shape block is valid
          (0 until colorBitsPerBlock).foldLeft(prev) { case (prev2, b) =>
            if (pos >= b) {
              Mux(shapeBlockValid(i) && boardBlockIndex(i) === (pos - b).U,
                newBits(b), prev2)
            } else {
              prev2
            }
          }
        }
      })

      boardRowDataD := resultBits.asUInt(rowLenInBits - 1, 0)
      stateD := stWriting
    }.elsewhen(inWritingState) {
      doneD := rowIndexQ === 3.U

      when(doneD) {
        stateD := stIdle
      }.otherwise {
        stateD    := stReading
        rowIndexD := rowIndexQ +& 1.U
      }
    }
  }

  stateQ        := stateD
  boardRowDataQ := boardRowDataD
  rowIndexQ     := rowIndexD
  doneQ         := doneD
  clearingQ     := clearingD
}
