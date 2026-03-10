import chisel3._
import chisel3.util._

class BCDAdder extends RawModule {
  val io = IO(new Bundle {
    val a    = Input(UInt(4.W))   // BCD digit (0-9)
    val b    = Input(UInt(4.W))   // BCD digit (0-9)
    val cin  = Input(Bool())      // carry in
    val sum  = Output(UInt(4.W)) // BCD sum digit
    val cout = Output(Bool())    // carry out
  })

  val binarySum = (0.U(1.W) ## io.a) +& (0.U(1.W) ## io.b) +& (0.U(4.W) ## io.cin)

  // If sum > 9, add 6 to correct back to BCD
  when(binarySum > 9.U) {
    io.sum  := binarySum(3, 0) + 6.U
    io.cout := true.B
  }.otherwise {
    io.sum  := binarySum(3, 0)
    io.cout := false.B
  }
}
