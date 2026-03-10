import chisel3._
import chisel3.util._

// Generates pseudo-random numbers using Fibonacci LFSR
class TetrisLFSRPseudoRandomNumGen(maxNum: Int = 6) extends Module {
  val randomNumBitCount = log2Ceil(maxNum)

  val io = IO(new Bundle {
    val enable = Input(Bool())   // Advance LFSR when high
    val random = Output(UInt(randomNumBitCount.W)) // Random value 0..maxNum
  })

  // 16-bit Fibonacci LFSR (x^16 + x^14 + x^13 + x^11 + 1)
  val lfsrBitCount = 16
  val seedValue    = "hACE1".U(lfsrBitCount.W)

  val lfsrQ = RegInit(seedValue)

  val feedback = (((lfsrQ(15) ^ lfsrQ(13)) ^ lfsrQ(12)) ^ lfsrQ(10))
  val lfsrD   = Mux(io.enable, Cat(lfsrQ(14, 0), feedback), lfsrQ)

  lfsrQ := lfsrD

  // Map LFSR bits to shape range 0..maxNum
  val rawValue = lfsrQ(randomNumBitCount - 1, 0)
  io.random := Mux(rawValue > maxNum.U(randomNumBitCount.W), maxNum.U(randomNumBitCount.W), rawValue)
}
