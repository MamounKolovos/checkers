import action
import birdie
import board
import error.{type Error}
import fen
import game.{type Game}
import gleam/bool
import gleam/dict
import gleam/list
import gleam/result
import gleeunit

fn move(game: Game, request: String) -> Result(Game, Error) {
  use <- bool.guard(
    game.state != game.Ongoing,
    return: Error(error.ActionAfterGameOver),
  )
  use action <- result.try(action.parse(request))

  use piece <- result.try(
    case board.get(game.board, at: action.from) |> board.get_piece() {
      Ok(piece) if piece.color == game.active_color -> Ok(piece)
      Ok(piece) if piece.color != game.active_color ->
        Error(error.WrongColorPiece)
      _ -> Error(error.NoPieceAtStart)
    },
  )

  case action {
    action.Move(from:, middle:, to:) -> game.move(game, piece, from, middle, to)
    action.Select(from: _) ->
      Error(error.UnexpectedAction(expected: "Move", got: "Select"))
  }
}

fn select(game: Game, request: String) -> Result(List(board.BoardIndex), Error) {
  use <- bool.guard(
    game.state != game.Ongoing,
    return: Error(error.ActionAfterGameOver),
  )
  use action <- result.try(action.parse(request))

  use piece <- result.try(
    case board.get(game.board, at: action.from) |> board.get_piece() {
      Ok(piece) if piece.color == game.active_color -> Ok(piece)
      Ok(piece) if piece.color != game.active_color ->
        Error(error.WrongColorPiece)
      _ -> Error(error.NoPieceAtStart)
    },
  )

  case action {
    action.Select(from:) ->
      game.generate_legal_moves(game.board, piece, from)
      //index order is irrelevant
      |> list.flat_map(fn(move) { [move.to, ..move.middle] })
      |> Ok
    action.Move(from: _, middle: _, to: _) ->
      Error(error.UnexpectedAction(expected: "Select", got: "Move"))
  }
}

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
  let assert Ok(from) = board.from_int(20)
  let assert Ok(to) = board.from_int(16)
  let assert Ok(action) = action.parse("a3b4")
  assert action == action.Move(from:, middle: [], to:)

  let assert Ok(from) = board.from_int(1)
  let assert Ok(middle) =
    [board.from_int(8), board.from_int(17)] |> result.all()
  let assert Ok(to) = board.from_int(26)
  let assert Ok(action) = action.parse("d8b6d4f2")
  assert action == action.Move(from:, middle:, to:)

  let assert Error(error.InvalidFile) = action.parse("$3b4")
  let assert Error(error.InvalidRank) = action.parse("a$b4")
  let assert Error(error.EmptyPath) = action.parse("")
  // let assert Error(action.MissingDestination) = action.parse("a3")
}

pub fn piece_highlighting_test() {
  let assert Ok(game) = game.from_fen("B:W6,7,14,15,23:B2")
  let assert Ok(indexes) = select(game, "d8")

  birdie.snap(
    board.highlight(game.board, indexes),
    title: "Expect all possible move paths to be highlighted",
  )
}

pub fn no_piece_at_start_test() {
  let assert Ok(game) = game.from_fen("B:W18:B14")
  let assert Error(error.NoPieceAtStart) = move(game, "b8a7")
}

pub fn game_over_all_captured_test() {
  let assert Ok(game) = game.from_fen("B:W18:B14")
  let assert Ok(game) = move(game, "c5e3")
  assert game.state == game.Win(board.Black)
}

pub fn game_over_no_legal_moves_test() {
  let assert Ok(game) = game.from_fen("B:B10,13,14,23,24,28:W17,32")
  let assert Ok(game) = move(game, "g3f2")
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
      let assert Ok(game) = move(game, black_king_forward)
      let assert Ok(game) = move(game, white_king_forward)
      let assert Ok(game) = move(game, black_king_backward)
      let assert Ok(game) = move(game, white_king_backward)
      game
    })
  // Black plies: 38-39
  let assert Ok(game) = move(game, black_king_forward)
  let assert Ok(game) = move(game, white_king_forward)
  // Black plies: 39-40
  let assert Ok(game) = move(game, black_king_backward)
  assert game.state == game.Draw
}

