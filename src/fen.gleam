import board
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type Error {
  SegmentMismatch
  OutOfRange
  UnexpectedChar(expected: String, got: String)
}

pub type ParseResult {
  ParseResult(
    active_color: board.Color,
    white_squares: List(#(Int, board.Piece)),
    black_squares: List(#(Int, board.Piece)),
  )
}

// format of fen: "[Turn]:[Color 1][K][Square number][,]...]:[Color 2][K][Square number][,]...]"
// example: "B:W18,22,25,29,31:B1,5,9,12"
pub fn parse(fen: String) -> Result(ParseResult, Error) {
  // consume the active color from the start of the fen
  // "B:W18,..." -> active_color = Black
  use #(active_color, fen) <- result.try(parse_color(fen))

  use fen <- result.try(parse_colon(fen))
  use #(color1, fen) <- result.try(parse_color(fen))
  // consume the first color's squares, stopping only when seeing a colon
  use #(squares1, fen) <- result.try(parse_pieces_until_colon(fen, color1, []))

  use fen <- result.try(parse_colon(fen))
  use #(color2, fen) <- result.try(parse_color(fen))
  // consume the second color's squares, stopping only when seeing the end of the string
  use #(squares2, _) <- result.try(parse_pieces_until_eos(fen, color2, []))

  // ensure the first and second colors are unique from each other
  use #(white_squares, black_squares) <- result.try(case color1, color2 {
    board.White, board.Black -> #(squares1, squares2) |> Ok
    board.Black, board.White -> #(squares2, squares1) |> Ok
    _, _ -> Error(SegmentMismatch)
  })

  ParseResult(active_color:, white_squares:, black_squares:) |> Ok
}

fn parse_color(fen: String) -> Result(#(board.Color, String), Error) {
  case string.pop_grapheme(fen) {
    Ok(#("B", rest)) -> #(board.Black, rest) |> Ok
    Ok(#("W", rest)) -> #(board.White, rest) |> Ok
    Ok(#(first, _)) -> UnexpectedChar(expected: "B or W", got: first) |> Error
    Error(_) -> UnexpectedChar(expected: "B or W", got: "") |> Error
  }
}

fn parse_colon(fen: String) -> Result(String, Error) {
  case string.pop_grapheme(fen) {
    Ok(#(":", rest)) -> rest |> Ok
    Ok(#(first, _)) -> UnexpectedChar(expected: ":", got: first) |> Error
    Error(_) -> UnexpectedChar(expected: ":", got: "") |> Error
  }
}

fn parse_pieces_until_colon(
  fen: String,
  color: board.Color,
  acc: List(#(Int, board.Piece)),
) -> Result(#(List(#(Int, board.Piece)), String), Error) {
  use #(n, piece, fen) <- result.try(parse_full_piece(fen, color, False))

  case string.pop_grapheme(fen) {
    Ok(#(",", rest)) -> {
      parse_pieces_until_colon(rest, color, [#(n, piece), ..acc])
    }
    Ok(#(":", _)) -> #([#(n, piece), ..acc] |> list.reverse(), fen) |> Ok
    Ok(#(first, _)) ->
      UnexpectedChar(expected: "1-32 or , or EOS", got: first) |> Error
    Error(_) -> UnexpectedChar(expected: "1-32 or , or EOS", got: "") |> Error
  }
}

fn parse_pieces_until_eos(
  fen: String,
  color: board.Color,
  acc: List(#(Int, board.Piece)),
) -> Result(#(List(#(Int, board.Piece)), String), Error) {
  use #(n, piece, fen) <- result.try(parse_full_piece(fen, color, False))

  case string.pop_grapheme(fen) {
    Ok(#(",", rest)) -> {
      parse_pieces_until_eos(rest, color, [#(n, piece), ..acc])
    }
    Ok(#(first, _)) ->
      UnexpectedChar(expected: "1-32 or , or EOS", got: first) |> Error
    Error(_) -> #([#(n, piece), ..acc] |> list.reverse(), fen) |> Ok
  }
}

fn parse_full_piece(
  fen: String,
  color: board.Color,
  k_parsed: Bool,
) -> Result(#(Int, board.Piece, String), Error) {
  case string.pop_grapheme(fen) {
    Ok(#(first, rest)) ->
      case first {
        "K" -> parse_full_piece(rest, color, True)

        "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> {
          let #(n, rest) = parse_piece_loop(rest, first)
          case n > 0 && n <= 32 {
            True ->
              case k_parsed {
                True -> #(n, board.King(color), rest) |> Ok
                False -> #(n, board.Man(color), rest) |> Ok
              }
            False -> OutOfRange |> Error
          }
        }

        first -> UnexpectedChar("K or 1-32", got: first) |> Error
      }

    Error(_) -> UnexpectedChar("K or 1-32", got: "") |> Error
  }
}

fn parse_piece_loop(fen: String, int_string: String) -> #(Int, String) {
  case parse_piece_char(fen) {
    Ok(#(char, rest)) -> parse_piece_loop(rest, int_string <> char)
    Error(_) -> {
      let assert Ok(n) = int.parse(int_string)
      #(n, fen)
    }
  }
}

fn parse_piece_char(fen: String) -> Result(#(String, String), Nil) {
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
    _ -> Error(Nil)
  }
}
