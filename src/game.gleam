import board.{type Board}
import error.{type Error}
import fen
import gleam/bool
import gleam/dict
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
    black_plies_until_draw: Int,
    white_plies_until_draw: Int,
  )
}

const plies_to_draw = 40

//TODO: make opaque
//TODO: add forfeit
pub type GameState {
  Win(board.Color)
  Draw
  Ongoing
}

/// A type-safe wrapper around an occupied square on the board.
/// 
/// The wrapper binds the square to a specific game instance. Ownership
/// can only be acquired through the smart constructor, which ensures
/// the piece belongs to the active player.
pub opaque type OwnedSquare {
  OwnedSquare(game: Game, position: Position, piece: board.Piece)
}

/// Smart constructor that checks the square is occupied **and** that the
/// piece belongs to the active player before granting ownership
pub fn new_owned_square(
  game: Game,
  position: Position,
) -> Result(OwnedSquare, Error) {
  case board.get(game.board, at: position) {
    board.Occupied(piece) if piece.color == game.active_color -> {
      OwnedSquare(game:, piece:, position:) |> Ok
    }
    board.Occupied(piece) if piece.color != game.active_color ->
      Error(error.WrongColorPiece)
    _ -> Error(error.ExpectedPieceOnSquare(position:))
  }
}

/// Takes ownership of all squares occupied by the active player's pieces
pub fn take_ownership_of_occupied_squares(game: Game) -> List(OwnedSquare) {
  list.range(0, 31)
  |> list.fold(from: [], with: fn(acc, i) {
    let assert Ok(position) = position.from_int(i)
    case new_owned_square(game, position) {
      Ok(owned_square) -> [owned_square, ..acc]
      _ -> acc
    }
  })
}

/// Opponent just moved, determine state from the perspective of the new active player
fn state(game: Game) -> GameState {
  let opponent_plies_until_draw = case game.active_color {
    board.Black -> game.white_plies_until_draw
    board.White -> game.black_plies_until_draw
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
          black_plies_until_draw: plies_to_draw,
          white_plies_until_draw: plies_to_draw,
        )

      Game(..game, state: state(game)) |> Ok
    }
    Error(e) -> Error(e)
  }
}

pub fn move(game: Game, move: LegalMove) -> Game {
  use <- bool.guard(game.state != Ongoing, return: game)

  let LegalMove(piece:, from:, middle: _, to:, captured:) = move

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

  // A draw requires a player to complete 40 plies without making a capture
  // or moving a man, reset the counter otherwise.
  let update_plies = fn(plies) {
    case captured, piece {
      [], board.King(_) -> plies - 1
      _, _ -> plies
    }
  }

  let #(black_plies_until_draw, white_plies_until_draw) = case
    game.active_color
  {
    board.Black -> #(
      update_plies(game.black_plies_until_draw),
      game.white_plies_until_draw,
    )

    board.White -> #(
      game.black_plies_until_draw,
      update_plies(game.white_plies_until_draw),
    )
  }

  let game =
    Game(
      ..game,
      board:,
      active_color: board.switch_color(game.active_color),
      black_plies_until_draw:,
      white_plies_until_draw:,
    )

  Game(..game, state: state(game))
}

//TODO: change to `PieceLegalMoves` -> #(piece, List(Move))
pub type LegalMove {
  LegalMove(
    piece: board.Piece,
    from: Position,
    middle: List(Position),
    to: Position,
    captured: List(Position),
  )
}

/// Generates all legal moves the `active_player` can make given
/// the current state of the game
pub fn generate_legal_moves_for_player(game: Game) -> List(LegalMove) {
  let owned_squares = take_ownership_of_occupied_squares(game)

  let capture_builders =
    owned_squares
    |> list.flat_map(with: fn(owned_square) {
      let builders = generate_capture_builders(owned_square)

      builders
      |> list.map(with: fn(builder) {
        LegalMove(
          piece: owned_square.piece,
          from: owned_square.position,
          middle: builder.middle,
          to: builder.to,
          captured: builder.captured,
        )
      })
    })

  case capture_builders {
    [] -> {
      owned_squares
      |> list.flat_map(with: fn(owned_square) {
        let builders = generate_simple_builders(owned_square)

        builders
        |> list.map(with: fn(builder) {
          LegalMove(
            piece: owned_square.piece,
            from: owned_square.position,
            middle: [],
            to: builder.to,
            captured: [],
          )
        })
      })
    }
    capture_builders -> capture_builders
  }
}

pub fn generate_legal_moves_at_position(
  owned_square: OwnedSquare,
) -> List(LegalMove) {
  let owned_squares = take_ownership_of_occupied_squares(owned_square.game)

  let any_piece_has_available_capture =
    owned_squares
    |> list.any(satisfying: fn(owned_square) {
      case generate_capture_builders(owned_square) {
        [_, ..] -> True
        _ -> False
      }
    })

  case any_piece_has_available_capture {
    True -> {
      generate_capture_builders(owned_square)
      |> list.map(with: fn(builder) {
        let CaptureBuilder(middle:, to:, captured:) = builder
        LegalMove(
          piece: owned_square.piece,
          from: owned_square.position,
          middle:,
          to:,
          captured:,
        )
      })
    }
    False -> {
      generate_simple_builders(owned_square)
      |> list.map(with: fn(builder) {
        let SimpleBuilder(to:) = builder
        LegalMove(
          piece: owned_square.piece,
          from: owned_square.position,
          middle: [],
          to:,
          captured: [],
        )
      })
    }
  }
}

pub fn create_legal_move(
  game: Game,
  from: Position,
  middle: List(Position),
  to: Position,
) -> Result(LegalMove, Error) {
  use owned_square <- result.try(new_owned_square(game, from))

  case generate_legal_moves_at_position(owned_square) {
    [] -> Error(error.NoMovesForPiece)
    moves ->
      moves
      |> list.find(one_that: fn(move) {
        move.from == from && move.middle == middle && move.to == to
      })
      |> result.replace_error(error.IllegalMove)
  }
}

type SimpleBuilder {
  SimpleBuilder(to: Position)
}

fn generate_simple_builders(owned_square: OwnedSquare) -> List(SimpleBuilder) {
  let OwnedSquare(game:, position:, piece:) = owned_square

  let #(from_row, from_col) = position.position_to_row_col(position)
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
      board.Empty -> SimpleBuilder(to:) |> Ok
      _ -> Error(Nil)
    }
  })
}

type CaptureBuilder {
  CaptureBuilder(middle: List(Position), to: Position, captured: List(Position))
}

type CaptureSearch {
  CaptureSearch(
    game: Game,
    piece: board.Piece,
    current: Position,
    path: List(Position),
    visited: Set(Position),
    captured: List(Position),
    acc: List(CaptureBuilder),
  )
}

fn generate_capture_builders(owned_square: OwnedSquare) -> List(CaptureBuilder) {
  let OwnedSquare(game:, position:, piece:) = owned_square

  generate_capture_builders_loop(
    CaptureSearch(
      game:,
      piece:,
      current: position,
      path: [],
      visited: set.new(),
      captured: [],
      acc: [],
    ),
  )
}

fn generate_capture_builders_loop(
  capture_search: CaptureSearch,
) -> List(CaptureBuilder) {
  let CaptureSearch(game:, piece:, current:, path:, visited:, captured:, acc:) =
    capture_search
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
