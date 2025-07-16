import board
import game.{type Game}
import gleam/io
import gleam/result
import input.{input}

pub fn play() -> Result(Nil, String) {
  let game = game.create()
  loop(game)
}

fn loop(game: Game) -> Result(Nil, String) {
  board.print(game.board)
  use request <- result.try(
    input(
      board.color_to_string(game.active_color)
      <> "'s turn, "
      <> "Enter a move: ",
    )
    |> result.replace_error("Error reading stdin"),
  )
  case request {
    "quit" | "q" | "exit" -> Ok(Nil)
    _ -> {
      case game.player_move(game, request) {
        Ok(game) -> loop(game)
        Error(e) -> {
          io.println(e)
          loop(game)
        }
      }
    }
  }
}

pub fn main() -> Nil {
  case play() {
    Ok(_) -> Nil
    Error(e) -> io.println(e)
  }
  Nil
}
