import board
import error.{type Error}
import gleam/list
import gleam/result

// pub type Error {
//   InvalidFile
//   InvalidRank
//   EmptyPath
//   MissingDestination
// }

// Important to remember that `middle` being present guarantees its a capture,
// but it *not* being present doesn't guarantee its *not* a capture
// cannot classify simple/capture by `middle`'s state 
pub type Action {
  Move(
    from: board.BoardIndex,
    middle: List(board.BoardIndex),
    to: board.BoardIndex,
  )
  Select(from: board.BoardIndex)
}

pub fn parse(request: String) -> Result(Action, Error) {
  parse_path(request)
}

fn parse_path(request: String) -> Result(Action, Error) {
  parse_path_loop(request, [])
}

fn parse_path_loop(
  request: String,
  positions: List(board.BoardIndex),
) -> Result(Action, Error) {
  case request {
    // base case - we've finished iterating, and now all everything is within
    // the `positions` variable
    "" -> {
      case positions {
        [] -> Error(error.EmptyPath)
        [from] -> Select(from:) |> Ok

        // `to` represents the final destination of the path. It'll be first,
        // because we're prepending to the list every time
        [to, ..rest] -> {
          // We use the new, reversed `middle` instead of `rest`, because since we
          // prepended to the list on creation, it was backwards before.

          // We must assert on the reverse since it doesn't know we already 
          // handled the empty list case above
          let assert [from, ..middle] = list.reverse(rest)
          Move(from:, middle:, to:) |> Ok
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

fn parse_position(request: String) -> Result(#(board.BoardIndex, String), Error) {
  use #(col, request) <- result.try(request |> parse_file())
  use #(row, request) <- result.try(request |> parse_rank())
  let col_index = col - 1
  let row_index = row - 1
  let assert Ok(index) = board.row_col_to_index(row_index, col_index)
  #(index, request) |> Ok
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
    _ -> Error(error.InvalidFile)
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
    _ -> Error(error.InvalidRank)
  }
}
