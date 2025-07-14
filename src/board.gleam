import gleam/bool
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam_community/ansi
import iv

pub type Position {
  Position(row: Int, col: Int)
}

pub fn index_to_row_col(index: Int) -> #(Int, Int) {
  let row = index / 4
  let offset = index % 4

  let col = case row % 2 {
    0 -> offset * 2 + 1
    // even rows: B, D, F, H (odd col indices)
    1 -> offset * 2
    // odd rows: A, C, E, G (even col indices)
    _ -> panic
  }

  #(row, col)
}

pub fn row_col_to_index(row: Int, col: Int) -> Int {
  { row * 8 + col } / 2
}

pub fn position_to_index(position: Position) -> Int {
  position.row * 4 + position.col
}

pub fn position_to_square(board: Board, position: Position) -> Square {
  iv.get_or_default(board, position_to_index(position), Empty)
}

pub fn is_valid_position(position: Position) -> Bool {
  { position.row + position.col } % 2 == 1
}

pub type Color {
  White
  Black
}

pub fn switch_color(color: Color) -> Color {
  case color {
    Black -> White
    White -> Black
  }
}

pub type Piece {
  Man(color: Color)
  King(color: Color)
}

pub fn is_king(piece: Piece) -> Bool {
  case piece {
    King(_) -> True
    _ -> False
  }
}

// pub fn get_piece_color(piece: Piece) -> Color {
//   case piece {
//     King(White) -> White
//     King(Black) -> Black
//     Man(White) -> White
//     Man(Black) -> Black
//   }
// }

fn piece_to_str(piece: Piece) -> String {
  case piece {
    King(White) -> "O" |> ansi.blue()
    King(Black) -> "X" |> ansi.red()
    Man(White) -> "o" |> ansi.blue()
    Man(Black) -> "x" |> ansi.red()
  }
}

pub type Square {
  Empty
  Occupied(Piece)
}

pub fn get_piece(square: Square) -> Result(Piece, Nil) {
  case square {
    Occupied(piece) -> Ok(piece)
    Empty -> Error(Nil)
  }
}

fn square_to_str(square: Square) -> String {
  case square {
    Empty -> " "
    Occupied(piece) -> piece_to_str(piece)
  }
}

pub type Board =
  iv.Array(Square)

pub fn create() -> Board {
  use i <- iv.initialise(32)
  let assert Ok(row) = int.floor_divide(i, 4)
  case row {
    0 | 1 | 2 -> Occupied(Man(Black))
    5 | 6 | 7 -> Occupied(Man(White))
    _ -> Empty
  }
}

// pub fn update(board: Board) -> Board {
//   iv.update()
// }

fn col_to_str(col: Int) -> String {
  case col {
    0 -> "A"
    1 -> "B"
    2 -> "C"
    3 -> "D"
    4 -> "E"
    5 -> "F"
    6 -> "G"
    7 -> "H"
    _ -> "?"
  }
}

type DisplayConfig {
  DisplayConfig(
    edge_spacing: Int,
    square_spacing: Int,
    col_num_spacing: Int,
    black_color: fn(String) -> String,
    white_color: fn(String) -> String,
  )
}

fn spacing_to_str(spacing: Int) -> String {
  string.repeat(" ", spacing)
}

fn row_to_string(row: Int, board: Board) -> String {
  let columns =
    list.range(0, 7)
    |> list.map(fn(col) {
      let i = row * 8 + col
      case { row + col } % 2 == 1 {
        True -> {
          // int.to_string(i / 2)
          let square = iv.get_or_default(board, i / 2, or: Empty)
          square_to_str(square)
        }
        False -> " "
      }
    })
    |> string.join(with: " | ")

  int.to_string(8 - row) <> " | " <> columns <> " |"
}

fn to_string(board: Board) {
  let row_divider = "  ---------------------------------"
  let column_display = "    A   B   C   D   E   F   G   H"

  let rows =
    list.range(0, 7)
    |> list.map(row_to_string(_, board))
    |> list.intersperse(row_divider)
    |> string.join(with: "\n")

  [row_divider, rows, row_divider, column_display]
  |> string.join(with: "\n")
}

pub fn print(board: Board) {
  // let config =
  //   DisplayConfig(
  //     edge_spacing: 0,
  //     square_spacing: 1,
  //     col_num_spacing: 1,
  //     black_color: ansi.red,
  //     white_color: ansi.blue,
  //   )
  to_string(board) |> io.println()
}
