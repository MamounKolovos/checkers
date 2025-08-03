import board
import game.{type Game}
import gleam/io
import gleam/result
import input.{input}

pub fn play() -> Result(Nil, String) {
  let game = game.create()
  board.print(game.board)
  loop(game)
}

fn loop(game: Game) -> Result(Nil, String) {
  use request <- result.try(
    game.active_color
    |> prompt()
    |> input()
    |> result.replace_error("Error reading stdin"),
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
          io.println(e)
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
  case play() {
    Ok(_) -> Nil
    Error(e) -> io.println(e)
  }
  Nil
}
