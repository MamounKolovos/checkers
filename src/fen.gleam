import board.{type Color, type Piece, Black, King, Man, White}
import gleam/int
import gleam/list
import gleam/result

pub type ParseResult {
  ParseResult(
    active_color: Color,
    white_squares: List(#(Int, Piece)),
    black_squares: List(#(Int, Piece)),
  )
}

//"B:W18,22,25,29,31:B1,5,9,12"
pub fn parse(fen: String) -> Result(ParseResult, String) {
  use #(active_color, fen) <- result.try(parse_color(fen))
  use #(squares1, color1, fen) <- result.try(parse_segment(fen))
  use #(squares2, color2, _) <- result.try(parse_segment(fen))

  use #(white_squares, black_squares) <- result.try(case color1, color2 {
    White, Black -> #(squares1, squares2) |> Ok
    Black, White -> #(squares2, squares1) |> Ok
    _, _ -> Error("Expected one white segment and one black segment")
  })

  ParseResult(active_color:, white_squares:, black_squares:) |> Ok
}

fn parse_segment(
  fen: String,
) -> Result(#(List(#(Int, Piece)), Color, String), String) {
  use fen <- result.try(parse_colon(fen))
  use #(color, fen) <- result.try(parse_color(fen))
  use #(squares, fen) <- result.try(parse_square_numbers(fen, color))
  #(squares, color, fen) |> Ok
}

fn parse_square_numbers(
  fen: String,
  color: Color,
) -> Result(#(List(#(Int, Piece)), String), String) {
  parse_square_numbers_loop(fen, color, [])
}

fn parse_square_numbers_loop(
  fen: String,
  color: Color,
  acc: List(#(Int, Piece)),
) -> Result(#(List(#(Int, Piece)), String), String) {
  use #(number, piece, fen) <- result.try(parse_square_number(fen, color))
  let acc = list.prepend(acc, #(number, piece))
  case fen {
    "," <> rest -> parse_square_numbers_loop(rest, color, acc)
    _ -> #(list.reverse(acc), fen) |> Ok
  }
}

fn parse_square_number(
  fen: String,
  color: Color,
) -> Result(#(Int, Piece, String), String) {
  use #(piece, fen) <- result.try(parse_king(fen, color))
  use #(number, fen) <- result.try(parse_int(fen))
  #(number, piece, fen) |> Ok
}

fn parse_color(fen: String) -> Result(#(Color, String), String) {
  case fen {
    "B" <> rest -> #(Black, rest) |> Ok
    "W" <> rest -> #(White, rest) |> Ok
    _ -> Error("Expected 'B' or 'W'")
  }
}

fn parse_colon(fen: String) -> Result(String, String) {
  case fen {
    ":" <> rest -> Ok(rest)
    _ -> Error("Expected a colon")
  }
}

fn parse_king(fen: String, color: Color) -> Result(#(Piece, String), String) {
  case fen {
    "K" <> rest -> #(King(color), rest) |> Ok
    _ -> #(Man(color), fen) |> Ok
  }
}

fn parse_int(fen: String) -> Result(#(Int, String), String) {
  do_parse_int(fen, "")
}

fn do_parse_int(
  fen: String,
  int_string: String,
) -> Result(#(Int, String), String) {
  case parse_int_char(fen) {
    Ok(#(char, rest)) -> do_parse_int(rest, int_string <> char)
    Error(_) -> {
      case int.parse(int_string) {
        Ok(n) -> Ok(#(n, fen))
        Error(Nil) -> Error("Expected an integer, got: " <> int_string)
      }
    }
  }
}

fn parse_int_char(fen: String) -> Result(#(String, String), String) {
  case fen {
    "0" <> rest -> Ok(#("0", rest))
    "1" <> rest -> Ok(#("1", rest))
    "2" <> rest -> Ok(#("2", rest))
    "3" <> rest -> Ok(#("3", rest))
    "4" <> rest -> Ok(#("4", rest))
    "5" <> rest -> Ok(#("5", rest))
    "6" <> rest -> Ok(#("6", rest))
    "7" <> rest -> Ok(#("7", rest))
    "8" <> rest -> Ok(#("8", rest))
    "9" <> rest -> Ok(#("9", rest))
    _ -> Error("Expected a digit, got: " <> fen)
  }
}
