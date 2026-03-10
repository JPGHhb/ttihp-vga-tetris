import chisel3._
import chisel3.util._

class VGATetris(
    availableColors: Int = 3
) extends Module {
  val colorBitsPerBlock: Int = log2Ceil(availableColors);
  def flog2(x: Int): Int = { require(x > 0); log2Floor(x) }

  val screenWidth        = 640
  val screenHeight       = 480
  val blockSizeInPx      = 16
  val boardWidthInBlocks = 10
  val boardHeightInBlocks = 20
  val boardRowLenInBits  = boardWidthInBlocks * colorBitsPerBlock
  val boardYCoordBits    = log2Ceil(boardHeightInBlocks)
  val posXBits           = flog2(boardWidthInBlocks) + 1

  val io = IO(new Bundle {
    val button1 = Input(Bool())
    val button2 = Input(Bool())
    val button3 = Input(Bool())
    val button4 = Input(Bool())

    val vgaR  = Output(UInt(colorBitsPerBlock.W))
    val vgaG  = Output(UInt(colorBitsPerBlock.W))
    val vgaB  = Output(UInt(colorBitsPerBlock.W))
    val vgaHs = Output(Bool())
    val vgaVs = Output(Bool())
    val vgaVisiblePixels = Output(Bool())

    val pxX = Output(UInt(10.W))
    val pxY = Output(UInt(10.W))
  })

  // --- VGA Controller ---
  val vgaController = Module(new VGAController(
    screenWidth = screenWidth,
    screenHeight = screenHeight
  ))
  io.vgaHs := vgaController.io.hSync
  io.vgaVs := vgaController.io.vSync
  val pxX        = vgaController.io.pixelPosX
  val pxY        = vgaController.io.pixelPosY
  val activeVideo = vgaController.io.pixelPosIsValid

  io.pxX := pxX
  io.pxY := pxY
  io.vgaVisiblePixels := activeVideo

  // --- TetrisDisplay ---
  val tetrisDisplay = Module(new TetrisDisplay(
    screenWidth = screenWidth,
    screenHeight = screenHeight,
    colorBitsPerBlock = colorBitsPerBlock,
    boardRowLenInBits = boardRowLenInBits,
    blockSizeInPx = blockSizeInPx,
    boardWidthInBlocks = boardWidthInBlocks,
    boardHeightInBlocks = boardHeightInBlocks
  ))
  tetrisDisplay.io.reset           := reset.asBool
  tetrisDisplay.io.pixelPosIsValid := activeVideo
  tetrisDisplay.io.pxX             := pxX
  tetrisDisplay.io.pxY             := pxY

  val score                   = Wire(TetrisTypes.ScoreType)
  val gameOver                = Wire(Bool())
  val boardRowData            = Wire(UInt(boardRowLenInBits.W))
  tetrisDisplay.io.showGameOver := gameOver
  tetrisDisplay.io.boardRowData := boardRowData
  tetrisDisplay.io.score       := score

  val coordsValid              = tetrisDisplay.io.coordsValid
  val displayBoardReadYCoord   = tetrisDisplay.io.boardYCoord

  io.vgaR := tetrisDisplay.io.vgaR
  io.vgaG := tetrisDisplay.io.vgaG
  io.vgaB := tetrisDisplay.io.vgaB

  // --- Registers for tetris logic scheduling ---
  val runningTetrisLogicQ = RegInit(false.B)
  val startTetrisLogicQ   = RegInit(false.B)

  // --- Tetris logic signals ---
  val tetrisLogicDone       = Wire(Bool())
  val tetrisLogicReadBoard  = Wire(Bool())
  val writeBoard            = Wire(Bool())
  val tetrisLogicRowIndex   = Wire(UInt(boardYCoordBits.W))
  val boardRowDataToWrite   = Wire(UInt(boardRowLenInBits.W))

  val readBoard      = Mux(runningTetrisLogicQ, tetrisLogicReadBoard, coordsValid)
  val boardReadYCoord  = Mux(runningTetrisLogicQ, tetrisLogicRowIndex, displayBoardReadYCoord)
  val boardWriteYCoord = tetrisLogicRowIndex

  // --- Board Memory ---
  val boardMem = Module(new TetrisBoardMemory(
    colorBitsPerBlock = colorBitsPerBlock,
    boardHeightInBlocks = boardHeightInBlocks,
    rowLenInBits = boardRowLenInBits
  ))
  boardMem.clock           := clock
  boardMem.io.wen          := writeBoard
  boardMem.io.ren          := readBoard
  boardMem.io.readYCoord   := boardReadYCoord
  boardMem.io.writeYCoord  := boardWriteYCoord
  boardMem.io.writeRowData := boardRowDataToWrite
  boardRowData             := boardMem.io.readRowData

  // --- Millisecond Timer ---
  val msTimer = Module(new MillisecondTimer(clockRateInMHz = 25))
  val msTimerTick = msTimer.io.tick

  // --- TetrisInputs ---
  val inputs = Module(new TetrisInputs())
  inputs.io.millisecondTimerTick := msTimerTick
  inputs.io.clear                := tetrisLogicDone
  inputs.io.rotateButtonPressed  := io.button3
  inputs.io.leftButtonPressed    := io.button1
  inputs.io.rightButtonPressed   := io.button2
  inputs.io.downButtonPressed    := io.button4

  val rotateButtonActive = inputs.io.rotateButtonActive
  val leftButtonActive   = inputs.io.leftButtonActive
  val rightButtonActive  = inputs.io.rightButtonActive
  val downButtonActive   = inputs.io.downButtonActive

  // --- TetrisLogic ---
  val tetrisLogic = Module(new TetrisLogic(
    colorBitsPerBlock = colorBitsPerBlock,
    boardWidthInBlocks = boardWidthInBlocks,
    boardHeightInBlocks = boardHeightInBlocks,
    rowLenInBits = boardRowLenInBits
  ))
  tetrisLogic.io.start                  := startTetrisLogicQ
  tetrisLogic.io.shapeStartPosX         := ((boardWidthInBlocks / 4) + 1).U(posXBits.W)
  tetrisLogic.io.shapeStartPosY         := 0.U
  tetrisLogic.io.shapeStartType         := 0.U
  tetrisLogic.io.alwaysStartInInitState := false.B
  tetrisLogic.io.rotateButtonActive     := rotateButtonActive
  tetrisLogic.io.leftButtonActive       := leftButtonActive
  tetrisLogic.io.rightButtonActive      := rightButtonActive
  tetrisLogic.io.downButtonActive       := downButtonActive
  tetrisLogic.io.boardRowDataIn         := boardRowData

  tetrisLogicReadBoard := tetrisLogic.io.reading
  writeBoard           := tetrisLogic.io.writing
  boardRowDataToWrite  := tetrisLogic.io.boardRowDataOut
  tetrisLogicRowIndex  := tetrisLogic.io.rowIndex
  score                := tetrisLogic.io.score
  gameOver             := tetrisLogic.io.gameOver
  tetrisLogicDone      := tetrisLogic.io.done

  // --- Tetris logic scheduling state machine ---
  val runningTetrisLogicD = WireDefault(runningTetrisLogicQ)
  val startTetrisLogicD   = WireDefault(startTetrisLogicQ)

  when(runningTetrisLogicQ) {
    runningTetrisLogicD := ~io.vgaVs
    startTetrisLogicD   := false.B
  }.otherwise {
    when(!startTetrisLogicQ) {
      startTetrisLogicD   := ~io.vgaVs & ~activeVideo
      runningTetrisLogicD := startTetrisLogicD
    }.otherwise {
      startTetrisLogicD := false.B
    }
  }

  runningTetrisLogicQ := runningTetrisLogicD
  startTetrisLogicQ   := startTetrisLogicD
}
