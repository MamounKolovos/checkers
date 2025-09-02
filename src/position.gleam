import gleam/bool

pub opaque type Position {
  Position(Int)
}

pub fn from_int(i: Int) -> Result(Position, Nil) {
  case i >= 0 && i < 32 {
    True -> Position(i) |> Ok
    False -> Nil |> Error
  }
}

pub fn to_int(position: Position) -> Int {
  let Position(i) = position
  i
}

pub fn position_to_row_col(position: Position) -> #(Int, Int) {
  let i = to_int(position)
  let row = i / 4
  let offset = i % 4

  let col = case row % 2 {
    0 -> offset * 2 + 1
    1 -> offset * 2
    _ -> panic
  }

  #(row, col)
}

pub fn row_col_to_position(row: Int, col: Int) -> Result(Position, Nil) {
  use <- bool.guard(
    row < 0 || row >= 8 || col < 0 || col >= 8,
    return: Error(Nil),
  )

  case { row + col } % 2 == 1 {
    True -> from_int({ row * 8 + col } / 2)
    False -> Error(Nil)
  }
}
