import chisel3._
import chisel3.util._

object TetrisTypes {
  val MaxScore        = 9999
  val ScoreDigitCount = digitCount(MaxScore)
  val ScoreDigitBits  = 4

  def ScoreType = Vec(ScoreDigitCount, UInt(ScoreDigitBits.W))

  private def digitCount(a: Int): Int = {
    var v = a; var count = 0
    while (v > 0) { count += 1; v /= 10 }
    count
  }
}