/// Resets white ply counter to ensure that draw is still reached - 
/// if black reaches 40
/// Basically ensures that plies are updated truly on a per-player basis
pub fn game_draw_from_max_plies_test1() {
  let #(
    black_king_forward,
    white_man_forward,
    white_king_forward,
    black_king_backward,
    white_king_backward,
  ) = #("d6c5", "c3b4", "g1f2", "c5d6", "f2g1")

  let assert Ok(game) = game.from_fen("B:BK10:W14,K32")
  let game =
    // Black and white plies: 0-38
    list.repeat(item: 0, times: 10)
    |> list.fold(from: game, with: fn(game, _) {
      let assert Ok(game) =
        move(game, black_king_forward)
        |> result.try(move(_, white_king_forward))
        |> result.try(move(_, black_king_backward))
        |> result.try(move(_, white_king_backward))
      game
    })
  // Black plies: 38-39
  let assert Ok(game) = move(game, black_king_forward)
  // *RESET WHITE PLIES* by moving man
  // White plies: 38-0
  let assert Ok(game) = move(game, white_man_forward)
  // Black plies: 39-40
  let assert Ok(game) = move(game, black_king_backward)
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
  let assert Ok(game) = move(game, "c5e3")
  assert game.state == game.Win(board.Black)
  let assert Error(error.ActionAfterGameOver) = move(game, "e3f2")
}

pub fn move_after_game_over_test1() {
  let assert Ok(game) = game.from_fen("B:B10,13,14,23,24,28:W17,32")
  let assert Ok(game) = move(game, "g3f2")
  let assert Error(error.ActionAfterGameOver) = move(game, "e3f2")
  let assert Error(error.ActionAfterGameOver) = move(game, "g1f2")
}

pub fn player_cannot_move_opponents_piece_test() {
  let assert Ok(game) = game.from_fen("B:W22:B9")
  let assert Error(error.WrongColorPiece) = move(game, "c3b4")

  let assert Ok(game) = game.from_fen("W:W22:B9")
  let assert Error(error.WrongColorPiece) = move(game, "b6a5")
}

pub fn simple_move_test() {
  let game = game.create()
  let assert Ok(game) = move(game, "b6a5")
  let assert Ok(_) = move(game, "c3d4")
}

pub fn capture_move_test() {
  let assert Ok(game) = game.from_fen("B:W23,28:B18")
  assert dict.size(game.white_data.mappings) == 2
  let assert Ok(game) = move(game, "d4f2")
  assert dict.size(game.white_data.mappings) == 1
}

pub fn capture_requires_empty_destination_test() {
  let assert Ok(game) = game.from_fen("W:B18,15:W22")
  let assert Error(error.InvalidSimpleMove) = move(game, "c3e5")
}

pub fn multi_capture_move_test() {
  let assert Ok(game) = game.from_fen("B:W18,27,28:B14")
  assert dict.size(game.white_data.mappings) == 3
  let assert Ok(game) = move(game, "c5e3g1")
  assert dict.size(game.white_data.mappings) == 1
}

pub fn multi_capture_move_1_test() {
  let assert Ok(game) = game.from_fen("B:W6,7,14,15,23:B2")
  let assert Ok(_) = move(game, "d8b6d4f2")
}

/// If simple and capture moves are available, player must take a capture move
pub fn must_capture_if_available_test() {
  let assert Ok(game) = game.from_fen("B:W18,27,28:B14")
  let assert Error(error.InvalidCaptureMove) = move(game, "c5b4")
}

pub fn must_capture_if_available_1_test() {
  let assert Ok(game) = game.from_fen("B:W6,7,14,15,23:B2")
  let assert Error(error.InvalidCaptureMove) = move(game, "d8b6d4")
}

/// A capture move must include the full sequence when multiple captures are available.
/// 
/// Partial capture moves are invalid, even if the first jump is legal.
pub fn must_complete_capture_path_test() {
  let assert Ok(game) = game.from_fen("B:W18,27,28:B14")
  let assert Error(error.InvalidCaptureMove) = move(game, "c5e3")
}

pub fn piece_promotion_test() {
  let assert Ok(game) = game.from_fen("B:B26:W11")
  let assert Ok(game) = move(game, "d2c1")

  let assert Ok(index) = board.from_int(29)
  let assert Ok(board.King(board.Black)) =
    board.get(game.board, index) |> board.get_piece()

  let assert Ok(game) = game.from_fen("W:B26:W6")
  let assert Ok(game) = move(game, "c7d8")

  let assert Ok(index) = board.from_int(1)
  let assert Ok(board.King(board.White)) =
    board.get(game.board, index) |> board.get_piece()
}

pub fn no_moves_for_piece_test() {
  let assert Ok(game) = game.from_fen("W:B13,15,17,18:W22,27")
  let assert Error(error.NoMovesForPiece) = move(game, "c3d4")
  let assert Error(error.NoMovesForPiece) = move(game, "c3b5")
  let assert Error(error.NoMovesForPiece) = move(game, "c3e5")
  let assert Error(error.NoMovesForPiece) = move(game, "c3a5")
}

pub fn no_duplicate_positions_in_fen_test() {
  let assert Error(error.DuplicateFound) = game.from_fen("W:B18:W18")
  let assert Error(error.DuplicateFound) = game.from_fen("W:B18,18:W1")
  let assert Error(error.DuplicateFound) = game.from_fen("W:B1:W18,18")
  let assert Error(error.DuplicateFound) =
    game.from_fen("W:B1,2,3,4,5:W6,7,8,9,1")
}
