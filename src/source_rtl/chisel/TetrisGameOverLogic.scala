import chisel3._
import chisel3.util._

class TetrisGameOverLogic(
    buttonPressCountForReset: Int = 2
) extends Module {
  def flog2(x: Int): Int = { require(x > 0); log2Floor(x) }

  val counterBits = flog2(buttonPressCountForReset) + 1

  val io = IO(new Bundle {
    val enterGameOverState = Input(Bool())
    val downButtonActive   = Input(Bool())

    val inGameOverState    = Output(Bool())
    val gameOverReset      = Output(Bool())
  })

  // --- Registers ---
  val inGameOverStateQ      = RegInit(false.B)
  val buttonPressesCounterQ = RegInit(0.U(counterBits.W))

  // --- Next-state wires ---
  val inGameOverStateD      = WireDefault(inGameOverStateQ)
  val buttonPressesCounterD = WireDefault(buttonPressesCounterQ)

  when(io.enterGameOverState) {
    inGameOverStateD      := true.B
    buttonPressesCounterD := 0.U
  }.elsewhen(inGameOverStateQ) {
    buttonPressesCounterD := buttonPressesCounterQ + io.downButtonActive
    when(buttonPressesCounterQ === (buttonPressCountForReset - 1).U(counterBits.W)) {
      inGameOverStateD := false.B
    }
  }

  // --- Register updates ---
  inGameOverStateQ      := inGameOverStateD
  buttonPressesCounterQ := buttonPressesCounterD

  // --- Outputs ---
  io.inGameOverState := inGameOverStateQ
  io.gameOverReset   := inGameOverStateQ & !inGameOverStateD
}
