import action
import birdie
import board
import checkers
import error
import fen
import game
import gleam/dict
import gleam/list
import gleam/result
import gleeunit
import position

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn fen_parsing_test() {
  let assert Ok(_) =
    fen.parse(
      "B:B1,2,3,4,5,6,7,8,9,10,11,12:W21,22,23,24,25,26,27,28,29,30,31,32",
    )
  let assert Ok(_) = fen.parse("B:W6,7,14,15,23:B2")
  let assert Ok(_) = fen.parse("B:W18:B14")
  let assert Ok(_) = fen.parse("B:WK18:BK14")
  let assert Error(error.UnexpectedChar(expected: "K or 1-32", got: "0")) =
    fen.parse("B:W08:BK14")
  let assert Error(error.UnexpectedChar(expected: "1-32 or , or EOS", got: "$")) =
    fen.parse("B:W8$:BK14")
  let assert Error(error.UnexpectedChar(expected: "K or 1-32", got: "$")) =
    fen.parse("B:W$18:BK14")
  let assert Error(error.UnexpectedChar(expected: "B or W", got: "")) =
    fen.parse("")
  let assert Error(error.UnexpectedChar(expected: "B or W", got: "$")) =
    fen.parse("$:W18:B14")
  let assert Error(error.SegmentMismatch) = fen.parse("W:B18:B14")
  let assert Error(error.OutOfRange) = fen.parse("B:W99:B14")
}

pub fn action_parsing_test() {
  let assert Ok(from) = position.from_int(20)
  let assert Ok(to) = position.from_int(16)
  let assert Ok(move) = action.parse_move("a3b4")
  assert move == #(from, [], to)

  let assert Ok(from) = position.from_int(1)
  let assert Ok(middle) =
    [position.from_int(8), position.from_int(17)] |> result.all()
  let assert Ok(to) = position.from_int(26)
  let assert Ok(move) = action.parse_move("d8b6d4f2")
  assert move == #(from, middle, to)

  let assert Error(error.InvalidFile) = action.parse_move("$3b4")
  let assert Error(error.InvalidFile) = action.parse_selection("$3b4")
  let assert Error(error.InvalidRank) = action.parse_move("a$b4")
  let assert Error(error.InvalidRank) = action.parse_selection("a$b4")
  let assert Error(error.EmptyRequest) = action.parse_move("")
  let assert Error(error.EmptyRequest) = action.parse_selection("")

  let assert Error(error.IncompleteMove) = action.parse_move("a3")

  let assert Ok(position) = position.from_int(28)
  let assert Ok(selection) = action.parse_selection("a1")
  assert selection == position

  let assert Error(error.UnexpectedTrailingRequest(got: "HELLO")) =
    action.parse_selection("a1HELLO")

  // only the black squares are playable in checkers
  // all the positions below are white squares in algebraic notation
  let assert Error(error.InvalidPosition) = action.parse_selection("b1")
  let assert Error(error.InvalidPosition) = action.parse_selection("c4")
  let assert Error(error.InvalidPosition) = action.parse_selection("g2")
  let assert Error(error.InvalidPosition) = action.parse_selection("h7")
}

// pub fn piece_highlighting_test() {
//   let assert Ok(game) = game.from_fen("B:W6,7,14,15,23:B2")
//   let assert Ok(positions) = checkers.select(game, "d8")

//   birdie.snap(
//     board.highlight(game.board, positions),
//     title: "Expect all possible move paths to be highlighted",
//   )
// }

pub fn no_piece_on_square_test() {
  let game = game.create()
  let assert Error(error.ExpectedPieceOnSquare(position: _)) =
    checkers.select(game, "b4")

  let assert Ok(game) = game.from_fen("B:W18:B14")
  let assert Error(error.ExpectedPieceOnSquare(_)) = checkers.move(game, "b8a7")
}

pub fn game_over_all_captured_test() {
  let assert Ok(game) = game.from_fen("B:W18:B14")
  let assert Ok(game) = checkers.move(game, "c5e3")
  assert game.state == game.Win(board.Black)
}

pub fn game_over_no_legal_moves_test() {
  let assert Ok(game) = game.from_fen("B:B10,13,14,21,22,23,24,28:W17,32")
  let assert Ok(game) = checkers.move(game, "g3f2")
  assert game.state == game.Win(board.Black)
}

