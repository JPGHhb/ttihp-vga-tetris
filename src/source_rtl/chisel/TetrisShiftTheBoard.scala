import chisel3._
import chisel3.util._

class TetrisShiftTheBoard(
    colorBitsPerBlock: Int = 2,
    boardWidthInBlocks: Int = 10,
    boardHeightInBlocks: Int = 20,
    rowLenInBits: Int = 20
) extends Module {
  require((boardWidthInBlocks * colorBitsPerBlock) <= rowLenInBits, "Inconsistent configuration")

  val rowIndexBits   = log2Ceil(boardHeightInBlocks)

  val io = IO(new Bundle {
    val start        = Input(Bool())
    val boardRowDataIn = Input(UInt(rowLenInBits.W))

    val reading      = Output(Bool())
    val writing      = Output(Bool())
    val boardRowDataOut = Output(UInt(rowLenInBits.W))
    val rowIndex     = Output(UInt(rowIndexBits.W))
    val incrementScore = Output(Bool())
    val done         = Output(Bool())
  })
//
  val stIdle :: stCountingRowsToShift :: stShiftingRowsReading :: stShiftingRowsWriting :: stClearingRows :: stRepeat :: stDone :: Nil = Enum(7)

  // Registers
  val stateQ               = RegInit(stIdle)
  val boardRowDataQ        = RegInit(0.U(rowLenInBits.W))
  val rowIndexQ            = RegInit(0.U(rowIndexBits.W))
  val linesToShiftQ        = RegInit(0.U(rowIndexBits.W))
  val shiftStartPosQ       = RegInit(0.U(rowIndexBits.W))
  val operationIsRunningQ  = RegInit(false.B)
  val internalStartTriggerQ = RegInit(false.B)

  // State comparisons
  val inCountingRowsToShiftState = stateQ === stCountingRowsToShift
  val inShiftingRowsReadingState = stateQ === stShiftingRowsReading
  val inShiftingRowsWritingState = stateQ === stShiftingRowsWriting
  val inClearingRowsState        = stateQ === stClearingRows
  val inRepeatState              = stateQ === stRepeat
  val inDoneState                = stateQ === stDone

  // Output assignments
  io.reading := inCountingRowsToShiftState || inShiftingRowsReadingState
  io.writing := inShiftingRowsWritingState || inClearingRowsState
  io.boardRowDataOut := Mux(inClearingRowsState, 0.U, boardRowDataQ)
  io.rowIndex := Mux(inClearingRowsState, linesToShiftQ,
    Mux(io.writing, shiftStartPosQ, rowIndexQ))
  io.done := inDoneState

  val invalidShiftPos = ((1 << rowIndexBits) - 1).U(rowIndexBits.W)
  val startShiftPosIsInvalid = shiftStartPosQ === invalidShiftPos

  val startTriggered = io.start || internalStartTriggerQ

  // Compress the board row: OR-reduce each ColorBitsPerBlock-wide block into 1 bit
  val compressedBoardRow = VecInit(Seq.tabulate(boardWidthInBlocks) { i =>
    io.boardRowDataIn((i * colorBitsPerBlock) + (colorBitsPerBlock - 1), i * colorBitsPerBlock).orR
  }).asUInt
  val fullRow = ((1 << boardWidthInBlocks) - 1).U(boardWidthInBlocks.W)

  io.incrementScore := false.B

  val operationIsRunningD = WireDefault(
    Mux(io.start, true.B, Mux(inDoneState, false.B, operationIsRunningQ)))

  // Next-state logic
  val rowIndexD            = WireDefault(rowIndexQ)
  val linesToShiftD        = WireDefault(linesToShiftQ)
  val stateD               = WireDefault(stateQ)
  val boardRowDataD        = WireDefault(boardRowDataQ)
  val shiftStartPosD       = WireDefault(shiftStartPosQ)
  val internalStartTriggerD = WireDefault(internalStartTriggerQ)

  when(startTriggered) {
    stateD               := stCountingRowsToShift
    rowIndexD            := (boardHeightInBlocks - 1).U
    shiftStartPosD       := invalidShiftPos
    internalStartTriggerD := false.B
  }

  when(operationIsRunningQ) {
    when(inCountingRowsToShiftState) {
      when(compressedBoardRow === fullRow) {
        io.incrementScore := true.B
        when(startShiftPosIsInvalid) {
          shiftStartPosD := rowIndexQ
        }
      }.elsewhen(!startShiftPosIsInvalid) {
        stateD       := stShiftingRowsReading
        linesToShiftD := shiftStartPosQ - rowIndexQ
      }

      when(rowIndexQ === 0.U) {
        stateD       := Mux(startShiftPosIsInvalid, stDone, stShiftingRowsReading)
        linesToShiftD := shiftStartPosQ - rowIndexQ
      }.otherwise {
        when(stateD =/= stShiftingRowsReading) {
          rowIndexD := rowIndexQ - 1.U
        }
      }
    }

    when(inShiftingRowsReadingState) {
      boardRowDataD := io.boardRowDataIn
      stateD        := stShiftingRowsWriting
    }

    when(inShiftingRowsWritingState) {
      when(rowIndexQ === 0.U) {
        stateD       := stClearingRows
        linesToShiftD := linesToShiftQ - 1.U
      }.otherwise {
        rowIndexD     := rowIndexQ - 1.U
        shiftStartPosD := shiftStartPosQ - 1.U
        stateD        := stShiftingRowsReading
      }
    }

    when(inClearingRowsState) {
      when(linesToShiftQ === 0.U) {
        stateD := stRepeat
      }.otherwise {
        linesToShiftD := linesToShiftQ - 1.U
      }
    }

    when(inRepeatState) {
      internalStartTriggerD := true.B
      stateD := stIdle
    }

    when(inDoneState) {
      stateD := stIdle
    }
  }

  // Register updates
  stateQ               := stateD
  boardRowDataQ        := boardRowDataD
  rowIndexQ            := rowIndexD
  linesToShiftQ        := linesToShiftD
  shiftStartPosQ       := shiftStartPosD
  operationIsRunningQ  := operationIsRunningD
  internalStartTriggerQ := internalStartTriggerD
}
