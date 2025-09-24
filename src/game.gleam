import board.{type Board}
import error.{type Error}
import fen
import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam_community/ansi
import position.{type Position}

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
  Data(mappings: Dict(Position, board.Piece), plies_until_draw: Int)
}

//TODO: make opaque
//TODO: add forfeit
pub type GameState {
  Win(board.Color)
  Draw
  Ongoing
}

/// Opponent just moved, determine state from the perspective of the new active player
fn state(game: Game) -> GameState {
  let opponent_plies_until_draw = case game.active_color {
    board.Black -> game.white_data.plies_until_draw
    board.White -> game.black_data.plies_until_draw
  }

  let is_draw = case opponent_plies_until_draw {
    // opponent went 40 plies without capturing or moving a man
    plies if plies == 0 -> True
    // not a draw yet
    plies if plies > 0 -> False
    // negative; should never happen
    _ -> panic
  }

  case is_active_player_defeated(game), is_draw {
    // wins take precedence over draws in the rare case both are true
    True, _ -> Win(board.switch_color(game.active_color))
    False, True -> Draw
    False, False -> Ongoing
  }
}

/// Defeated if all player's pieces are captured OR 
/// if player has no pieces left with legal moves
fn is_active_player_defeated(game: Game) -> Bool {
  game |> generate_legal_moves_for_player() |> list.is_empty()
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
    Ok(fen.ParseResult(active_color:, white_mappings:, black_mappings:)) -> {
      let board =
        dict.merge(white_mappings, black_mappings)
        |> dict.fold(from: board.empty(), with: fn(board, position, piece) {
          board.set(board, at: position, to: board.Occupied(piece))
        })

      let game =
        Game(
          state: Ongoing,
          board:,
          active_color:,
          black_data: Data(
            mappings: black_mappings,
            plies_until_draw: plies_to_draw,
          ),
          white_data: Data(
            mappings: white_mappings,
            plies_until_draw: plies_to_draw,
          ),
        )

      Game(..game, state: state(game)) |> Ok
    }
    Error(e) -> Error(e)
  }
}

pub fn move(
  game: Game,
  piece: board.Piece,
  from: Position,
  middle: List(Position),
  to: Position,
) -> Result(Game, Error) {
  use <- bool.guard(
    game.state != Ongoing,
    return: Error(error.ActionAfterGameOver),
  )

  use <- bool.guard(
    game.active_color != piece.color,
    return: Error(error.WrongColorPiece),
  )

  use LegalMove(from:, middle: _, to:, captured:) <- result.try(
    case generate_legal_moves_for_piece(game, from) {
      Ok([]) -> Error(error.NoMovesForPiece)
      Ok(moves) ->
        moves
        |> list.find(one_that: fn(move) {
          move.from == from && move.middle == middle && move.to == to
        })
        |> result.replace_error(error.IllegalMove)
      Error(e) -> Error(e)
    },
  )

  // Promotion
  let #(row, _) = position.position_to_row_col(to)
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
    |> list.fold(captured, from: _, with: fn(acc, capture_position) {
      board.set(acc, at: capture_position, to: board.Empty)
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
    let player_mappings =
      player_data.mappings
      |> dict.delete(delete: from)
      |> dict.insert(for: to, insert: piece)

    // A draw requires a player to complete 40 plies without making a capture
    // or moving a man, reset the counter otherwise.
    let player_plies_until_draw = case captured, piece {
      [], board.King(_) -> player_data.plies_until_draw - 1
      _, _ -> plies_to_draw
    }

    // remove captured pieces from opponent's mappings
    let opponent_mappings = dict.drop(opponent_data.mappings, drop: captured)

    let player_data =
      Data(mappings: player_mappings, plies_until_draw: player_plies_until_draw)
    // plies are half-moves, so they can only change for the active player
    let opponent_data =
      Data(
        mappings: opponent_mappings,
        plies_until_draw: opponent_data.plies_until_draw,
      )

    #(player_data, opponent_data)
  }

  // convert back to black-white model after transformations are done
  let #(black_data, white_data) = case game.active_color {
    board.Black -> #(player_data, opponent_data)
    board.White -> #(opponent_data, player_data)
  }

  let game =
    Game(
      ..game,
      board:,
      active_color: board.switch_color(game.active_color),
      black_data:,
      white_data:,
    )

  Game(..game, state: state(game)) |> Ok
}

//TODO: change to `PieceLegalMoves` -> #(piece, List(Move))
pub type LegalMove {
  LegalMove(
    from: Position,
    middle: List(Position),
    to: Position,
    captured: List(Position),
  )
}

