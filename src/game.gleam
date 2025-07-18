import board.{type Board, type Color, Black, White}
import gleam/bool
import gleam/int
import gleam/list
import gleam/result
import gleam/set.{type Set}
import iv
import parsed_move.{type ParsedMove}

pub opaque type Move {
  Simple(piece: board.Piece, from: Int, to: Int)
  Capture(piece: board.Piece, from: Int, to: Int, captured: List(Int))
}

pub type Game {
  Game(
    board: Board,
    active_color: Color,
    white_count: Int,
    black_count: Int,
    is_over: Bool,
  )
}

pub fn create() -> Game {
  Game(board.create(), Black, 12, 12, False)
}

pub fn player_move(game: Game, request: String) -> Result(Game, String) {
  use parsed_move <- result.try(parsed_move.parse(request))
  use move <- result.try(from_parsed(game, parsed_move))

  case move {
    Simple(piece, from, to) -> {
      let board =
        game.board
        |> iv.try_set(at: from, to: board.Empty)
        |> iv.try_set(at: to, to: board.Occupied(piece))
      let active_color = board.switch_color(game.active_color)
      Game(..game, board:, active_color:) |> Ok
    }
    Capture(piece, from, to, captured) -> {
      let board =
        game.board
        |> iv.try_set(at: from, to: board.Empty)
        |> iv.try_set(at: to, to: board.Occupied(piece))
        |> list.fold(captured, from: _, with: fn(acc, square_index) {
          iv.try_set(acc, at: square_index, to: board.Empty)
        })

      let captured_count = list.length(captured)
      let #(white_count, black_count) = case game.active_color {
        Black -> #(game.white_count - captured_count, game.black_count)
        White -> #(game.white_count, game.black_count - captured_count)
      }

      let is_over = white_count == 0 || black_count == 0
      let active_color = case is_over {
        True -> game.active_color
        False -> board.switch_color(game.active_color)
      }
      Game(board:, active_color:, white_count:, black_count:, is_over:)
      |> Ok
    }
  }
}

pub fn from_parsed(game: Game, parsed: ParsedMove) -> Result(Move, String) {
  case parsed_move.path(parsed) {
    [from, to] ->
      case is_capture_move(from, to) {
        True -> {
          use builder <- result.try(from_parsed_to_capture(
            game,
            from,
            to,
            parsed_move.path(parsed),
          ))
          Capture(builder.piece, builder.from, builder.to, builder.captured)
          |> Ok
        }
        False -> {
          use builder <- result.try(from_parsed_to_simple(game, from, to))
          Simple(builder.piece, builder.from, builder.to) |> Ok
        }
      }
    [from, first_to, ..] -> {
      use builder <- result.try(from_parsed_to_capture(
        game,
        from,
        first_to,
        parsed_move.path(parsed),
      ))
      Capture(builder.piece, builder.from, builder.to, builder.captured)
      |> Ok
    }
    _ -> {
      Error("Invalid ParsedMove")
    }
  }
}

fn is_capture_move(from: Int, to: Int) -> Bool {
  let #(from_row, from_col) = board.index_to_row_col(from)
  let #(to_row, to_col) = board.index_to_row_col(to)

  int.absolute_value(to_row - from_row) == 2
  && int.absolute_value(to_col - from_col) == 2
}

fn is_valid_step(
  piece: board.Piece,
  row_diff: Int,
  col_diff: Int,
  step expected_step: Int,
) -> Bool {
  let abs_col = int.absolute_value(col_diff)

  case piece {
    board.Man(Black) -> row_diff == expected_step && abs_col == expected_step
    board.Man(White) -> row_diff == -expected_step && abs_col == expected_step
    board.King(_) ->
      int.absolute_value(row_diff) == expected_step && abs_col == expected_step
  }
}

type SimpleBuilder {
  SimpleBuilder(piece: board.Piece, from: Int, to: Int)
}

fn from_parsed_to_simple(
  game: Game,
  from: Int,
  to: Int,
) -> Result(SimpleBuilder, String) {
  use <- bool.guard(
    from == to,
    return: Error("Can't move to the same position"),
  )
  use <- bool.guard(
    iv.get_or_default(game.board, to, board.Empty) != board.Empty,
    return: Error("Destination square is not empty"),
  )
  use piece <- result.try(
    iv.get_or_default(game.board, from, board.Empty)
    |> board.get_piece()
    |> result.replace_error("No piece at the starting position"),
  )
  use <- bool.guard(
    piece.color != game.active_color,
    return: Error("Active player does not own this piece"),
  )
  let #(from_row, from_col) = board.index_to_row_col(from)

  use <- bool.guard(
    { from_row + from_col } % 2 == 0,
    return: Error("Start position must be a dark square"),
  )

  let #(to_row, to_col) = board.index_to_row_col(to)

  use <- bool.guard(
    { to_row + to_col } % 2 == 0,
    return: Error("End position must be a dark square"),
  )

  let row_diff = to_row - from_row
  let col_diff = to_col - from_col

  use <- bool.guard(
    !is_valid_step(piece, row_diff, col_diff, step: 1),
    return: Error(
      "Invalid simple move: must be a one-square diagonal step in the correct direction",
    ),
  )
  SimpleBuilder(piece:, from:, to:) |> Ok
}

