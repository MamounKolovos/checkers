import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam_community/ansi
import iv

pub opaque type BoardIndex {
  BoardIndex(Int)
}

pub fn from_int(i: Int) -> Result(BoardIndex, Nil) {
  case i >= 0 && i < 32 {
    True -> BoardIndex(i) |> Ok
    False -> Nil |> Error
  }
}

pub fn to_int(index: BoardIndex) -> Int {
  let BoardIndex(i) = index
  i
}

pub fn index_to_row_col(index: BoardIndex) -> #(Int, Int) {
  let i = to_int(index)
  let row = i / 4
  let offset = i % 4

  let col = case row % 2 {
    0 -> offset * 2 + 1
    1 -> offset * 2
    _ -> panic
  }

  #(row, col)
}

pub fn row_col_to_index(row: Int, col: Int) -> Result(BoardIndex, Nil) {
  from_int({ row * 8 + col } / 2)
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

pub opaque type Board {
  Board(iv.Array(Square))
}

pub fn empty() -> Board {
  Board(iv.repeat(Empty, 32))
}

pub fn get(from board: Board, at index: BoardIndex) -> Square {
  let Board(squares) = board
  let assert Ok(square) = iv.get(from: squares, at: to_int(index))
  square
}

pub fn set(in board: Board, at index: BoardIndex, to square: Square) -> Board {
  let Board(squares) = board
  let assert Ok(squares) = iv.set(in: squares, at: to_int(index), to: square)
  Board(squares)
}

fn row_to_string(row: Int, board: Board) -> String {
  let columns =
    list.range(0, 7)
    |> list.map(fn(col) {
      case { row + col } % 2 == 1 {
        True -> {
          let assert Ok(index) = row_col_to_index(row, col)
          let square = get(board, at: index)
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
