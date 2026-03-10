import chisel3._
import chisel3.util._

class VGAController(
    screenWidth: Int = 640,
    screenHeight: Int = 480,
    useFastClock: Boolean = false
) extends Module {
  val hPixels = screenWidth
  val vPixels = screenHeight

  val (hPulse, hBackPorch, hFrontPorch, vPulse, vBackPorch, vFrontPorch) =
    if (useFastClock) {
      // 31.5 MHz
      (40, 128, 24, 3, 28, 9)
    } else {
      // 21.175 MHz
      (96, 48, 16, 2, 33, 10)
    }

  val hFrame = hPulse + hBackPorch + hPixels + hFrontPorch
  val vFrame = vPulse + vBackPorch + vPixels + vFrontPorch

  val vSyncPulseStart = vPixels + vFrontPorch
  val vSyncPulseEnd   = vSyncPulseStart + vPulse

  val io = IO(new Bundle {
    val hSync          = Output(Bool())
    val vSync          = Output(Bool())
    val pixelPosX      = Output(UInt(10.W))
    val pixelPosY      = Output(UInt(10.W))
    val pixelPosIsValid = Output(Bool())
  })

  val horizontalCounterQ = RegInit(0.U(10.W))
  val verticalCounterQ   = RegInit(0.U(10.W))
  val pixelPosXQ         = RegInit(0.U(10.W))
  val pixelPosYQ         = RegInit(0.U(10.W))

  io.pixelPosX := pixelPosXQ
  io.pixelPosY := pixelPosYQ

  // Next-state defaults
  val horizontalCounterD = WireDefault(horizontalCounterQ + 1.U)
  val verticalCounterD   = WireDefault(verticalCounterQ)
  val pixelPosXD         = WireDefault(pixelPosXQ)
  val pixelPosYD         = WireDefault(pixelPosYQ)

  when(pixelPosXQ < (hPixels - 1).U(10.W)) {
    pixelPosXD := pixelPosXQ + 1.U
  }.elsewhen(horizontalCounterQ === (hFrame - 1).U(10.W)) {
    horizontalCounterD := 0.U
    pixelPosXD         := 0.U

    when(verticalCounterQ === (vFrame - 1).U(10.W)) {
      verticalCounterD := 0.U
      pixelPosYD       := 0.U
    }.otherwise {
      verticalCounterD := verticalCounterQ + 1.U

      when(pixelPosYQ < (vPixels - 1).U(10.W)) {
        pixelPosYD := pixelPosYQ + 1.U
      }
    }
  }

  horizontalCounterQ := horizontalCounterD
  verticalCounterQ   := verticalCounterD
  pixelPosXQ         := pixelPosXD
  pixelPosYQ         := pixelPosYD

  // Sync signals (active low)
  val isVisibleHorizPixel = horizontalCounterQ < hPixels.U(10.W)
  val isVisibleVertPixel  = verticalCounterQ < vPixels.U(10.W)

  val hSyncActive = (horizontalCounterQ >= (hPixels + hFrontPorch).U(10.W)) &
                    (horizontalCounterQ < (hPixels + hFrontPorch + hPulse).U(10.W))
  val vSyncActive = (verticalCounterQ >= vSyncPulseStart.U(10.W)) &
                    (verticalCounterQ < vSyncPulseEnd.U(10.W))

  io.hSync           := !hSyncActive
  io.vSync           := !vSyncActive
  io.pixelPosIsValid := isVisibleHorizPixel & isVisibleVertPixel
}