type CaptureBuilder {
  CaptureBuilder(piece: board.Piece, from: Int, to: Int, captured: List(Int))
}

fn from_parsed_to_capture(
  game: Game,
  from: Int,
  first_to: Int,
  path: List(Int),
) -> Result(CaptureBuilder, String) {
  use <- bool.guard(
    from == first_to,
    return: Error("Can't move to the same position"),
  )
  use <- bool.guard(
    iv.get_or_default(game.board, first_to, board.Empty) != board.Empty,
    return: Error("Destination square is not empty"),
  )
  use piece <- result.try(
    iv.get_or_default(game.board, from, board.Empty)
    |> board.get_piece()
    |> result.replace_error("No piece at the starting position"),
  )
  use <- bool.guard(
    piece.color != game.active_color,
    return: Error("Active player does not own this piece"),
  )
  from_parsed_to_capture_loop(
    game,
    list.window_by_2(path),
    CaptureBuilder(piece, from, first_to, []),
  )
}

fn from_parsed_to_capture_loop(
  game: Game,
  move_pairs: List(#(Int, Int)),
  acc: CaptureBuilder,
) -> Result(CaptureBuilder, String) {
  case move_pairs {
    [] -> CaptureBuilder(..acc, captured: list.reverse(acc.captured)) |> Ok
    [#(from, to), ..rest] -> {
      let #(from_row, from_col) = board.index_to_row_col(from)

      use <- bool.guard(
        { from_row + from_col } % 2 == 0,
        return: Error("Start position must be a dark square"),
      )

      let #(to_row, to_col) = board.index_to_row_col(to)

      use <- bool.guard(
        { to_row + to_col } % 2 == 0,
        return: Error("End position must be a dark square"),
      )

      let row_diff = to_row - from_row
      let col_diff = to_col - from_col

      use <- bool.guard(
        !is_valid_step(acc.piece, row_diff, col_diff, step: 2),
        return: Error(
          "Invalid simple move: must be a two-square diagonal step in the correct direction",
        ),
      )

      let mid_row = from_row + { row_diff / 2 }
      let mid_col = from_col + { col_diff / 2 }
      let mid_index = board.row_col_to_index(mid_row, mid_col)

      let did_capture = case
        iv.get_or_default(game.board, mid_index, board.Empty)
      {
        board.Occupied(mid_piece) -> mid_piece.color != acc.piece.color
        board.Empty -> False
      }

      use <- bool.guard(!did_capture, return: Error("No piece to capture"))
      from_parsed_to_capture_loop(
        game,
        rest,
        CaptureBuilder(
          ..acc,
          to:,
          captured: list.prepend(acc.captured, mid_index),
        ),
      )
    }
  }
}

type CaptureSearch {
  CaptureSearch(
    board: Board,
    position: Int,
    path: List(Int),
    visited: Set(Int),
    piece: board.Piece,
    acc: List(List(Int)),
  )
}

fn find_capture_paths(board: Board, position: Int, piece: board.Piece) {
  let cs =
    CaptureSearch(
      board:,
      position:,
      path: [],
      visited: set.new(),
      piece:,
      acc: [],
    )
  find_capture_paths_loop(cs)
}

fn find_capture_paths_loop(cs: CaptureSearch) -> List(List(Int)) {
  let #(_, col) = board.index_to_row_col(cs.position)

  let next_paths =
    case cs.piece {
      board.Man(color) ->
        case color {
          board.Black -> [7, 9]
          board.White -> [-7, -9]
        }
      board.King(_) -> [7, 9, -7, -9]
    }
    |> list.filter(fn(delta) {
      let to = cs.position + delta
      let inside_board = to >= 0 && to < 32

      let inside_edge = case delta {
        7 | -7 -> col <= 5
        9 | -9 -> col >= 2
        _ -> False
      }

      let mid = cs.position + { delta / 2 }
      let did_capture = case iv.get_or_default(cs.board, mid, board.Empty) {
        board.Occupied(mid_piece) -> mid_piece.color != cs.piece.color
        board.Empty -> False
      }

      inside_board && inside_edge && did_capture
    })
    |> list.map(fn(delta) { cs.position + delta })

  case next_paths {
    [] ->
      case cs.path {
        [] -> cs.acc
        _ -> list.prepend(cs.acc, list.reverse(cs.path))
      }
    _ -> {
      list.flat_map(next_paths, fn(x) {
        find_capture_paths_loop(
          CaptureSearch(
            ..cs,
            position: x,
            path: list.prepend(cs.path, x),
            visited: set.insert(cs.visited, x),
          ),
        )
      })
    }
  }
}
