pub type Error {
  Todo
  FailedToReadStdin
  WrongColorPiece
  NoPieceAtStart

  InvalidSimpleMove
  InvalidCaptureMove
  NoMovesForPiece

  SegmentMismatch
  OutOfRange
  DuplicateFound
  UnexpectedChar(expected: String, got: String)

  InvalidFile
  InvalidRank
  EmptyRequest
  UnexpectedTrailingRequest(got: String)
  IncompleteMove
  ActionAfterGameOver
}

pub fn to_string(error: Error) -> String {
  case error {
    Todo -> "Todo: replace with actual error"
    FailedToReadStdin -> "Error reading stdin"
    WrongColorPiece -> "Player tried to interact with opponent's piece"
    NoPieceAtStart -> "No piece at starting position"
    InvalidSimpleMove ->
      "Invalid move: must choose from the available simple moves"
    InvalidCaptureMove ->
      "Invalid move: must choose from the available capture moves"
    NoMovesForPiece -> "No moves available for selected piece"
    SegmentMismatch -> "Expected one white segment and one black segment"
    OutOfRange -> "Square number out of range"
    DuplicateFound -> "Duplicate found in fen string"
    UnexpectedChar(expected:, got:) -> "Expected " <> expected <> ", " <> got
    InvalidFile -> "Invalid file: must be a-h"
    InvalidRank -> "Invalid rank: must be 1-8"
    EmptyRequest -> "Empty path: please enter one"
    UnexpectedTrailingRequest(got:) ->
      "Unexpected trailing request, got " <> got
    IncompleteMove -> "Incomplete move: please fill it out"
    ActionAfterGameOver ->
      "Player tried to take an action after the game has ended"
  }
}
