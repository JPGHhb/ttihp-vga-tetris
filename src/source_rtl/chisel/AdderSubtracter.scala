import chisel3._
import chisel3.util._

// Add or subtract two Two's Complement numbers
class AdderSubtracter(width: Int = 5) extends RawModule {
  val io = IO(new Bundle {
    val a        = Input(UInt(width.W))
    val b        = Input(UInt(width.W))

    // If set to 1 perform subtraction, otherwise perform addition
    val subtract = Input(Bool())

    // Set if a == b (Note: Only valid if subtract is set)
    val isZeroResult = Output(Bool())

    // Set if a < b (Note: Only valid if subtract is set and both a and b are signed values)
    val signedIsLowerThan = Output(Bool())

    val result = Output(UInt(width.W))
  })

  //
  // How subtraction is done
  //
  // (a - b) == (a + (-b))
  //
  // Assuming Two's Complement number format: Negation of a number is -N == (~N + 1),
  // hence (a + (-b)) == (a + (~b + 1))
  //
  // The "+1" in the below code is done by adding 1'b1 to the right side of both of the input
  // numbers and then letting the carry logic do the rest
  //
  val input0       = Cat(io.a, 1.U(1.W))
  val negatedInput1 = Cat(~io.b, 1.U(1.W))
  val input1       = Mux(io.subtract, negatedInput1, Cat(io.b, 0.U(1.W)))

  val adderRes = input0 +& input1

  val result = adderRes(width, 1)
  io.result := result

  io.isZeroResult := result === 0.U

  val aSignBit = io.a(width - 1)
  val bSignBit = io.b(width - 1)

  val bothInputsAreNegative = (aSignBit ^ bSignBit) === 0.U
  val resultIsPositive      = result(width - 1) === 0.U

  val signedIsGreaterEqual = Mux(bothInputsAreNegative, resultIsPositive, ~aSignBit)
  io.signedIsLowerThan := ~signedIsGreaterEqual
}