/// When a player reaches 40 plies (half-moves) without capturing or moving a man,
/// a draw must occur
pub fn game_draw_from_max_plies_test() {
  let #(
    black_king_forward,
    white_king_forward,
    black_king_backward,
    white_king_backward,
  ) = #("d6c5", "g1f2", "c5d6", "f2g1")
  // start with kings since moving a man resets the draw counter
  let assert Ok(game) = game.from_fen("B:BK10:WK32")
  let game =
    // Black plies: 0-38
    list.repeat(item: 0, times: 19)
    |> list.fold(from: game, with: fn(game, _) {
      let assert Ok(game) =
        checkers.move(game, black_king_forward)
        |> result.try(checkers.move(_, white_king_forward))
        |> result.try(checkers.move(_, black_king_backward))
        |> result.try(checkers.move(_, white_king_backward))
      game
    })
  // Black plies: 38-39
  let assert Ok(game) = checkers.move(game, black_king_forward)
  let assert Ok(game) = checkers.move(game, white_king_forward)
  // Black plies: 39-40
  let assert Ok(game) = checkers.move(game, black_king_backward)
  assert game.state == game.Draw
}

/// Resets white ply counter to ensure that draw is still reached - 
/// if black reaches 40
/// Basically ensures that plies are updated truly on a per-player basis
pub fn game_draw_from_max_plies_1_test() {
  let #(
    white_man_forward,
    black_king_forward,
    white_king_forward,
    black_king_backward,
    white_king_backward,
  ) = #("a1b2", "d6c5", "g1f2", "c5d6", "f2g1")

  let assert Ok(game) = game.from_fen("B:BK10:W29,K32")
  let game =
    // Black and white plies: 0-38
    list.repeat(item: 0, times: 19)
    |> list.fold(from: game, with: fn(game, _) {
      let assert Ok(game) =
        checkers.move(game, black_king_forward)
        |> result.try(checkers.move(_, white_king_forward))
        |> result.try(checkers.move(_, black_king_backward))
        |> result.try(checkers.move(_, white_king_backward))
      game
    })
  // Black plies: 38-39
  let assert Ok(game) = checkers.move(game, black_king_forward)
  // *RESET WHITE PLIES* by moving man
  // White plies: 38-0
  let assert Ok(game) = checkers.move(game, white_man_forward)
  // Black plies: 39-40
  let assert Ok(game) = checkers.move(game, black_king_backward)
  assert game.state == game.Draw
}

/// The most recent fen grammar spec doesn't support positions with no pieces for one of the players
/// which is why we don't test that game over case
pub fn game_over_on_fen_load_test() {
  let assert Ok(game) = game.from_fen("W:B10,13,14,23,27,28:W17,32")
  assert game.state == game.Win(board.Black)
}

pub fn move_after_game_over_test() {
  let assert Ok(game) = game.from_fen("B:W18:B14")
  let assert Ok(game) = checkers.move(game, "c5e3")
  assert game.state == game.Win(board.Black)
  let assert Error(error.ActionAfterGameOver) = checkers.move(game, "e3f2")
}

pub fn move_after_game_over_1_test() {
  let assert Ok(game) = game.from_fen("B:B10,13,14,21,22,23,24,28:W17,32")
  let assert Ok(game) = checkers.move(game, "g3f2")
  let assert Error(error.ActionAfterGameOver) = checkers.move(game, "e3f2")
  let assert Error(error.ActionAfterGameOver) = checkers.move(game, "g1f2")
}

pub fn player_cannot_move_opponents_piece_test() {
  let assert Ok(game) = game.from_fen("B:W22:B9")
  let assert Error(error.WrongColorPiece) = checkers.move(game, "c3b4")

  let assert Ok(game) = game.from_fen("W:W22:B9")
  let assert Error(error.WrongColorPiece) = checkers.move(game, "b6a5")
}

pub fn simple_move_test() {
  let game = game.create()
  let assert Ok(game) = checkers.move(game, "b6a5")
  let assert Ok(_) = checkers.move(game, "c3d4")
}

pub fn capture_move_test() {
  let assert Ok(game) = game.from_fen("B:W23,28:B18")
  assert dict.size(game.white_data.mappings) == 2
  let assert Ok(game) = checkers.move(game, "d4f2")
  assert dict.size(game.white_data.mappings) == 1
}

