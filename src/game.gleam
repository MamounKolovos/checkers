import board.{type Board, type Color, Black, White}
import fen
import gleam/bool
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

pub fn move(game: Game, request: String) -> Result(Game, String) {
  use parsed_move <- result.try(parsed_move.parse(request))
  use move <- result.try(from_parsed(game, parsed_move))

  case move {
    Simple(piece:, from:, to:) -> {
      let board =
        game.board
        |> iv.try_set(at: from, to: board.Empty)
        |> iv.try_set(at: to, to: board.Occupied(piece))
      let active_color = board.switch_color(game.active_color)
      Game(..game, board:, active_color:) |> Ok
    }
    Capture(piece:, from:, to:, captured:) -> {
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
  let #(from, middle, to) = parsed_move.parts(parsed)
  use piece <- result.try(
    iv.get_or_default(game.board, from, board.Empty)
    |> board.get_piece()
    |> result.replace_error("No piece at starting position"),
  )

  case generate_capture_builders(game, from, piece) {
    // In American Checkers, simple moves can only be taken if no captures are possible
    [] -> {
      generate_simple_builders(game, from, piece)
      |> list.find(fn(builder) {
        builder.from == from && middle == [] && builder.to == to
      })
      |> result.replace_error("Invalid simple move")
      |> result.map(build_simple_move)
    }
    capture_builders -> {
      capture_builders
      |> list.find(fn(builder) {
        builder.from == from && builder.middle == middle && builder.to == to
      })
      |> result.replace_error("Invalid capture move")
      |> result.map(build_capture_move)
    }
  }
}

type SimpleBuilder {
  SimpleBuilder(piece: board.Piece, from: Int, to: Int)
}

fn build_simple_move(builder: SimpleBuilder) -> Move {
  Simple(builder.piece, builder.from, builder.to)
}

fn generate_simple_builders(
  game: Game,
  from: Int,
  piece: board.Piece,
) -> List(SimpleBuilder) {
  let #(from_row, from_col) = board.index_to_row_col(from)
  case piece {
    board.Man(color) ->
      case color {
        board.Black -> [#(1, 1), #(1, -1)]
        board.White -> [#(-1, 1), #(-1, -1)]
      }
    board.King(_) -> [#(1, 1), #(1, -1), #(-1, 1), #(-1, -1)]
  }
  |> list.filter_map(fn(offset) {
    let #(row, col) = offset
    let to = board.row_col_to_index(from_row + row, from_col + col)
    case iv.get(game.board, to) {
      Ok(board.Empty) -> SimpleBuilder(piece:, from:, to:) |> Ok
      _ -> Error(Nil)
    }
  })
}

type CaptureBuilder {
  CaptureBuilder(
    piece: board.Piece,
    from: Int,
    middle: List(Int),
    to: Int,
    captured: List(Int),
  )
}

fn build_capture_move(builder: CaptureBuilder) -> Move {
  Capture(builder.piece, builder.from, builder.to, builder.captured)
}

type CaptureSearch {
  CaptureSearch(
    game: Game,
    from: Int,
    piece: board.Piece,
    builder: CaptureBuilder,
    acc: List(CaptureBuilder),
  )
}

fn generate_capture_builders(
  game: Game,
  from: Int,
  piece: board.Piece,
) -> List(CaptureBuilder) {
  generate_capture_builders_loop(
    CaptureSearch(
      game:,
      from:,
      piece:,
      builder: CaptureBuilder(piece:, from:, middle: [], to: -1, captured: []),
      acc: [],
    ),
  )
}

//TODO: account for promotions
fn generate_capture_builders_loop(
  capture_search: CaptureSearch,
) -> List(CaptureBuilder) {
  let CaptureSearch(game, from, piece, builder, acc) = capture_search
  let #(from_row, from_col) = board.index_to_row_col(from)
  let next_indexes =
    case piece {
      board.Man(board.Black) -> [#(2, 2), #(2, -2)]
      board.Man(board.White) -> [#(-2, 2), #(-2, -2)]
      board.King(_) -> [#(2, 2), #(2, -2), #(-2, 2), #(-2, -2)]
    }
    |> list.filter_map(fn(offset) {
      let #(offset_row, offset_col) = offset

      let new_row = from_row + offset_row
      let new_col = from_col + offset_col

      use <- bool.guard(
        new_row < 0 || new_row > 7 || new_col < 0 || new_col > 7,
        return: Error(Nil),
      )

      let capture_row = from_row + { offset_row / 2 }
      let capture_col = from_col + { offset_col / 2 }
      let capture_index = board.row_col_to_index(capture_row, capture_col)

      case iv.get(game.board, at: capture_index) {
        Ok(board.Occupied(capture_piece)) if capture_piece.color != piece.color ->
          #(board.row_col_to_index(new_row, new_col), capture_index) |> Ok
        _ -> Error(Nil)
      }
    })

  case next_indexes, builder {
    //no paths and no captures means a capture never occurred
    [], CaptureBuilder(captured: [], ..) -> []
    //no paths and some captures means the current path was fully explored
    [], CaptureBuilder(middle: [to, ..middle], captured:, ..) ->
      list.prepend(
        acc,
        CaptureBuilder(
          ..builder,
          middle: list.reverse(middle),
          to:,
          captured: list.reverse(captured),
        ),
      )
    next_indexes, CaptureBuilder(middle:, captured:, ..) ->
      list.flat_map(next_indexes, fn(data) {
        let #(to, capture_index) = data
        generate_capture_builders_loop(
          CaptureSearch(
            ..capture_search,
            from: to,
            builder: CaptureBuilder(
              ..builder,
              middle: [to, ..middle],
              captured: [capture_index, ..captured],
            ),
          ),
        )
      })
  }
}
