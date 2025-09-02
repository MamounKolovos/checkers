import error.{type Error}
import gleam/bool
import gleam/list
import gleam/result
import position.{type Position}

type Selection =
  Position

pub fn parse_selection(request: String) -> Result(Selection, Error) {
  use <- bool.guard(request == "", return: Error(error.EmptyRequest))

  use #(position, request) <- result.try(request |> parse_position())
  case request {
    "" -> position |> Ok
    request -> error.UnexpectedTrailingRequest(got: request) |> Error
  }
}

type Move =
  #(Position, List(Position), Position)

pub fn parse_move(request: String) -> Result(Move, Error) {
  parse_move_loop(request, [])
}

fn parse_move_loop(
  request: String,
  positions: List(Position),
) -> Result(Move, Error) {
  case request {
    // base case - we've finished iterating, and now all everything is within
    // the `positions` variable
    "" -> {
      case positions {
        [] -> Error(error.EmptyRequest)
        [_] -> Error(error.IncompleteMove)

        // `to` represents the final destination of the path. It'll be first,
        // because we're prepending to the list every time
        [to, ..rest] -> {
          // We use the new, reversed `middle` instead of `rest`, because since we
          // prepended to the list on creation, it was backwards before.

          // We must assert on the reverse since it doesn't know we already 
          // handled the empty list case above
          let assert [from, ..middle] = list.reverse(rest)
          #(from, middle, to) |> Ok
        }
      }
    }

    // Still iterating recursively - send the current character to
    // `parse_position`, and keep going
    request -> {
      use #(position, request) <- result.try(request |> parse_position())
      parse_move_loop(request, [position, ..positions])
    }
  }
}

fn parse_position(request: String) -> Result(#(Position, String), Error) {
  use #(col, request) <- result.try(request |> parse_file())
  use #(row, request) <- result.try(request |> parse_rank())
  let assert Ok(position) = position.row_col_to_position(row, col)
  #(position, request) |> Ok
}

fn parse_file(request: String) -> Result(#(Int, String), Error) {
  case request {
    "a" <> rest -> Ok(#(0, rest))
    "b" <> rest -> Ok(#(1, rest))
    "c" <> rest -> Ok(#(2, rest))
    "d" <> rest -> Ok(#(3, rest))
    "e" <> rest -> Ok(#(4, rest))
    "f" <> rest -> Ok(#(5, rest))
    "g" <> rest -> Ok(#(6, rest))
    "h" <> rest -> Ok(#(7, rest))
    _ -> Error(error.InvalidFile)
  }
}

fn parse_rank(request: String) -> Result(#(Int, String), Error) {
  case request {
    "8" <> rest -> Ok(#(0, rest))
    "7" <> rest -> Ok(#(1, rest))
    "6" <> rest -> Ok(#(2, rest))
    "5" <> rest -> Ok(#(3, rest))
    "4" <> rest -> Ok(#(4, rest))
    "3" <> rest -> Ok(#(5, rest))
    "2" <> rest -> Ok(#(6, rest))
    "1" <> rest -> Ok(#(7, rest))
    _ -> Error(error.InvalidRank)
  }
}
