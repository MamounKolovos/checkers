import gleam/int
import gleam/io
import gleam/list
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
    1 -> offset * 2
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

pub fn color_to_string(color: Color) -> String {
  case color {
    Black -> "Black"
    White -> "White"
  }
}

pub type Piece {
  Man(color: Color)
  King(color: Color)
}

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

fn row_to_string(row: Int, board: Board) -> String {
  let columns =
    list.range(0, 7)
    |> list.map(fn(col) {
      let i = row * 8 + col
      case { row + col } % 2 == 1 {
        True -> {
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
  to_string(board) |> io.println()
}
