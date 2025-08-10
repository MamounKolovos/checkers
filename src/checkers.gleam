import board
import error
import game.{type Game}
import gleam/io
import gleam/result
import input.{input}

pub fn play() -> Nil {
  let game = game.create()
  board.print(game.board)
  let _ = loop(game)
  Nil
}

fn loop(game: Game) -> Result(Nil, error.Error) {
  use request <- result.try(
    game.active_color
    |> prompt()
    |> input()
    |> result.replace_error(error.FailedToReadStdin),
  )
  case request {
    "quit" | "q" | "exit" -> Ok(Nil)
    _ ->
      case game.move(game, request) {
        Ok(game) if game.is_over -> {
          io.println(board.color_to_string(game.active_color) <> " Wins!")
          Ok(Nil)
        }
        Ok(game) -> {
          board.print(game.board)
          loop(game)
        }
        Error(e) -> {
          error.GameError(e) |> error.to_string() |> io.println_error()
          loop(game)
        }
      }
  }
}

fn prompt(active_color: board.Color) -> String {
  board.color_to_string(active_color) <> "'s turn, Enter a move: "
}

//TODO: Mandatory capture
//TODO: piece promotion
pub fn main() -> Nil {
  play()
}
