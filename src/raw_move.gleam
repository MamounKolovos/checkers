import gleam/list
import gleam/result

pub type Error {
  InvalidFile
  InvalidRank
  EmptyPath
  MissingDestination
}

pub opaque type RawMove {
  RawMove(from: Int, middle: List(Int), to: Int)
}

pub fn parts(raw_move: RawMove) -> #(Int, List(Int), Int) {
  #(raw_move.from, raw_move.middle, raw_move.to)
}

pub fn parse(request: String) -> Result(RawMove, Error) {
  parse_path(request)
}

fn parse_path(request: String) -> Result(RawMove, Error) {
  parse_path_loop(request, [])
}

fn parse_path_loop(
  request: String,
  positions: List(Int),
) -> Result(RawMove, Error) {
  case request {
    // base case - we've finished iterating, and now all everything is within
    // the `positions` variable
    "" -> {
      case positions {
        [] -> Error(EmptyPath)

        // `to` represents the final destination of the path. It'll be first,
        // because we're prepending to the list every time
        [to, ..rest] ->
          case list.reverse(rest) {
            [] -> Error(MissingDestination)

            // We use the new, reversed `middle` instead of `rest`, because since we
            // prepended to the list on creation, it was backwards before.
            [from, ..middle] -> RawMove(from:, middle:, to:) |> Ok
          }
      }
    }

    // Still iterating recursively - send the current character to
    // `parse_position`, and keep going
    request -> {
      use #(position, request) <- result.try(request |> parse_position())
      parse_path_loop(request, [position, ..positions])
    }
  }
}

fn parse_position(request: String) -> Result(#(Int, String), Error) {
  use #(col, request) <- result.try(request |> parse_file())
  use #(row, request) <- result.try(request |> parse_rank())
  let col_index = col - 1
  let row_index = row - 1
  #({ row_index * 8 + col_index } / 2, request) |> Ok
}

fn parse_file(request: String) -> Result(#(Int, String), Error) {
  case request {
    "a" <> rest -> Ok(#(1, rest))
    "b" <> rest -> Ok(#(2, rest))
    "c" <> rest -> Ok(#(3, rest))
    "d" <> rest -> Ok(#(4, rest))
    "e" <> rest -> Ok(#(5, rest))
    "f" <> rest -> Ok(#(6, rest))
    "g" <> rest -> Ok(#(7, rest))
    "h" <> rest -> Ok(#(8, rest))
    _ -> Error(InvalidFile)
  }
}

fn parse_rank(request: String) -> Result(#(Int, String), Error) {
  case request {
    "8" <> rest -> Ok(#(1, rest))
    "7" <> rest -> Ok(#(2, rest))
    "6" <> rest -> Ok(#(3, rest))
    "5" <> rest -> Ok(#(4, rest))
    "4" <> rest -> Ok(#(5, rest))
    "3" <> rest -> Ok(#(6, rest))
    "2" <> rest -> Ok(#(7, rest))
    "1" <> rest -> Ok(#(8, rest))
    _ -> Error(InvalidRank)
  }
}
