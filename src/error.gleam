import fen
import game
import raw_move

pub type Error {
  Todo
  FailedToReadStdin
  GameError(game.Error)
}

pub fn to_string(error: Error) -> String {
  case error {
    Todo -> "Todo: replace with actual error"
    FailedToReadStdin -> "Error reading stdin"
    GameError(error) -> game_error_to_string(error)
  }
}

fn game_error_to_string(error: game.Error) -> String {
  case error {
    game.NoPieceAtStart -> "No piece at starting position"
    game.InvalidSimpleMove -> "Invalid simple move"
    game.InvalidCaptureMove -> "Invalid capture move"
    game.FenError(error) -> fen_error_to_string(error)
    game.RawMoveError(error) -> raw_move_error_to_string(error)
  }
}

fn fen_error_to_string(error: fen.Error) -> String {
  case error {
    fen.SegmentMismatch -> "Expected one white segment and one black segment"
    fen.OutOfRange -> "Square number out of range"
    fen.UnexpectedChar(expected:, got:) ->
      "Expected " <> expected <> ", " <> got
  }
}

fn raw_move_error_to_string(error: raw_move.Error) -> String {
  case error {
    raw_move.InvalidFile -> "Invalid file: must be a-h"
    raw_move.InvalidRank -> "Invalid rank: must be 1-8"
    raw_move.EmptyPath -> "Empty path: please enter one"
    raw_move.MissingDestination -> "Missing destination: please enter one"
  }
}
