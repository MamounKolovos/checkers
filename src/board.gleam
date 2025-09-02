import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam_community/ansi
import iv
import position.{type Position}

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

pub opaque type Board {
  Board(iv.Array(Square))
}

pub fn empty() -> Board {
  Board(iv.repeat(Empty, 32))
}

pub fn get(from board: Board, at position: Position) -> Square {
  let Board(squares) = board
  let assert Ok(square) = iv.get(from: squares, at: position.to_int(position))
  square
}

pub fn set(in board: Board, at position: Position, to square: Square) -> Board {
  let Board(squares) = board
  let assert Ok(squares) =
    iv.set(in: squares, at: position.to_int(position), to: square)
  Board(squares)
}

fn row_to_string(
  row: Int,
  board: Board,
  formatter: fn(Position, Square) -> String,
) -> String {
  let columns =
    list.range(0, 7)
    |> list.map(fn(col) {
      case { row + col } % 2 == 1 {
        True -> {
          let assert Ok(position) = position.row_col_to_position(row, col)
          let square = get(board, at: position)
          formatter(position, square)
        }
        False -> " "
      }
    })
    |> string.join(with: " | ")

  int.to_string(8 - row) <> " | " <> columns <> " |"
}

pub fn format(board: Board, formatter fun: fn(Position, Square) -> String) {
  let row_divider = "  ---------------------------------"
  let column_display = "    A   B   C   D   E   F   G   H"

  let rows =
    list.range(0, 7)
    |> list.map(row_to_string(_, board, fun))
    |> list.intersperse(row_divider)
    |> string.join(with: "\n")

  [row_divider, rows, row_divider, column_display]
  |> string.join(with: "\n")
}

pub fn to_string(board: Board) -> String {
  format(board, formatter: fn(_, square) { square_to_str(square) })
}

pub fn print(board: Board) {
  board
  |> to_string()
  |> io.println()
}

pub fn highlight(board: Board, positions: List(Position)) -> String {
  format(board, formatter: fn(position, square) {
    case list.contains(positions, position) {
      True -> square_to_str(square) |> ansi.bg_bright_green()
      False -> square_to_str(square)
    }
  })
}
