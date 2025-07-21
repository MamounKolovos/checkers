import board.{Black}
import game
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn game_over_test() {
  let assert Ok(game) = game.from_fen("B:W18:B14")
  let assert Ok(game) = game.move(game, "c5e3")
  assert game.is_over && game.active_color == Black
}

pub fn simple_move_test() {
  let game = game.create()
  let assert Ok(game) = game.move(game, "b6a5")
  let assert Ok(_) = game.move(game, "c3d4")
}

pub fn capture_move_test() {
  let assert Ok(game) = game.from_fen("B:W23,28:B18")
  let assert Ok(game) = game.move(game, "d4f2")
  assert game.white_count == 1
}

pub fn multi_capture_move_test() {
  let assert Ok(game) = game.from_fen("B:W18,27,28:B14")
  let assert Ok(game) = game.move(game, "c5e3g1")
  assert game.white_count == 1
}
