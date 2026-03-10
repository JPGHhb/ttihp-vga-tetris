import chisel3._
import chisel3.util._

class TetrisInputs(
    buttonStateHoldingIntervalsInMs: Seq[Int] = Seq(100, 100, 100, 1)
) extends Module {
  val buttonCount = 4
  require(buttonStateHoldingIntervalsInMs.length == buttonCount)

  val largestValue = buttonStateHoldingIntervalsInMs.max
  val buttonTimerBits = log2Ceil(largestValue) + 1

  val io = IO(new Bundle {
    val millisecondTimerTick = Input(Bool())
    val clear                = Input(Bool())

    val rotateButtonPressed = Input(Bool())
    val leftButtonPressed   = Input(Bool())
    val rightButtonPressed  = Input(Bool())
    val downButtonPressed   = Input(Bool())

    val rotateButtonActive = Output(Bool())
    val leftButtonActive   = Output(Bool())
    val rightButtonActive  = Output(Bool())
    val downButtonActive   = Output(Bool())
  })

  val buttonPressed = VecInit(
    io.rotateButtonPressed,
    io.leftButtonPressed,
    io.rightButtonPressed,
    io.downButtonPressed
  )

  val buttonTimerQ  = RegInit(VecInit(Seq.fill(buttonCount)(0.U(buttonTimerBits.W))))
  val buttonActiveQ = RegInit(VecInit(Seq.fill(buttonCount)(false.B)))

  io.rotateButtonActive := buttonActiveQ(0)
  io.leftButtonActive   := buttonActiveQ(1)
  io.rightButtonActive  := buttonActiveQ(2)
  io.downButtonActive   := buttonActiveQ(3)

  for (i <- 0 until buttonCount) {
    // Timer: count milliseconds while button is held, reset when released
    val buttonTimerD = WireDefault(buttonTimerQ(i))
    when(!buttonPressed(i) | (buttonActiveQ(i) & io.clear)) {
      buttonTimerD := 0.U
    }.elsewhen(io.millisecondTimerTick && !buttonActiveQ(i)) {
      buttonTimerD := buttonTimerQ(i) + 1.U
    }

    // Active latch: set when debounce threshold reached, clear on clear
    val buttonActiveD = WireDefault(buttonActiveQ(i))
    when(!buttonActiveQ(i)) {
      buttonActiveD := buttonPressed(i) &
        (buttonTimerD >= buttonStateHoldingIntervalsInMs(i).U(buttonTimerBits.W))
    }.otherwise {
      buttonActiveD := !io.clear
    }

    buttonTimerQ(i)  := buttonTimerD
    buttonActiveQ(i) := buttonActiveD
  }
}