pub fn capture_requires_empty_destination_test() {
  let assert Ok(game) = game.from_fen("W:B18,15:W22")
  let assert Error(error.IllegalMove) = checkers.move(game, "c3e5")
}

pub fn multi_capture_move_test() {
  let assert Ok(game) = game.from_fen("B:W18,27,28:B14")
  assert dict.size(game.white_data.mappings) == 3
  let assert Ok(game) = checkers.move(game, "c5e3g1")
  assert dict.size(game.white_data.mappings) == 1
}

pub fn multi_capture_move_1_test() {
  let assert Ok(game) = game.from_fen("B:W6,7,14,15,23:B2")
  let assert Ok(_) = checkers.move(game, "d8b6d4f2")
}

/// If simple and capture moves are available, player must take a capture move
pub fn must_capture_if_available_test() {
  let assert Ok(game) = game.from_fen("B:W18,27,28:B14")
  let assert Error(error.IllegalMove) = checkers.move(game, "c5b4")
}

pub fn must_capture_if_available_1_test() {
  let assert Ok(game) = game.from_fen("B:W6,7,14,15,23:B2")
  let assert Error(error.IllegalMove) = checkers.move(game, "d8b6d4")
}

/// Ensures that the must capture rule applies for all the player's pieces,
/// not just any given one
/// 
/// If the player has 5 pieces and 2 of them can capture,
/// they can only move+capture with those two
pub fn global_must_capture_test() {
  let assert Ok(game) = game.from_fen("W:W23,28:B18")
  let assert Error(error.NoMovesForPiece) = checkers.move(game, "h2g3")
}

/// A capture move must include the full sequence when multiple captures are available.
/// 
/// Partial capture moves are invalid, even if the first jump is legal.
pub fn must_complete_capture_path_test() {
  let assert Ok(game) = game.from_fen("B:W18,27,28:B14")
  let assert Error(error.IllegalMove) = checkers.move(game, "c5e3")
}

pub fn piece_promotion_test() {
  let assert Ok(game) = game.from_fen("B:B26:W11")
  let assert Ok(game) = checkers.move(game, "d2c1")

  let assert Ok(position) = position.from_int(29)
  let assert Ok(board.King(board.Black)) =
    board.get(game.board, position) |> board.get_piece()

  let assert Ok(game) = game.from_fen("W:B26:W6")
  let assert Ok(game) = checkers.move(game, "c7d8")

  let assert Ok(position) = position.from_int(1)
  let assert Ok(board.King(board.White)) =
    board.get(game.board, position) |> board.get_piece()
}

pub fn no_moves_for_piece_test() {
  let assert Ok(game) = game.from_fen("W:B13,15,17,18:W22,27")
  let assert Error(error.NoMovesForPiece) = checkers.move(game, "c3d4")
  let assert Error(error.NoMovesForPiece) = checkers.move(game, "c3b4")
  let assert Error(error.NoMovesForPiece) = checkers.move(game, "c3e5")
  let assert Error(error.NoMovesForPiece) = checkers.move(game, "c3a5")
}

pub fn no_duplicate_positions_in_fen_test() {
  let assert Error(error.DuplicateFound) = game.from_fen("W:B18:W18")
  let assert Error(error.DuplicateFound) = game.from_fen("W:B18,18:W1")
  let assert Error(error.DuplicateFound) = game.from_fen("W:B1:W18,18")
  let assert Error(error.DuplicateFound) =
    game.from_fen("W:B1,2,3,4,5:W6,7,8,9,1")
}

pub fn legal_move_generation_test() {
  let assert Ok(game) = game.from_fen("B:B10,11:W14,15,16,22,23,24")
  let assert Ok(moves) = game.generate_legal_moves_for_player(game)

  birdie.snap(
    game.highlight(game, moves),
    title: "Expected all possible capture move paths for black to be highlighted",
  )
}

pub fn legal_move_generation_1_test() {
  let assert Ok(game) = game.from_fen("B:B1,2,3,9,10,11,17,18,19:W30")
  let assert Ok(moves) = game.generate_legal_moves_for_player(game)

  birdie.snap(
    game.highlight(game, moves),
    title: "Expected all possible simple move paths for black to be highlighted",
  )
}
