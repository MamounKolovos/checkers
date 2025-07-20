import board.{type Board, type Color, Black, White}
import fen
import gleam/bool
import gleam/int
import gleam/list
import gleam/result
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
  let assert Ok(game) =
    from_fen(
      "B:B1,2,3,4,5,6,7,8,9,10,11,12:W21,22,23,24,25,26,27,28,29,30,31,32",
    )
  game
}

pub fn from_fen(fen: String) -> Result(Game, String) {
  case fen.parse(fen) {
    Ok(fen.ParseResult(active_color, white_squares, black_squares)) -> {
      let board =
        list.append(white_squares, black_squares)
        |> list.fold(from: iv.repeat(board.Empty, 32), with: fn(board, pair) {
          let #(number, piece) = pair
          iv.try_set(board, at: number - 1, to: board.Occupied(piece))
        })

      Game(
        board:,
        active_color:,
        white_count: list.length(white_squares),
        black_count: list.length(black_squares),
        is_over: False,
      )
      |> Ok
    }
    Error(e) -> Error(e)
  }
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
