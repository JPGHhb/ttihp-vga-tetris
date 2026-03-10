import chisel3._
import chisel3.util._

class TetrisBoardMemory(
    colorBitsPerBlock: Int = 2,
    boardHeightInBlocks: Int = 20,
    rowLenInBits: Int = 20
) extends RawModule {
  require(colorBitsPerBlock <= 3, "ColorBitsPerBlock is expected to be <= 3 bits")
  require(rowLenInBits <= 32, "RowLenInBits with more than 32 bits not supported")

  val clock = IO(Input(Clock()))

  val io = IO(new Bundle {
    val wen          = Input(Bool())
    val ren          = Input(Bool())
    val readYCoord   = Input(UInt(log2Ceil(boardHeightInBlocks).W))
    val writeYCoord  = Input(UInt(log2Ceil(boardHeightInBlocks).W))
    val writeRowData = Input(UInt(rowLenInBits.W))
    val readRowData  = Output(UInt(rowLenInBits.W))
  })

  withClock(clock) {
    val board = Reg(Vec(boardHeightInBlocks, UInt(rowLenInBits.W)))

    when(io.wen) {
      board(io.writeYCoord) := io.writeRowData
    }

    io.readRowData := Mux(io.ren, board(io.readYCoord), 0.U)
  }
}
