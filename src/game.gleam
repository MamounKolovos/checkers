import board.{type Board}
import fen
import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import raw_move

pub type Error {
  MoveAfterGameOver
  CannotMoveOpponentPiece
  NoPieceAtStart
  InvalidSimpleMove
  InvalidCaptureMove
  NoMovesForPiece
  FenError(fen.Error)
  RawMoveError(raw_move.Error)
}

//TODO: make opaque
pub type Game {
  Game(
    state: GameState,
    board: Board,
    active_color: board.Color,
    black_data: Data,
    white_data: Data,
  )
}

const plies_to_draw = 40

//TODO: make opaque
pub type Data {
  Data(squares: Dict(board.BoardIndex, board.Piece), plies_until_draw: Int)
}

//TODO: make opaque
pub type GameState {
  Win(board.Color)
  Draw
  Ongoing
}

pub fn create() -> Game {
  let assert Ok(game) =
    from_fen(
      "B:B1,2,3,4,5,6,7,8,9,10,11,12:W21,22,23,24,25,26,27,28,29,30,31,32",
    )
  game
}

pub fn from_fen(fen: String) -> Result(Game, Error) {
  case fen.parse(fen) {
    Ok(fen.ParseResult(active_color:, white_squares:, black_squares:)) -> {
      let board =
        dict.merge(white_squares, black_squares)
        |> dict.fold(from: board.empty(), with: fn(board, index, piece) {
          board.set(board, at: index, to: board.Occupied(piece))
        })

      let has_pieces_left =
        case active_color {
          board.Black -> black_squares
          board.White -> white_squares
        }
        // keep pieces with legal moves
        |> dict.filter(keeping: fn(index, piece) {
          let capture_builders = generate_capture_builders(board, index, piece)
          let simple_builders = generate_simple_builders(board, index, piece)
          case capture_builders, simple_builders {
            [], [] -> False
            _, _ -> True
          }
        })
        // game over if none remain
        |> dict.is_empty()

      let state = case has_pieces_left {
        True -> Win(board.switch_color(active_color))
        False -> Ongoing
      }

      Game(
        state:,
        board:,
        active_color:,
        black_data: Data(
          squares: black_squares,
          plies_until_draw: plies_to_draw,
        ),
        white_data: Data(
          squares: white_squares,
          plies_until_draw: plies_to_draw,
        ),
      )
      |> Ok
    }
    Error(e) -> Error(FenError(e))
  }
}

pub fn move(game: Game, request: String) -> Result(Game, Error) {
  use <- bool.guard(game.state != Ongoing, return: Error(MoveAfterGameOver))

  use #(from, middle, to) <- result.try(
    raw_move.parse(request)
    |> result.map_error(RawMoveError)
    |> result.map(raw_move.parts),
  )

  use piece <- result.try(
    board.get(game.board, at: from)
    |> board.get_piece()
    |> result.replace_error(NoPieceAtStart),
  )

  use <- bool.guard(
    game.active_color != piece.color,
    return: Error(CannotMoveOpponentPiece),
  )

  let capture_builders = generate_capture_builders(game.board, from, piece)
  let simple_builders = generate_simple_builders(game.board, from, piece)

  use #(piece, from, to, captured) <- result.try(
    case capture_builders, simple_builders {
      //no moves available
      [], [] -> Error(NoMovesForPiece)
      // Player is allowed to do a simple move since no captures are possible
      [], simple_builders -> {
        use SimpleBuilder(piece:, from:, to:) <- result.map(
          simple_builders
          |> list.find(fn(builder) { builder.from == from && builder.to == to })
          |> result.replace_error(InvalidSimpleMove),
        )
        #(piece, from, to, [])
      }
      // Player must do a capture move when one is available
      capture_builders, _ -> {
        use CaptureBuilder(piece:, from:, middle: _, to:, captured:) <- result.map(
          capture_builders
          |> list.find(fn(builder) {
            builder.from == from && builder.middle == middle && builder.to == to
          })
          |> result.replace_error(InvalidCaptureMove),
        )
        #(piece, from, to, captured)
      }
    },
  )

  // Promotion
  let #(row, _) = board.index_to_row_col(to)
  let piece = case piece, row {
    board.Man(board.Black as color), 7 | board.Man(board.White as color), 0 ->
      board.King(color)
    piece, _ -> piece
  }

  // Update board
  let board =
    game.board
    |> board.set(at: from, to: board.Empty)
    |> board.set(at: to, to: board.Occupied(piece))
    |> list.fold(captured, from: _, with: fn(acc, square_index) {
      board.set(acc, at: square_index, to: board.Empty)
    })

  let #(player_data, opponent_data) = {
    // use a player-opponent model instead of a black-white model
    // it allows us to avoid duplicating the logic for both colors
    let #(player_data, opponent_data) = case game.active_color {
      board.Black -> #(game.black_data, game.white_data)
      board.White -> #(game.white_data, game.black_data)
    }

    // move piece from origin to destination,
    // updating its position in terms of the mappings
    let player_squares =
      player_data.squares
      |> dict.delete(delete: from)
      |> dict.insert(for: to, insert: piece)

    // A draw requires a player to complete 40 plies without making a capture
    // or moving a man, reset the counter otherwise.
    let player_plies_until_draw = case captured, piece {
      [], board.King(color) if color == game.active_color ->
        player_data.plies_until_draw - 1
      _, _ -> plies_to_draw
    }

    // remove captured pieces from opponent's mappings
    let opponent_squares = dict.drop(opponent_data.squares, drop: captured)

    let player_data =
      Data(squares: player_squares, plies_until_draw: player_plies_until_draw)
    // plies are half-moves, so they can only change for the active player
    let opponent_data =
      Data(
        squares: opponent_squares,
        plies_until_draw: opponent_data.plies_until_draw,
      )

    #(player_data, opponent_data)
  }

  // convert back to black-white model after transformations are done
  let #(black_data, white_data) = case game.active_color {
    board.Black -> #(player_data, opponent_data)
    board.White -> #(opponent_data, player_data)
  }

  let opponent_movable_pieces =
    dict.filter(opponent_data.squares, keeping: fn(index, piece) {
      let capture_builders = generate_capture_builders(board, index, piece)
      let simple_builders = generate_simple_builders(board, index, piece)
      case capture_builders, simple_builders {
        [], [] -> False
        _, _ -> True
      }
    })

  let is_win =
    // captured all of opponent's pieces
    dict.is_empty(opponent_data.squares)
    // opponent has no more movable pieces
    || dict.is_empty(opponent_movable_pieces)

  let is_draw = case player_data.plies_until_draw {
    // player went 40 plies without capturing or moving a man
    plies if plies == 0 -> True
    // not a draw yet
    plies if plies > 0 -> False
    // negative; should never happen
    _ -> panic
  }

  let state = case is_win, is_draw {
    // wins take precedence over draws in the rare case both are true
    True, _ -> Win(game.active_color)
    False, True -> Draw
    False, False -> Ongoing
  }

  Game(
    state:,
    board:,
    active_color: board.switch_color(game.active_color),
    black_data:,
    white_data:,
  )
  |> Ok
}

