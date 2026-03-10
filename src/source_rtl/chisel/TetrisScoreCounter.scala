import chisel3._
import chisel3.util._

class TetrisScoreCounter extends Module {
  val digitCount = TetrisTypes.ScoreDigitCount

  val io = IO(new Bundle {
    val incrementScore = Input(Bool())
    val resetToZero    = Input(Bool())
    val score          = Output(TetrisTypes.ScoreType)
  })

  val scoreQ = RegInit(VecInit(Seq.fill(digitCount)(0.U(TetrisTypes.ScoreDigitBits.W))))

  val maxScoreReached = scoreQ(digitCount - 1) === 9.U
  val increment       = io.incrementScore & ~maxScoreReached

  val scoreD = Wire(TetrisTypes.ScoreType)
  val carry  = Wire(Vec(digitCount, Bool()))

  for (i <- 0 until digitCount) {
    val bcdAdder = Module(new BCDAdder)
    bcdAdder.io.a   := scoreQ(i)
    bcdAdder.io.b   := 0.U
    bcdAdder.io.cin := (if (i == 0) increment else carry(i - 1))
    scoreD(i)       := bcdAdder.io.sum
    carry(i)        := bcdAdder.io.cout
  }

  when(io.resetToZero) {
    for (i <- 0 until digitCount) {
      scoreD(i) := 0.U
    }
  }

  scoreQ   := scoreD
  io.score := scoreQ
}
