import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam_community/ansi
import gleam_community/colour
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
    King(White) -> "W"
    King(Black) -> "B"
    Man(White) -> "w"
    Man(Black) -> "b"
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

pub fn square_to_str(square: Square) -> String {
  case square {
    Empty -> ""
    Occupied(piece) -> piece_to_str(piece)
  }
}

pub opaque type Board {
  Board(iv.Array(Square))
}

pub fn piece_count(in board: Board, for color: Color) -> Int {
  let Board(squares) = board
  squares
  |> iv.filter(keeping: fn(square) {
    case square {
      Occupied(piece) if piece.color == color -> {
        True
      }
      _ -> False
    }
  })
  |> iv.length()
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

const enable_dim = "\u{001B}[2m"

const disable_dim = "\u{001B}[22m"

const top_left = enable_dim <> "┏" <> disable_dim

const top_right = enable_dim <> "┓" <> disable_dim

const bottom_left = enable_dim <> "┗" <> disable_dim

const bottom_right = enable_dim <> "┛" <> disable_dim

const horizontal_connector = enable_dim <> "━" <> disable_dim

const vertical_connector = enable_dim <> "┃" <> disable_dim

const top_intersection = enable_dim <> "┳" <> disable_dim

const bottom_intersection = enable_dim <> "┻" <> disable_dim

const left_intersection = enable_dim <> "┣" <> disable_dim

const right_intersection = enable_dim <> "┫" <> disable_dim

const center_intersection = enable_dim <> "╋" <> disable_dim

const board_left_margin = 1

/// Only odd widths supported
/// 
/// This is because even widths can't properly center characters
const square_width = 7

pub type SquareView {
  SquareView(
    // normal string content inside the square, length should be <= `square_width`
    content: Option(String),
    // highlights entire square with `color`, will be padded to `square_width`
    background: Option(colour.Color),
    position_content: Option(String),
  )
}

fn pad_spaces(times times: Int) -> String {
  string.repeat(" ", times)
}

fn top_border() -> String {
  let padding = pad_spaces(board_left_margin + 1)
  let left = top_left <> string.repeat(horizontal_connector, square_width - 1)
  let middle =
    string.repeat(
      horizontal_connector
        <> top_intersection
        <> string.repeat(horizontal_connector, square_width - 1),
      7,
    )
  let right = horizontal_connector <> top_right
  padding <> left <> middle <> right
}

fn row_divider() -> String {
  let padding = pad_spaces(board_left_margin + 1)
  let left =
    left_intersection <> string.repeat(horizontal_connector, square_width - 1)
  let middle =
    string.repeat(
      horizontal_connector
        <> center_intersection
        <> string.repeat(horizontal_connector, square_width - 1),
      7,
    )
  let right = horizontal_connector <> right_intersection
  padding <> left <> middle <> right
}

fn bottom_border() -> String {
  let padding = pad_spaces(board_left_margin + 1)
  let left =
    bottom_left <> string.repeat(horizontal_connector, square_width - 1)
  let middle =
    string.repeat(
      horizontal_connector
        <> bottom_intersection
        <> string.repeat(horizontal_connector, square_width - 1),
      7,
    )
  let right = horizontal_connector <> bottom_right
  padding <> left <> middle <> right
}

fn row_to_string(
  row: Int,
  board: Board,
  formatter: fn(Position, Square) -> SquareView,
) -> String {
  let columns =
    list.range(0, 7)
    |> list.map(fn(col) {
      case { row + col } % 2 == 1 {
        True -> {
          let assert Ok(position) = position.row_col_to_position(row, col)
          let square = get(board, at: position)

          case formatter(position, square) {
            SquareView(content:, background:, position_content:) -> {
              let render = case position_content {
                Some(position_content) -> {
                  let position_length =
                    position_content |> ansi.strip() |> string.length()
                  let center = { square_width / 2 } + 1

                  case content {
                    Some(content) -> {
                      let left_pad = case center - 1 - position_length {
                        space_left if space_left < 0 ->
                          panic as "cannot render, position has too many digits"
                        space_left -> space_left
                      }

                      let text_length =
                        content |> ansi.strip() |> string.length()
                      let right_pad = case center - 1 - text_length {
                        space_left if space_left < 0 ->
                          panic as "cannot render, square content has too many chars"
                        space_left -> space_left
                      }

                      pad_spaces(left_pad)
                      <> position_content
                      <> " "
                      <> content
                      <> pad_spaces(right_pad)
                    }
                    None ->
                      case center - position_length {
                        diff if diff < 0 ->
                          panic as "cannot render, position has too many digits"
                        diff -> {
                          let left_pad = center - 1
                          let right_pad = diff
                          pad_spaces(left_pad)
                          <> position_content
                          <> pad_spaces(right_pad)
                        }
                      }
                  }
                }
                None ->
                  case content {
                    Some(content) -> {
                      let text_length =
                        content |> ansi.strip() |> string.length()
                      case square_width - text_length {
                        diff if diff < 0 -> panic
                        0 -> content
                        diff -> {
                          let left_pad = diff / 2
                          let right_pad = diff - left_pad
                          pad_spaces(left_pad)
                          <> content
                          <> pad_spaces(right_pad)
                        }
                      }
                    }
                    None -> pad_spaces(square_width)
                  }
              }

              case background {
                Some(background) -> render |> ansi.bg_color(background)
                None -> render
              }
            }
          }
        }
        // not a playable square, should always be empty
        False -> pad_spaces(square_width)
      }
    })

  pad_spaces(board_left_margin)
  <> vertical_connector
  <> columns |> string.join(with: vertical_connector)
  <> vertical_connector
}

pub fn format(board: Board, formatter fun: fn(Position, Square) -> SquareView) {
  let rows =
    list.range(0, 7)
    |> list.map(fn(row) {
      int.to_string(8 - row) <> row_to_string(row, board, fun)
    })
    |> list.intersperse(row_divider())

  let column_display = {
    let left_padding = { board_left_margin + 2 } + { square_width / 2 }
    let column_string =
      ["A", "B", "C", "D", "E", "F", "G", "H"]
      |> string.join(with: pad_spaces(square_width))
    pad_spaces(left_padding) <> column_string
  }

  [top_border(), ..rows]
  |> list.append([bottom_border(), column_display])
  |> string.join(with: "\n")
}

pub fn to_string(board: Board) -> String {
  format(board, formatter: fn(_, square) {
    SquareView(
      content: square |> square_to_str() |> string.to_option(),
      background: None,
      position_content: None,
    )
  })
}

pub fn print(board: Board) {
  board
  |> to_string()
  |> io.println()
}

pub fn highlight(board: Board, positions: List(Position)) -> String {
  format(board, formatter: fn(position, square) {
    case list.contains(positions, position) {
      True ->
        SquareView(
          content: square
            |> square_to_str()
            |> ansi.bg_bright_green()
            |> string.to_option(),
          background: None,
          position_content: None,
        )
      False ->
        SquareView(
          content: square |> square_to_str() |> string.to_option(),
          background: None,
          position_content: None,
        )
    }
  })
}
