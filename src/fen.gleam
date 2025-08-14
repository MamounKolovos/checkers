import board
import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/result
import gleam/string

pub type Error {
  SegmentMismatch
  OutOfRange
  DuplicateFound
  UnexpectedChar(expected: String, got: String)
}

pub type ParseResult {
  ParseResult(
    active_color: board.Color,
    squares: Dict(Int, board.Piece),
    white_count: Int,
    black_count: Int,
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
  use #(squares, squares1_count, fen) <- result.try(parse_pieces_until_colon(
    fen,
    color1,
  ))

  use fen <- result.try(parse_colon(fen))
  use #(color2, fen) <- result.try(parse_color(fen))
  // consume the second color's squares, stopping only when seeing the end of the string
  use #(squares, squares2_count, _) <- result.try(parse_pieces_until_eos(
    fen,
    color2,
    squares,
  ))

  // ensure the first and second colors are unique from each other
  use #(white_count, black_count) <- result.try(case color1, color2 {
    board.White, board.Black -> #(squares1_count, squares2_count) |> Ok
    board.Black, board.White -> #(squares2_count, squares1_count) |> Ok
    _, _ -> Error(SegmentMismatch)
  })
  ParseResult(active_color:, squares:, white_count:, black_count:) |> Ok
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
) -> Result(#(Dict(Int, board.Piece), Int, String), Error) {
  parse_pieces_until_colon_loop(fen, color, dict.new(), 0)
}

fn parse_pieces_until_colon_loop(
  fen: String,
  color: board.Color,
  acc: Dict(Int, board.Piece),
  count: Int,
) -> Result(#(Dict(Int, board.Piece), Int, String), Error) {
  use #(n, piece, fen) <- result.try(parse_full_piece(fen, color, False))
  use <- bool.guard(dict.has_key(acc, n), return: Error(DuplicateFound))

  case string.pop_grapheme(fen) {
    Ok(#(",", rest)) -> {
      parse_pieces_until_colon_loop(
        rest,
        color,
        dict.insert(acc, for: n, insert: piece),
        count + 1,
      )
    }
    Ok(#(":", _)) ->
      #(dict.insert(acc, for: n, insert: piece), count + 1, fen) |> Ok
    Ok(#(first, _)) ->
      UnexpectedChar(expected: "1-32 or , or EOS", got: first) |> Error
    Error(_) -> UnexpectedChar(expected: "1-32 or , or EOS", got: "") |> Error
  }
}

fn parse_pieces_until_eos(
  fen: String,
  color: board.Color,
  acc: Dict(Int, board.Piece),
) -> Result(#(Dict(Int, board.Piece), Int, String), Error) {
  parse_pieces_until_eos_loop(fen, color, acc, 0)
}

fn parse_pieces_until_eos_loop(
  fen: String,
  color: board.Color,
  acc: Dict(Int, board.Piece),
  count count: Int,
) -> Result(#(Dict(Int, board.Piece), Int, String), Error) {
  use #(n, piece, fen) <- result.try(parse_full_piece(fen, color, False))
  use <- bool.guard(dict.has_key(acc, n), return: Error(DuplicateFound))

  case string.pop_grapheme(fen) {
    Ok(#(",", rest)) -> {
      parse_pieces_until_eos_loop(
        rest,
        color,
        dict.insert(acc, for: n, insert: piece),
        count + 1,
      )
    }
    Ok(#(first, _)) ->
      UnexpectedChar(expected: "1-32 or , or EOS", got: first) |> Error
    Error(_) -> #(dict.insert(acc, for: n, insert: piece), count + 1, fen) |> Ok
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
