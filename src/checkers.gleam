import action
import board
import error.{type Error}
import game.{type Game}
import gleam/bool
import gleam/io
import gleam/list
import gleam/result
import input.{input}

pub fn play() -> Nil {
  let game = game.create()
  board.print(game.board)
  let _ = loop(game)
  Nil
}

type ActionResult {
  Continue(Game)
  Stop
}

fn loop(game: Game) -> Result(Nil, error.Error) {
  use request <- result.try(
    game.active_color
    |> prompt()
    |> input()
    |> result.replace_error(error.FailedToReadStdin),
  )

  case handle_request(game, request) {
    Ok(#(result, message)) -> {
      io.println(message)
      case result {
        Continue(game) -> loop(game)
        Stop -> Ok(Nil)
      }
    }
    Error(e) -> {
      e |> error.to_string() |> io.println_error()
      loop(game)
    }
  }
}

fn handle_request(
  game: Game,
  request: String,
) -> Result(#(ActionResult, String), Error) {
  use <- bool.guard(is_quit(request), return: #(Stop, "Player quit") |> Ok)

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
    action.Move(from:, middle:, to:) ->
      case game.move(game, piece, from, middle, to) {
        Ok(game) ->
          case game.state {
            game.Win(winner) -> {
              #(Stop, board.color_to_string(winner) <> " Wins!") |> Ok
            }
            game.Draw -> {
              #(Stop, "Draw!") |> Ok
            }
            game.Ongoing -> {
              #(Continue(game), board.to_string(game.board)) |> Ok
            }
          }
        Error(e) -> Error(e)
      }
    action.Select(from:) -> {
      let indexes =
        game.generate_legal_moves(game.board, piece, from)
        //index order is irrelevant
        |> list.flat_map(fn(move) { [move.to, ..move.middle] })
      #(Continue(game), board.highlight(game.board, indexes)) |> Ok
    }
  }
}

fn is_quit(request: String) -> Bool {
  case request {
    "quit" | "q" | "exit" -> True
    _ -> False
  }
}

fn prompt(active_color: board.Color) -> String {
  board.color_to_string(active_color)
  <> "'s turn, Options: \n"
  <> "\n"
  <> "  - Select piece\n"
  <> "  - Move piece\n"
  <> "\n"
}

pub fn main() -> Nil {
  play()
}