/// Generates all legal moves the `active_player` can make given
/// the current state of the game
pub fn generate_legal_moves_for_player(game: Game) -> List(LegalMove) {
  let capture_builders = collect_builders(game, with: generate_capture_builders)

  case capture_builders {
    [] -> {
      let simple_builders =
        collect_builders(game, with: generate_simple_builders)

      list.map(simple_builders, fn(builder) {
        let SimpleBuilder(from:, to:) = builder
        LegalMove(from:, middle: [], to:, captured: [])
      })
    }
    capture_builders ->
      list.map(capture_builders, fn(builder) {
        let CaptureBuilder(from:, middle:, to:, captured:) = builder
        LegalMove(from:, middle:, to:, captured:)
      })
  }
}

fn collect_builders(
  game: Game,
  with collector: fn(Game, Position) -> Result(List(builder), Error),
) -> List(builder) {
  case game.active_color {
    board.Black -> game.black_data.mappings
    board.White -> game.white_data.mappings
  }
  |> dict.fold(from: [], with: fn(acc, position, _) {
    let builders = collector(game, position) |> result.unwrap([])
    list.append(acc, builders)
  })
}

//TODO: rename to `generate_legal_moves_at_position`
pub fn generate_legal_moves_for_piece(
  game: Game,
  from: Position,
) -> Result(List(LegalMove), Error) {
  let any_piece_has_available_capture =
    case game.active_color {
      board.Black -> game.black_data.mappings
      board.White -> game.white_data.mappings
    }
    |> dict.to_list()
    |> list.any(satisfying: fn(mapping) {
      let #(position, _) = mapping
      case generate_capture_builders(game, position) {
        Ok([_, ..]) -> True
        _ -> False
      }
    })

  case any_piece_has_available_capture {
    True -> {
      use builders <- result.map(generate_capture_builders(game, from))
      builders
      |> list.map(with: fn(builder) {
        let CaptureBuilder(from:, middle:, to:, captured:) = builder
        LegalMove(from:, middle:, to:, captured:)
      })
    }
    False -> {
      use builders <- result.map(generate_simple_builders(game, from))

      builders
      |> list.map(with: fn(builder) {
        let SimpleBuilder(from:, to:) = builder
        LegalMove(from:, middle: [], to:, captured: [])
      })
    }
  }
}

type SimpleBuilder {
  SimpleBuilder(from: Position, to: Position)
}

fn generate_simple_builders(
  game: Game,
  from: Position,
) -> Result(List(SimpleBuilder), Error) {
  use piece <- result.try(
    case board.get(game.board, at: from) |> board.get_piece() {
      Ok(piece) if piece.color == game.active_color -> Ok(piece)
      Ok(piece) if piece.color != game.active_color ->
        Error(error.WrongColorPiece)
      _ -> Error(error.ExpectedPieceOnSquare(position: from))
    },
  )

  let #(from_row, from_col) = position.position_to_row_col(from)
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
    use to <- result.try(position.row_col_to_position(
      from_row + row,
      from_col + col,
    ))
    case board.get(game.board, to) {
      board.Empty -> SimpleBuilder(from:, to:) |> Ok
      _ -> Error(Nil)
    }
  })
  |> Ok
}

type CaptureBuilder {
  CaptureBuilder(
    from: Position,
    middle: List(Position),
    to: Position,
    captured: List(Position),
  )
}

type CaptureSearch {
  CaptureSearch(
    game: Game,
    piece: board.Piece,
    from: Position,
    current: Position,
    path: List(Position),
    visited: Set(Position),
    captured: List(Position),
    acc: List(CaptureBuilder),
  )
}

fn generate_capture_builders(
  game: Game,
  from: Position,
) -> Result(List(CaptureBuilder), Error) {
  use piece <- result.try(
    case board.get(game.board, at: from) |> board.get_piece() {
      Ok(piece) if piece.color == game.active_color -> Ok(piece)
      Ok(piece) if piece.color != game.active_color ->
        Error(error.WrongColorPiece)
      _ -> Error(error.ExpectedPieceOnSquare(position: from))
    },
  )

  generate_capture_builders_loop(
    CaptureSearch(
      game:,
      piece:,
      from:,
      current: from,
      path: [],
      visited: set.new(),
      captured: [],
      acc: [],
    ),
  )
  |> Ok
}

