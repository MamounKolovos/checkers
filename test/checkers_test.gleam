import board
import fen
import game
import gleam/dict
import gleam/result
import gleeunit
import raw_move

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
  let assert Error(fen.UnexpectedChar(expected: "K or 1-32", got: "0")) =
    fen.parse("B:W08:BK14")
  let assert Error(fen.UnexpectedChar(expected: "1-32 or , or EOS", got: "$")) =
    fen.parse("B:W8$:BK14")
  let assert Error(fen.UnexpectedChar(expected: "K or 1-32", got: "$")) =
    fen.parse("B:W$18:BK14")
  let assert Error(fen.UnexpectedChar(expected: "B or W", got: "")) =
    fen.parse("")
  let assert Error(fen.UnexpectedChar(expected: "B or W", got: "$")) =
    fen.parse("$:W18:B14")
  let assert Error(fen.SegmentMismatch) = fen.parse("W:B18:B14")
  let assert Error(fen.OutOfRange) = fen.parse("B:W99:B14")
}

pub fn raw_move_parsing_test() {
  let assert Ok(raw_move) = raw_move.parse("a3b4")
  let assert Ok(from) = board.from_int(20)
  let assert Ok(to) = board.from_int(16)
  assert raw_move.parts(raw_move) == #(from, [], to)

  let assert Ok(from) = board.from_int(1)
  let assert Ok(middle) =
    [board.from_int(8), board.from_int(17)] |> result.all()
  let assert Ok(to) = board.from_int(26)
  let assert Ok(raw_move) = raw_move.parse("d8b6d4f2")
  assert raw_move.parts(raw_move) == #(from, middle, to)

  let assert Error(raw_move.InvalidFile) = raw_move.parse("$3b4")
  let assert Error(raw_move.InvalidRank) = raw_move.parse("a$b4")
  let assert Error(raw_move.EmptyPath) = raw_move.parse("")
  let assert Error(raw_move.MissingDestination) = raw_move.parse("a3")
}

pub fn no_piece_at_start_test() {
  let assert Ok(game) = game.from_fen("B:W18:B14")
  let assert Ok(raw_move) = raw_move.parse("b8a7")
  let assert Error(game.NoPieceAtStart) = game.from_raw(game, raw_move)
}

pub fn game_over_all_captured_test() {
  let assert Ok(game) = game.from_fen("B:W18:B14")
  let assert Ok(game) = game.move(game, "c5e3")
  assert game.is_over && game.active_color == board.Black
}

pub fn game_over_no_legal_moves_test() {
  let assert Ok(game) = game.from_fen("B:B10,13,14,23,24,28:W17,32")
  let assert Ok(game) = game.move(game, "g3f2")
  assert game.is_over && game.active_color == board.Black
}

pub fn move_after_game_over_test() {
  let assert Ok(game) = game.from_fen("B:W18:B14")
  let assert Ok(game) = game.move(game, "c5e3")
  assert game.is_over && game.active_color == board.Black
  let assert Error(game.MoveAfterGameOver) = game.move(game, "e3f2")
}

pub fn simple_move_test() {
  let game = game.create()
  let assert Ok(game) = game.move(game, "b6a5")
  let assert Ok(_) = game.move(game, "c3d4")
}

pub fn capture_move_test() {
  let assert Ok(game) = game.from_fen("B:W23,28:B18")
  assert dict.size(game.white_squares) == 2
  let assert Ok(game) = game.move(game, "d4f2")
  assert dict.size(game.white_squares) == 1
}

pub fn capture_requires_empty_destination_test() {
  let assert Ok(game) = game.from_fen("W:B18,15:W22")
  let assert Error(game.InvalidSimpleMove) = game.move(game, "c3e5")
}

pub fn multi_capture_move_test() {
  let assert Ok(game) = game.from_fen("B:W18,27,28:B14")
  assert dict.size(game.white_squares) == 3
  let assert Ok(game) = game.move(game, "c5e3g1")
  assert dict.size(game.white_squares) == 1
}

pub fn multi_capture_move_1_test() {
  let assert Ok(game) = game.from_fen("B:W6,7,14,15,23:B2")
  let assert Ok(_) = game.move(game, "d8b6d4f2")
}

/// If simple and capture moves are available, player must take a capture move
pub fn must_capture_if_available_test() {
  let assert Ok(game) = game.from_fen("B:W18,27,28:B14")
  let assert Error(game.InvalidCaptureMove) = game.move(game, "c5b4")
}

pub fn must_capture_if_available_1_test() {
  let assert Ok(game) = game.from_fen("B:W6,7,14,15,23:B2")
  let assert Error(game.InvalidCaptureMove) = game.move(game, "d8b6d4")
}

/// A capture move must include the full sequence when multiple captures are available.
/// 
/// Partial capture moves are invalid, even if the first jump is legal.
pub fn must_complete_capture_path_test() {
  let assert Ok(game) = game.from_fen("B:W18,27,28:B14")
  let assert Error(game.InvalidCaptureMove) = game.move(game, "c5e3")
}

pub fn piece_promotion_test() {
  let assert Ok(game) = game.from_fen("B:B26:W11")
  let assert Ok(game) = game.move(game, "d2c1")

  let assert Ok(index) = board.from_int(29)
  let assert Ok(board.King(board.Black)) =
    board.get(game.board, index) |> board.get_piece()

  let assert Ok(game) = game.from_fen("W:B26:W6")
  let assert Ok(game) = game.move(game, "c7d8")

  let assert Ok(index) = board.from_int(1)
  let assert Ok(board.King(board.White)) =
    board.get(game.board, index) |> board.get_piece()
}

pub fn no_moves_for_piece_test() {
  let assert Ok(game) = game.from_fen("W:B13,15,17,18:W22")
  let assert Error(game.NoMovesForPiece) = game.move(game, "c3d4")
  let assert Error(game.NoMovesForPiece) = game.move(game, "c3b5")
  let assert Error(game.NoMovesForPiece) = game.move(game, "c3e5")
  let assert Error(game.NoMovesForPiece) = game.move(game, "c3a5")
}

pub fn no_duplicate_positions_in_fen_test() {
  let assert Error(game.FenError(fen.DuplicateFound)) =
    game.from_fen("W:B18:W18")
  let assert Error(game.FenError(fen.DuplicateFound)) =
    game.from_fen("W:B18,18:W1")
  let assert Error(game.FenError(fen.DuplicateFound)) =
    game.from_fen("W:B1:W18,18")
  let assert Error(game.FenError(fen.DuplicateFound)) =
    game.from_fen("W:B1,2,3,4,5:W6,7,8,9,1")
}
