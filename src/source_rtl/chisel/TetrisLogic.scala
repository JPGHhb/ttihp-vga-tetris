import chisel3._
import chisel3.util._

class TetrisLogic(
    colorBitsPerBlock: Int = 2,
    boardWidthInBlocks: Int = 10,
    boardHeightInBlocks: Int = 20,
    rowLenInBits: Int = 20,
    shapeDropTimerNormalMax: Int = 60,
    shapeDropTimerFastMax: Int = 5,
    shapeCount: Int = 7
) extends Module {
  // flog2: floor(log2(x)) — equivalent to HelperFunctions::flog2
  def flog2(x: Int): Int = { require(x > 0); log2Floor(x) }

  val posXBits           = flog2(boardWidthInBlocks) + 1
  val posYBits           = flog2(boardHeightInBlocks) + 1
  val shapeTypeBits      = flog2(shapeCount) + 1
  val shapeRotationBits  = 2
  val rowIndexBits       = log2Ceil(boardHeightInBlocks)
  val dropTimerBits      = log2Floor(math.max(shapeDropTimerNormalMax, shapeDropTimerFastMax)) + 1

  val io = IO(new Bundle {
    val start                    = Input(Bool())

    val shapeStartPosX           = Input(UInt(posXBits.W))
    val shapeStartPosY           = Input(UInt(posYBits.W))
    val shapeStartType           = Input(UInt(shapeTypeBits.W))
    val alwaysStartInInitState   = Input(Bool())

    val rotateButtonActive       = Input(Bool())
    val leftButtonActive         = Input(Bool())
    val rightButtonActive        = Input(Bool())
    val downButtonActive         = Input(Bool())

    val boardRowDataIn           = Input(UInt(rowLenInBits.W))
    val reading                  = Output(Bool())
    val writing                  = Output(Bool())
    val boardRowDataOut          = Output(UInt(rowLenInBits.W))
    val rowIndex                 = Output(UInt(rowIndexBits.W))

    val score                    = Output(TetrisTypes.ScoreType)

    val gameOver                 = Output(Bool())
    val done                     = Output(Bool())
  })

  // --- State enum ---
  object LogicState extends ChiselEnum {
    val stPerformInitialClearBoard,
        stInitialClearBoard,
        stInitState,
        stIdle,
        stRemoveShapeFromTheBoard,
        stGetInput,
        stRotateIsAllowed,
        stMoveLeftIfAllowed,
        stMoveRightIfAllowed,
        stMoveShapeDownStep0,
        stMoveShapeDownStep1,
        stCheckIfShapeStoppedMoving,
        stAddShapeToTheBoard,
        stAddShapeToTheBoardAndDone,
        stShiftBoard,
        stGetNextShape,
        stCheckIfGameOverStep0,
        stCheckIfGameOverStep1,
        stClearBoard,
        stDoneWithGameOver,
        stDoneAfterInitialBoardClear, stDone = Value
  }
  import LogicState._

  // --- Registers ---
  val posXQ          = RegInit(0.U(posXBits.W))
  val posYQ          = RegInit(0.U(posYBits.W))
  val shapeTypeQ     = RegInit(0.U(shapeTypeBits.W))
  val rotationQ      = RegInit(0.U(shapeRotationBits.W))
  val stateQ         = RegInit(stPerformInitialClearBoard)
  val shapeDropTimerQ = RegInit(0.U(dropTimerBits.W))
  val gameOverResetHappenedQ = RegInit(false.B)

  // --- State decode flags ---
  val inPerformInitialBoardClearState  = stateQ === stPerformInitialClearBoard
  val inInitialClearBoardState         = stateQ === stInitialClearBoard
  val inInitState                      = stateQ === stInitState
  val inIdleState                      = stateQ === stIdle
  val inRemoveShapeFromTheBoardState   = stateQ === stRemoveShapeFromTheBoard
  val inGetInputState                  = stateQ === stGetInput
  val inRotateIsAllowedState           = stateQ === stRotateIsAllowed
  val inMoveLeftIfAllowedState         = stateQ === stMoveLeftIfAllowed
  val inMoveRightIfAllowedState        = stateQ === stMoveRightIfAllowed
  val inMoveShapeDownStateStep0        = stateQ === stMoveShapeDownStep0
  val inMoveShapeDownStateStep1        = stateQ === stMoveShapeDownStep1
  val inCheckIfShapeStoppedMovingState = stateQ === stCheckIfShapeStoppedMoving
  val inAddShapeToTheBoardState        = stateQ === stAddShapeToTheBoard
  val inAddShapeToTheBoardAndDoneState = stateQ === stAddShapeToTheBoardAndDone
  val inShiftBoardState                = stateQ === stShiftBoard
  val inGetNextShapeState              = stateQ === stGetNextShape
  val inCheckIfGameOverStep0State      = stateQ === stCheckIfGameOverStep0
  val inCheckIfGameOverStep1State      = stateQ === stCheckIfGameOverStep1
  val inClearBoardState                = stateQ === stClearBoard
  val inDoneWithGameOverState          = stateQ === stDoneWithGameOver
  val inDoneAfterInitialBoardClearState = stateQ === stDoneAfterInitialBoardClear
  val inDoneState                      = stateQ === stDone

  // --- Composite state flags ---
  val addingOrRemovingShape = inRemoveShapeFromTheBoardState | inAddShapeToTheBoardState | inAddShapeToTheBoardAndDoneState
  val inMoveIfAllowedState  = inRotateIsAllowedState | inMoveLeftIfAllowedState | inMoveRightIfAllowedState |
                              inMoveShapeDownStateStep0 | inMoveShapeDownStateStep1 |
                              inCheckIfShapeStoppedMovingState |
                              inCheckIfGameOverStep0State | inCheckIfGameOverStep1State

  io.done     := inDoneState | inDoneWithGameOverState | inDoneAfterInitialBoardClearState

  // --- Submodule: TetrisLFSRPseudoRandomNumGen ---
  val tetrisLFSRPseudoRandomNumGen = Module(new TetrisLFSRPseudoRandomNumGen(maxNum = (shapeCount - 1)))

  val genRandomNum = Wire(Bool())
  val randomNum0To6 = tetrisLFSRPseudoRandomNumGen.io.random 

  tetrisLFSRPseudoRandomNumGen.io.enable := genRandomNum;

  // --- Submodule: AdderSubtracter ---
  val adderSubtracter = Module(new AdderSubtracter(width = posYBits))
  val addSubbInA     = Wire(UInt(posYBits.W))
  val addSubbInB     = Wire(UInt(posYBits.W))
  val addSubbSubtract = Wire(Bool())
  val addSubbRes     = adderSubtracter.io.result

  addSubbInA      := posYQ
  addSubbInB      := 1.U(posYBits.W)
  addSubbSubtract := inCheckIfShapeStoppedMovingState | inCheckIfGameOverStep1State

  adderSubtracter.io.a        := addSubbInA
  adderSubtracter.io.b        := addSubbInB
  adderSubtracter.io.subtract := addSubbSubtract

  // --- Submodule: TetrisShapeDataProvider ---
  val relativeRowIndex = Wire(UInt(2.W))

  val addRemoveShapeRelativeRowIndex   = Wire(UInt(2.W))
  val checkMoveAllowedRelativeRowIndex = Wire(UInt(2.W))

  relativeRowIndex := Mux(addingOrRemovingShape, addRemoveShapeRelativeRowIndex,
                       Mux(inMoveIfAllowedState, checkMoveAllowedRelativeRowIndex, 0.U))

  val shapeDataProvider = Module(new TetrisShapeDataProvider(shapeCount = shapeCount))
  shapeDataProvider.io.shapeSelector         := shapeTypeQ
  shapeDataProvider.io.shapeRotationSelector := rotationQ
  shapeDataProvider.io.shapeDataRowIndex     := relativeRowIndex

  val shapeRowData              = shapeDataProvider.io.shapeRowData
  val currentShapeLastRotationId = shapeDataProvider.io.currentShapeLastRotationId

  // --- Shape colors ---
  val shapeColors = Wire(Vec(shapeCount, UInt(colorBitsPerBlock.W)))
  if (colorBitsPerBlock == 3) {
    for (i <- 0 until shapeCount) shapeColors(i) := (i + 1).U(colorBitsPerBlock.W)
  } else if (colorBitsPerBlock == 2) {
    val colorValues = Seq(1, 2, 3, 1, 2, 3, 1)
    for (i <- 0 until shapeCount) shapeColors(i) := colorValues(i).U(colorBitsPerBlock.W)
  } else {
    for (i <- 0 until shapeCount) shapeColors(i) := ((i % ((1 << colorBitsPerBlock) - 1)) + 1).U(colorBitsPerBlock.W)
  }

  // --- Row index computation ---
  val boardShiftRowIndexOut = Wire(UInt(rowIndexBits.W))

  val addingOrRemovingShapeOrCheckIfMoveAllowedState = addingOrRemovingShape | inMoveIfAllowedState

  val addOrRemoveShapeOrCheckIfMoveAllowedRowIndexOut = (posYQ +& relativeRowIndex)(rowIndexBits - 1, 0)

  val rowIndex = Mux(inShiftBoardState, boardShiftRowIndexOut,
                  Mux(addingOrRemovingShapeOrCheckIfMoveAllowedState, addOrRemoveShapeOrCheckIfMoveAllowedRowIndexOut, posYQ))

  val shapeYCoordLastIndex      = rowIndex === (boardHeightInBlocks - 1).U(rowIndexBits.W)
  val shapeYCoordOutsideTheRange = rowIndex > (boardHeightInBlocks - 1).U(rowIndexBits.W)

  io.rowIndex := Mux(shapeYCoordOutsideTheRange, posYQ, rowIndex)

  // --- Submodule: TetrisAddCurrentShapeToOrRemoveFromTheBoard ---
  val addRemoveShapeStart      = Wire(Bool())
  val addRemoveShapeClearShape = Wire(Bool())
  val addRemoveShapeDone       = Wire(Bool())

  val addOrRemoveShape = Module(new TetrisAddCurrentShapeToOrRemoveFromTheBoard(
    colorBitsPerBlock = colorBitsPerBlock,
    boardWidthInBlocks = boardWidthInBlocks,
    rowLenInBits = rowLenInBits
  ))
  addOrRemoveShape.io.start        := addRemoveShapeStart
  addOrRemoveShape.io.clearShape   := addRemoveShapeClearShape
  addOrRemoveShape.io.shapeRowData := shapeRowData
  addOrRemoveShape.io.shapeColor   := shapeColors(shapeTypeQ)
  addOrRemoveShape.io.boardRowDataIn := io.boardRowDataIn
  addOrRemoveShape.io.shapeXCoord  := posXQ

  val addOrRemoveShapeReadingOut         = addOrRemoveShape.io.reading
  val addOrRemoveShapeWritingOut         = addOrRemoveShape.io.writing
  val addRemoveShapeBoardRowDataOut      = addOrRemoveShape.io.boardRowDataOut
  addRemoveShapeRelativeRowIndex        := addOrRemoveShape.io.rowIndex
  addRemoveShapeDone                    := addOrRemoveShape.io.done

  // --- Submodule: TetrisCheckMoveAllowed ---
  val checkMoveAllowedStart  = Wire(Bool())
  val checkMoveAllowedResult = Wire(Bool())
  val checkMoveAllowedDone   = Wire(Bool())

  val checkMoveAllowed = Module(new TetrisCheckMoveAllowed(
    colorBitsPerBlock = colorBitsPerBlock,
    boardWidthInBlocks = boardWidthInBlocks,
    rowLenInBits = rowLenInBits
  ))
  checkMoveAllowed.io.startCheck           := checkMoveAllowedStart
  checkMoveAllowed.io.shapeRowData         := shapeRowData
  checkMoveAllowed.io.boardRowData         := io.boardRowDataIn
  checkMoveAllowed.io.shapeXCoord          := posXQ
  checkMoveAllowed.io.rowIndexIsOutOfRange := shapeYCoordOutsideTheRange

  checkMoveAllowedRelativeRowIndex := checkMoveAllowed.io.rowIndex
  checkMoveAllowedResult           := checkMoveAllowed.io.moveAllowed
  checkMoveAllowedDone             := checkMoveAllowed.io.checkDone

  // --- Submodule: TetrisShiftTheBoard ---
  val boardShifterStateStart = Wire(Bool())
  val boardShifterStateDone  = Wire(Bool())

  val shiftTheBoard = Module(new TetrisShiftTheBoard(
    colorBitsPerBlock = colorBitsPerBlock,
    boardWidthInBlocks = boardWidthInBlocks,
    boardHeightInBlocks = boardHeightInBlocks,
    rowLenInBits = rowLenInBits
  ))
  shiftTheBoard.io.start          := boardShifterStateStart
  shiftTheBoard.io.boardRowDataIn := io.boardRowDataIn

  val boardShiftReadingOut        = shiftTheBoard.io.reading
  val boardShiftWritingOut        = shiftTheBoard.io.writing
  val boardShiftBoardRowDataOut   = shiftTheBoard.io.boardRowDataOut
  boardShiftRowIndexOut          := shiftTheBoard.io.rowIndex
  val incrementScore              = shiftTheBoard.io.incrementScore
  boardShifterStateDone          := shiftTheBoard.io.done

  // --- Submodule: TetrisGameOverLogic ---
  val gameOverLogic = Module(new TetrisGameOverLogic(buttonPressCountForReset = 4))
  gameOverLogic.io.enterGameOverState := inDoneWithGameOverState
  gameOverLogic.io.downButtonActive   := io.downButtonActive

  io.gameOver := gameOverLogic.io.inGameOverState
  val gameOverReset = gameOverLogic.io.gameOverReset

  // --- Submodule: TetrisScoreCounter ---
  val scoreCounter = Module(new TetrisScoreCounter())
  scoreCounter.io.incrementScore := incrementScore
  scoreCounter.io.resetToZero   := gameOverReset
  io.score := scoreCounter.io.score

  // --- Reading / Writing / Board row data outputs ---
  val clearingBoard = inClearBoardState | inInitialClearBoardState

  io.reading := inMoveIfAllowedState | Mux(addingOrRemovingShape, addOrRemoveShapeReadingOut, boardShiftReadingOut)
  io.writing := clearingBoard |
                (~shapeYCoordOutsideTheRange & Mux(addingOrRemovingShape, addOrRemoveShapeWritingOut, boardShiftWritingOut))
  io.boardRowDataOut := Mux(clearingBoard, 0.U,
                         Mux(addingOrRemovingShape, addRemoveShapeBoardRowDataOut, boardShiftBoardRowDataOut))

  // --- Drop timer ---
  val shapeDropTimerSaturated = !(shapeDropTimerQ < Mux(io.downButtonActive,
    shapeDropTimerFastMax.U(dropTimerBits.W), shapeDropTimerNormalMax.U(dropTimerBits.W)))

  // --- Next-state logic ---
  val posXD           = WireDefault(posXQ)
  val posYD           = WireDefault(posYQ)
  val shapeTypeD      = WireDefault(shapeTypeQ)
  val rotationD       = WireDefault(rotationQ)
  val stateD          = WireDefault(stateQ)
  val shapeDropTimerD = WireDefault(shapeDropTimerQ)
  val gameOverResetHappenedD = WireDefault(gameOverResetHappenedQ)

  addRemoveShapeStart      := io.start
  addRemoveShapeClearShape := io.start
  checkMoveAllowedStart    := false.B
  boardShifterStateStart   := false.B

  genRandomNum := !(inIdleState | inInitState)

  when(!gameOverResetHappenedQ) {
    gameOverResetHappenedD := gameOverReset
  }

  when(shapeDropTimerSaturated & io.done) {
    shapeDropTimerD := 0.U
  }.otherwise {
    shapeDropTimerD := shapeDropTimerQ + io.start
  }

  when(inPerformInitialBoardClearState) {
    when(io.start) {
      stateD := stInitialClearBoard
    }
  }

  when(inIdleState | inInitState) {
    when(io.start) {
      when(io.gameOver) {
        stateD := stDone
      }.elsewhen(gameOverResetHappenedQ) {
        gameOverResetHappenedD := false.B
        posYD  := 0.U
        stateD := stClearBoard
      }.otherwise {
        when(inInitState) {
          posXD      := io.shapeStartPosX
          posYD      := io.shapeStartPosY
          shapeTypeD := io.shapeStartType
        }
        stateD := stRemoveShapeFromTheBoard
      }
    }
  }

  when(inRemoveShapeFromTheBoardState) {
    when(addRemoveShapeDone) {
      stateD := stGetInput
    }
  }

  when(inGetInputState) {
    when(io.rotateButtonActive) {
      when(rotationQ < currentShapeLastRotationId) {
        rotationD := rotationQ + 1.U
      }.otherwise {
        rotationD := 0.U
      }
      checkMoveAllowedStart := true.B
      stateD := stRotateIsAllowed
    }.elsewhen(io.leftButtonActive && (posXQ =/= 0.U)) {
      posXD := posXQ - 1.U
      checkMoveAllowedStart := true.B
      stateD := stMoveLeftIfAllowed
    }.elsewhen(io.rightButtonActive && (posXQ =/= (boardWidthInBlocks - 1).U(posXBits.W))) {
      posXD := posXQ + 1.U
      checkMoveAllowedStart := true.B
      stateD := stMoveRightIfAllowed
    }.otherwise {
      stateD := stMoveShapeDownStep0
    }
  }

  when(inRotateIsAllowedState) {
    when(checkMoveAllowedDone) {
      when(!checkMoveAllowedResult) {
        when(rotationQ === 0.U) {
          rotationD := currentShapeLastRotationId
        }.otherwise {
          rotationD := rotationQ - 1.U 
        }
      }
      stateD := stMoveShapeDownStep0
    }
  }

  when(inMoveLeftIfAllowedState) {
    when(checkMoveAllowedDone) {
      when(!checkMoveAllowedResult) {
        posXD := posXQ + 1.U
      }
      stateD := stMoveShapeDownStep0
    }
  }

  when(inMoveRightIfAllowedState) {
    when(checkMoveAllowedDone) {
      when(!checkMoveAllowedResult) {
        posXD := posXQ - 1.U
      }
      stateD := stMoveShapeDownStep0
    }
  }

  when(inMoveShapeDownStateStep0) {
    when(shapeDropTimerSaturated) {
      stateD := stMoveShapeDownStep1
      checkMoveAllowedStart := true.B
      // Y + 1
      posYD := addSubbRes
    }.otherwise {
      addRemoveShapeStart := true.B
      stateD := stAddShapeToTheBoardAndDone
    }
  }

  when(inMoveShapeDownStateStep1) {
    when(checkMoveAllowedDone) {
      when(checkMoveAllowedResult) {
        // Y + 1
        posYD := addSubbRes
      }
      checkMoveAllowedStart := true.B
      stateD := stCheckIfShapeStoppedMoving
    }
  }

  when(inCheckIfShapeStoppedMovingState) {
    when(checkMoveAllowedDone) {
      // Y - 1
      posYD := addSubbRes
      addRemoveShapeStart := true.B
      when(!checkMoveAllowedResult) {
        stateD := stAddShapeToTheBoard
      }.otherwise {
        stateD := stAddShapeToTheBoardAndDone
      }
    }
  }

  when(inAddShapeToTheBoardState | inAddShapeToTheBoardAndDoneState) {
    when(addRemoveShapeDone) {
      when(inAddShapeToTheBoardAndDoneState) {
        stateD := stDone
      }.otherwise {
        boardShifterStateStart := true.B
        stateD := stShiftBoard
      }
    }
  }

  when(inShiftBoardState) {
    when(boardShifterStateDone) {
      stateD := stGetNextShape
    }
  }

  when(inGetNextShapeState) {
    shapeTypeD := randomNum0To6 
    posXD      := io.shapeStartPosX
    posYD      := io.shapeStartPosY
    rotationD  := 0.U
    checkMoveAllowedStart := true.B
    stateD := stCheckIfGameOverStep0
  }

  when(inCheckIfGameOverStep0State) {
    when(checkMoveAllowedDone) {
      when(!checkMoveAllowedResult) {
        posXD      := io.shapeStartPosX
        posYD      := 0.U
        shapeTypeD := 0.U
        stateD     := stDoneWithGameOver
      }.otherwise {
        // Y + 1
        posYD := addSubbRes
        checkMoveAllowedStart := true.B
        stateD := stCheckIfGameOverStep1
      }
    }
  }

  when(inCheckIfGameOverStep1State) {
    when(checkMoveAllowedDone) {
      // Y - 1
      posYD := addSubbRes
      when(!checkMoveAllowedResult) {
        posXD      := io.shapeStartPosX
        posYD      := 0.U
        shapeTypeD := 0.U
        stateD     := stDoneWithGameOver
      }.otherwise {
        stateD := stDone
      }
    }
  }

  when(inClearBoardState | inInitialClearBoardState) {
    when(shapeYCoordLastIndex) {
      posYD := 0.U
      stateD := Mux(inInitialClearBoardState, stDoneAfterInitialBoardClear, stDone)
    }.otherwise {
      // Y + 1
      posYD := addSubbRes
    }
  }

  when(inDoneWithGameOverState) {
    stateD := stIdle
  }

  when(inDoneAfterInitialBoardClearState) {
    stateD := stInitState
  }

  when(inDoneState) {
    stateD := Mux(io.alwaysStartInInitState, stInitState, stIdle)
  }

  // --- Register updates ---
  posXQ           := posXD
  posYQ           := posYD
  shapeTypeQ      := shapeTypeD
  rotationQ       := rotationD
  stateQ          := stateD
  shapeDropTimerQ := shapeDropTimerD
  gameOverResetHappenedQ := gameOverResetHappenedD
}