fn generate_capture_builders_loop(
  capture_search: CaptureSearch,
) -> List(CaptureBuilder) {
  let CaptureSearch(
    game:,
    piece:,
    from:,
    current:,
    path:,
    visited:,
    captured:,
    acc:,
  ) = capture_search
  let #(from_row, from_col) = position.position_to_row_col(current)
  let next_positions =
    // could be moved outside to the wrapper so passing in piece isnt necessary
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

      use to <- result.try(case position.row_col_to_position(new_row, new_col) {
        Ok(to) ->
          // prevents path from visiting squares its already visited
          case set.contains(visited, to) {
            False -> Ok(to)
            True -> Error(Nil)
          }
        Error(Nil) -> Error(Nil)
      })

      // destination square must be empty in order to jump to it
      case board.get(game.board, at: to) {
        board.Empty -> {
          let capture_row = from_row + { offset_row / 2 }
          let capture_col = from_col + { offset_col / 2 }
          use capture_position <- result.try(position.row_col_to_position(
            capture_row,
            capture_col,
          ))

          case board.get(game.board, at: capture_position) {
            board.Occupied(capture_piece) if capture_piece.color != piece.color ->
              #(to, capture_position) |> Ok
            _ -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    })

  case next_positions, path, captured {
    [], [], [] -> []
    [], [to, ..rest], captured -> [
      CaptureBuilder(
        from:,
        middle: list.reverse(rest),
        to:,
        captured: list.reverse(captured),
      ),
      ..acc
    ]
    next_positions, path, captured -> {
      list.flat_map(next_positions, fn(data) {
        let #(next, capture_position) = data
        generate_capture_builders_loop(
          CaptureSearch(
            ..capture_search,
            current: next,
            path: [next, ..path],
            visited: set.insert(visited, next),
            captured: [capture_position, ..captured],
          ),
        )
      })
    }
  }
}

pub fn highlight(game: Game, moves: List(LegalMove)) -> String {
  let chunked_moves = moves |> list.chunk(by: fn(move) { move.from })

  let position_to_view =
    chunked_moves
    |> list.fold(from: [], with: fn(acc, moves) {
      // let color = int.random(16_777_215)
      let color = 0xffffff

      list.fold(moves, from: [], with: fn(acc, move) {
        let square = board.get(game.board, at: move.from)
        let from = #(
          move.from,
          square
            |> board.square_to_str()
            |> ansi.underline()
            |> ansi.italic()
            |> ansi.bright_white()
            |> Some
            |> board.SquareView(
              background: None,
              position_content: move.from
                |> position.to_int()
                |> int.to_string()
                |> ansi.hex(color)
                |> Some,
            ),
        )

        let middle =
          move.middle
          |> list.map(with: fn(position) {
            #(
              position,
              board.SquareView(
                content: None,
                background: None,
                position_content: position
                  |> position.to_int()
                  |> int.to_string()
                  |> ansi.hex(color)
                  |> Some,
              ),
            )
          })

        let to = #(
          move.to,
          board.SquareView(
            content: "★" |> ansi.pink() |> Some,
            background: None,
            position_content: move.to
              |> position.to_int()
              |> int.to_string()
              |> ansi.hex(color)
              |> Some,
          ),
        )

        let captured =
          list.map(move.captured, with: fn(position) {
            let square = board.get(game.board, at: position)
            #(
              position,
              square
                |> board.square_to_str()
                |> string.to_option()
                |> board.SquareView(background: None, position_content: None),
            )
          })

        [[from], middle, [to], captured, ..acc]
      })
      |> list.flatten()
      |> list.append(acc, _)
    })
    |> dict.from_list()

  // let overlapping_positions = case chunked_moves {
  //   [_] -> set.new()
  //   chunked_moves ->
  //     chunked_moves
  //     |> list.fold(from: set.new(), with: fn(acc, chunk) {
  //       let positions =
  //         chunk
  //         |> list.fold(from: set.new(), with: fn(acc, move) {
  //           acc
  //           |> set.insert(move.from)
  //           |> list.fold(move.middle, from: _, with: fn(acc, position) {
  //             acc |> set.insert(position)
  //           })
  //           |> set.insert(move.to)
  //         })

  //       case set.is_empty(acc) {
  //         True -> positions
  //         False -> set.intersection(acc, positions)
  //       }
  //     })
  // }

  // let position_to_view =
  //   overlapping_positions
  //   |> set.fold(from: position_to_view, with: fn(acc, position) {
  //     acc
  //     |> dict.upsert(update: position, with: fn(view) {
  //       let assert Some(view) = view
  //       case view.position_content {
  //         Some(position_content) ->
  //           board.SquareView(
  //             ..view,
  //             position_content: position_content
  //               |> ansi.strip()
  //               |> ansi.pink()
  //               |> Some,
  //           )
  //         None -> view
  //       }
  //     })
  //   })

  board.format(game.board, formatter: fn(position, square) {
    case dict.get(position_to_view, position) {
      Ok(view) -> view
      Error(Nil) ->
        square
        |> board.square_to_str()
        |> Some
        |> board.SquareView(background: None, position_content: None)
    }
  })
}
