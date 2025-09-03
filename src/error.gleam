import gleam/int
import position.{type Position}

pub type Error {
  Todo
  FailedToReadStdin
  WrongColorPiece
  ExpectedPieceOnSquare(position: Position)

  IllegalMove
  NoMovesForPiece

  SegmentMismatch
  OutOfRange
  DuplicateFound
  UnexpectedChar(expected: String, got: String)

  InvalidFile
  InvalidRank
  InvalidPosition
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
    ExpectedPieceOnSquare(position:) ->
      "Expected a piece on the square at position: "
      <> { position |> position.to_int() |> int.to_string() }
    IllegalMove -> "Illegal move: must make a legal move"
    NoMovesForPiece -> "No moves available for selected piece"
    SegmentMismatch -> "Expected one white segment and one black segment"
    OutOfRange -> "Square number out of range"
    DuplicateFound -> "Duplicate found in fen string"
    UnexpectedChar(expected:, got:) -> "Expected " <> expected <> ", " <> got
    InvalidFile -> "Invalid file: must be a-h"
    InvalidRank -> "Invalid rank: must be 1-8"
    InvalidPosition -> "Invalid position: only black squares are playable"
    EmptyRequest -> "Empty path: please enter one"
    UnexpectedTrailingRequest(got:) ->
      "Unexpected trailing request, got " <> got
    IncompleteMove -> "Incomplete move: please fill it out"
    ActionAfterGameOver ->
      "Player tried to take an action after the game has ended"
  }
}
