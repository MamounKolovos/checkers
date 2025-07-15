import board
import gleam/bool
import gleam/list
import gleam/result
import gleam/string

pub type Move {
  Simple(piece: board.Piece, from: Int, to: Int)
  Capture(piece: board.Piece, from: Int, to: Int, captured: List(Int))
}

pub type ParsedMove {
  ParsedMove(path: List(Int))
}

pub fn parse(request: String) -> Result(ParsedMove, String) {
  use path <- result.try(parse_path(string.to_graphemes(request), []))
  ParsedMove(path:) |> Ok
}

fn parse_path(chars: List(String), path: List(Int)) -> Result(List(Int), String) {
  case chars {
    [file, rank, ..rest] -> {
      use position <- result.try(parse_position(file, rank))
      parse_path(rest, list.prepend(path, position))
    }
    _ -> path |> list.reverse |> Ok
  }
}

fn parse_position(file: String, rank: String) -> Result(Int, String) {
  use col <- result.try(parse_file(file))
  use row <- result.try(parse_rank(rank))
  let col_index = col - 1
  let row_index = row - 1
  Ok({ row_index * 8 + col_index } / 2)
}

fn parse_file(file: String) -> Result(Int, String) {
  case file {
    "a" -> Ok(1)
    "b" -> Ok(2)
    "c" -> Ok(3)
    "d" -> Ok(4)
    "e" -> Ok(5)
    "f" -> Ok(6)
    "g" -> Ok(7)
    "h" -> Ok(8)
    _ -> Error("Invalid file: must be a-h")
  }
}

fn parse_rank(rank: String) -> Result(Int, String) {
  case rank {
    "8" -> Ok(1)
    "7" -> Ok(2)
    "6" -> Ok(3)
    "5" -> Ok(4)
    "4" -> Ok(5)
    "3" -> Ok(6)
    "2" -> Ok(7)
    "1" -> Ok(8)
    _ -> Error("Invalid rank: must be 1-8")
  }
}
