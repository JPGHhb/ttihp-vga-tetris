import chisel3._
import chisel3.util._

class MillisecondTimer(
    clockRateInMHz: Double = 21.181
) extends Module {
  val clockTicksPerMs = (clockRateInMHz * 1000.0).toInt
  val timerBits       = log2Ceil(clockTicksPerMs)

  val io = IO(new Bundle {
    val tick = Output(Bool())
  })

  val msTimerQ = RegInit(0.U(timerBits.W))

  val msTimerD = Mux(msTimerQ < clockTicksPerMs.U(timerBits.W),
                     msTimerQ + 1.U, 0.U)

  msTimerQ := msTimerD
  io.tick  := msTimerQ === clockTicksPerMs.U(timerBits.W)
}