type SimpleBuilder {
  SimpleBuilder(
    piece: board.Piece,
    from: board.BoardIndex,
    to: board.BoardIndex,
  )
}

fn generate_simple_builders(
  board: Board,
  from: board.BoardIndex,
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
    use to <- result.try(board.row_col_to_index(from_row + row, from_col + col))
    case board.get(board, to) {
      board.Empty -> SimpleBuilder(piece:, from:, to:) |> Ok
      _ -> Error(Nil)
    }
  })
}

type CaptureBuilder {
  CaptureBuilder(
    piece: board.Piece,
    from: board.BoardIndex,
    middle: List(board.BoardIndex),
    to: board.BoardIndex,
    captured: List(board.BoardIndex),
  )
}

type CaptureSearch {
  CaptureSearch(
    board: Board,
    piece: board.Piece,
    from: board.BoardIndex,
    current: board.BoardIndex,
    path: List(board.BoardIndex),
    captured: List(board.BoardIndex),
    acc: List(CaptureBuilder),
  )
}

fn generate_capture_builders(
  board: Board,
  from: board.BoardIndex,
  piece: board.Piece,
) -> List(CaptureBuilder) {
  generate_capture_builders_loop(
    CaptureSearch(
      board:,
      piece:,
      from:,
      current: from,
      path: [],
      captured: [],
      acc: [],
    ),
  )
}

fn generate_capture_builders_loop(
  capture_search: CaptureSearch,
) -> List(CaptureBuilder) {
  let CaptureSearch(board:, piece:, from:, current:, path:, captured:, acc:) =
    capture_search
  let #(from_row, from_col) = board.index_to_row_col(current)
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

      use to <- result.try(board.row_col_to_index(new_row, new_col))
      // destination square must be empty in order to jump to it
      case board.get(board, at: to) {
        board.Empty -> {
          let capture_row = from_row + { offset_row / 2 }
          let capture_col = from_col + { offset_col / 2 }
          use capture_index <- result.try(board.row_col_to_index(
            capture_row,
            capture_col,
          ))

          case board.get(board, at: capture_index) {
            board.Occupied(capture_piece) if capture_piece.color != piece.color ->
              #(to, capture_index) |> Ok
            _ -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    })
  case next_indexes, path, captured {
    [], [], [] -> []
    [], [to, ..rest], captured -> [
      CaptureBuilder(
        piece:,
        from:,
        middle: list.reverse(rest),
        to:,
        captured: list.reverse(captured),
      ),
      ..acc
    ]
    next_indexes, path, captured ->
      list.flat_map(next_indexes, fn(data) {
        let #(next, capture_index) = data
        generate_capture_builders_loop(
          CaptureSearch(
            ..capture_search,
            current: next,
            path: [next, ..path],
            captured: [capture_index, ..captured],
          ),
        )
      })
  }
}
