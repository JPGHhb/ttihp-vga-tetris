import chisel3._
import chisel3.util._

class TetrisShapeDataProvider(
    shapeCount: Int = 7
) extends RawModule {
  require(shapeCount <= 7, "Inconsistent configuration")

  val io = IO(new Bundle {
    val shapeSelector         = Input(UInt(log2Ceil(shapeCount).W))
    val shapeRotationSelector = Input(UInt(2.W))
    val shapeDataRowIndex     = Input(UInt(2.W))

    val shapeRowData              = Output(UInt(4.W))
    val currentShapeLastRotationId = Output(UInt(2.W))
  })

  val shapeData = Wire(Vec(2, UInt(8.W)))
  shapeData(0) := 0.U
  shapeData(1) := 0.U

  io.shapeRowData              := 0.U
  io.currentShapeLastRotationId := 0.U

  val rot = io.shapeRotationSelector

  switch(io.shapeSelector) {
    // TetrisShape_I
    //   Rotation 0: # # # #    Rotation 1: @ # # #
    //               @ @ @ @                @ # # #
    //               # # # #                @ # # #
    //               # # # #                @ # # #
    is(0.U) {
      io.currentShapeLastRotationId := 1.U
      when(rot === 0.U) {
        shapeData(0) := "b11110000".U
        shapeData(1) := "b00000000".U
      }
      when(rot === 1.U) {
        shapeData(0) := "b00010001".U
        shapeData(1) := "b00010001".U
      }
    }

    // TetrisShape_T
    //   Rot 0: @ @ @ #   Rot 1: # @ # #   Rot 2: # @ # #   Rot 3: @ # # #
    //          # @ # #          @ @ # #          @ @ @ #          @ @ # #
    //          # # # #          # @ # #          # # # #          @ # # #
    //          # # # #          # # # #          # # # #          # # # #
    is(1.U) {
      io.currentShapeLastRotationId := 3.U
      when(rot === 0.U) {
        shapeData(0) := "b01110000".U
        shapeData(1) := "b00000010".U
      }
      when(rot === 1.U) {
        shapeData(0) := "b00110010".U
        shapeData(1) := "b00000010".U
      }
      when(rot === 2.U) {
        shapeData(0) := "b01110010".U
        shapeData(1) := "b00000000".U
      }
      when(rot === 3.U) {
        shapeData(0) := "b00110001".U
        shapeData(1) := "b00000001".U
      }
    }

    // TetrisShape_J
    //   Rot 0: @ @ @ #   Rot 1: @ @ # #   Rot 2: # # @ #   Rot 3: @ # # #
    //          @ # # #          # @ # #          @ @ @ #          @ # # #
    //          # # # #          # @ # #          # # # #          @ @ # #
    //          # # # #          # # # #          # # # #          # # # #
    is(2.U) {
      io.currentShapeLastRotationId := 3.U
      when(rot === 0.U) {
        shapeData(0) := "b01110000".U
        shapeData(1) := "b00000001".U
      }
      when(rot === 1.U) {
        shapeData(0) := "b00100011".U
        shapeData(1) := "b00000010".U
      }
      when(rot === 2.U) {
        shapeData(0) := "b01110100".U
        shapeData(1) := "b00000000".U
      }
      when(rot === 3.U) {
        shapeData(0) := "b00010001".U
        shapeData(1) := "b00000011".U
      }
    }

    // TetrisShape_L
    //   Rot 0: @ # # #   Rot 1: @ @ # #   Rot 2: # # # #   Rot 3: # @ # #
    //          @ @ @ #          @ # # #          @ @ @ #          # @ # #
    //          # # # #          @ # # #          # # @ #          @ @ # #
    //          # # # #          # # # #          # # # #          # # # #
    is(3.U) {
      io.currentShapeLastRotationId := 3.U
      when(rot === 0.U) {
        shapeData(0) := "b01110001".U
        shapeData(1) := "b00000000".U
      }
      when(rot === 1.U) {
        shapeData(0) := "b00010011".U
        shapeData(1) := "b00000001".U
      }
      when(rot === 2.U) {
        shapeData(0) := "b01110000".U
        shapeData(1) := "b00000100".U
      }
      when(rot === 3.U) {
        shapeData(0) := "b00100010".U
        shapeData(1) := "b00000011".U
      }
    }

    // TetrisShape_Z
    //   Rot 0: @ @ # #   Rot 1: # @ # #
    //          # @ @ #          @ @ # #
    //          # # # #          @ # # #
    //          # # # #          # # # #
    is(4.U) {
      io.currentShapeLastRotationId := 1.U
      when(rot === 0.U) {
        shapeData(0) := "b00110000".U
        shapeData(1) := "b00000110".U
      }
      when(rot === 1.U) {
        shapeData(0) := "b00110010".U
        shapeData(1) := "b00000001".U
      }
    }

    // TetrisShape_S
    //   Rot 0: # @ @ #   Rot 1: @ # # #
    //          @ @ # #          @ @ # #
    //          # # # #          # @ # #
    //          # # # #          # # # #
    is(5.U) {
      io.currentShapeLastRotationId := 1.U
      when(rot === 0.U) {
        shapeData(0) := "b01100000".U
        shapeData(1) := "b00000011".U
      }
      when(rot === 1.U) {
        shapeData(0) := "b00110001".U
        shapeData(1) := "b00000010".U
      }
    }

    // TetrisShape_O
    //   Rot 0: @ @ # #
    //          @ @ # #
    //          # # # #
    //          # # # #
    is(6.U) {
      io.currentShapeLastRotationId := 0.U
      when(rot === 0.U) {
        shapeData(0) := "b00110011".U
        shapeData(1) := "b00000000".U
      }
    }
  }

  // Extract the 4-bit row from the packed 16-bit shape data
  switch(io.shapeDataRowIndex) {
    is(0.U) { io.shapeRowData := shapeData(0)(3, 0) }
    is(1.U) { io.shapeRowData := shapeData(0)(7, 4) }
    is(2.U) { io.shapeRowData := shapeData(1)(3, 0) }
    is(3.U) { io.shapeRowData := shapeData(1)(7, 4) }
  }
}
