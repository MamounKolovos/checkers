import game
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn game_over_test() {
  let assert Ok(game) = game.from_fen("B:W18:B14")
  let assert Ok(game) = game.player_move(game, "c5e3")
  assert game.is_over
}
