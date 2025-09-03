import action
import board
import error.{type Error}
import game.{type Game}
import gleam/bool
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import input.{input}
import position.{type Position}

pub fn main() -> Nil {
  play()
}

fn play() -> Nil {
  let model = init()
  display(model)
  loop(model)
}

/// Application loop
/// 
/// The basic flow is:
/// get user input -> update model -> display updated model to user
fn loop(model: Model) -> Nil {
  let assert Ok(request) = input("")

  let msg = case request {
    "q" | "quit" | "exit" -> UserEnteredQuit
    "move" <> rest -> {
      let path = string.trim_start(rest)
      UserEnteredMove(path:)
    }
    "select" <> rest -> {
      let position_string = string.trim_start(rest)
      UserEnteredSelection(position_string:)
    }
    _ -> panic as "unsupported command"
  }

  let model = update(model, msg)

  display(model)

  case model.game.state {
    game.Ongoing -> loop(model)
    _ -> Nil
  }
}

/// Application's state
pub type Model {
  Model(
    game: Game,
    // any error that could've occurred during the game that needs to be displayed
    error: Option(Error),
    highlighted_squares: Option(List(Position)),
    is_over: Bool,
  )
}

pub fn init() -> Model {
  Model(
    game: game.create(),
    error: None,
    highlighted_squares: None,
    is_over: False,
  )
}

/// The way the user interacts with the model
/// 
/// For a CLI app, sent exclusively from terminal input
pub type Msg {
  //todo: new game
  //todo: add some type of player forfeited message
  UserEnteredQuit
  UserEnteredMove(path: String)
  UserEnteredSelection(position_string: String)
}

pub fn update(model: Model, msg: Msg) -> Model {
  case msg {
    UserEnteredMove(path:) ->
      case move(model.game, path) {
        Ok(game) -> Model(..model, game:, error: None)
        Error(e) -> Model(..model, error: Some(e))
      }
    UserEnteredSelection(position_string:) ->
      case select(model.game, position_string) {
        Ok(highlighted_squares) ->
          Model(
            ..model,
            highlighted_squares: Some(highlighted_squares),
            error: None,
          )
        Error(e) -> Model(..model, error: Some(e))
      }
    UserEnteredQuit -> Model(..model, is_over: True)
  }
}

/// Gets all possible move paths that a piece at the `position_string` could take
/// 
/// Paths returned as a flat list of positions because that's all the UI needs
/// in order to highlight them
pub fn select(
  game: Game,
  position_string: String,
) -> Result(List(Position), Error) {
  use <- bool.guard(
    game.state != game.Ongoing,
    return: Error(error.ActionAfterGameOver),
  )
  use position <- result.try(action.parse_selection(position_string))

  use piece <- result.try(
    case board.get(game.board, at: position) |> board.get_piece() {
      Ok(piece) if piece.color == game.active_color -> Ok(piece)
      Ok(piece) if piece.color != game.active_color ->
        Error(error.WrongColorPiece)
      _ -> Error(error.ExpectedPieceOnSquare(position:))
    },
  )

  case game.generate_legal_moves_for_piece(game, piece, position) {
    Ok(moves) ->
      //position order is irrelevant
      moves |> list.flat_map(fn(move) { [move.to, ..move.middle] }) |> Ok
    Error(e) -> Error(e)
  }
}

/// Wrapper around `game.move`
/// 
/// Main responsibility is getting the piece the player wants to move
/// \+ its movement path from the `path` string
pub fn move(game: Game, path: String) -> Result(Game, Error) {
  use <- bool.guard(
    game.state != game.Ongoing,
    return: Error(error.ActionAfterGameOver),
  )
  use #(from, middle, to) <- result.try(action.parse_move(path))

  use piece <- result.try(
    case board.get(game.board, at: from) |> board.get_piece() {
      Ok(piece) if piece.color == game.active_color -> Ok(piece)
      Ok(piece) if piece.color != game.active_color ->
        Error(error.WrongColorPiece)
      _ -> Error(error.ExpectedPieceOnSquare(position: from))
    },
  )

  game.move(game, piece, from, middle, to)
}

/// String representation of the model
pub fn view(model: Model) -> String {
  let board_string = case model.highlighted_squares {
    None -> board.to_string(model.game.board)
    Some(highlighted_squares) ->
      board.highlight(model.game.board, highlighted_squares)
  }
  let error_string = case model.error {
    Some(e) -> error.to_string(e)
    None -> ""
  }

  let prompt_string = case model.game.state {
    game.Ongoing -> prompt(model.game.active_color)

    // Don't need to prompt user for further actions if game is over
    game.Win(winner) -> board.color_to_string(winner) <> " Wins!"
    game.Draw -> "Draw!"
  }

  board_string <> "\n" <> error_string <> "\n" <> prompt_string <> "\n"
}

const esc = "\u{001b}"

fn display(model: Model) -> Nil {
  // Resets terminal cursor so the new board paints over the old one
  io.print(esc <> "[2J" <> esc <> "[H")
  model |> view() |> io.println()
}

fn prompt(active_color: board.Color) -> String {
  board.color_to_string(active_color)
  <> "'s turn, Options: \n"
  <> "\n"
  <> "  - Select piece\n"
  <> "  - Move piece\n"
}
