import board
import game.{type Game}
import gleam/dict
import gleam/int

const win_reward = 999_999

const lose_reward = -999_999

const draw_reward = 0

// --- HELPERS

/// Applies the given function to every element in the list and returns
/// the element that produced the highest value
fn argmax(in elements: List(a), with fun: fn(a) -> Int) -> Result(a, Nil) {
  case elements {
    [] -> Error(Nil)
    [a] -> Ok(a)
    [a, ..rest] -> Ok(argmax_loop(rest, fun, fun(a), a))
  }
}

fn argmax_loop(elements: List(a), fun: fn(a) -> Int, max: Int, best: a) -> a {
  case elements {
    [] -> best
    [a, ..rest] ->
      case fun(a) {
        value if value > max -> argmax_loop(rest, fun, value, a)
        _ -> argmax_loop(rest, fun, max, best)
      }
  }
}

// ---

/// Finds the best legal move for the current player by looking ahead at possible
/// sequences of moves up to the specified `depth` (Recommended depth to start out with is 6)
///
/// The search is represented as a tree, so depth is the distance from the root node to the leaves
///
/// The general search algorithm is as follows:
/// 1. We generate all legal moves for the player
/// 2. Simulate each move
/// 3. Evaluate the move with negascout down to the specified depth
/// 4. Pick the move that scored the highest
pub fn search(game: Game, depth: Int) -> Result(game.LegalMove, Nil) {
  game.generate_legal_moves_for_player(game)
  |> argmax(with: fn(move) {
    let assert board.Occupied(piece) = board.get(game.board, at: move.from)
    let assert Ok(game) =
      game.move(game, piece, move.from, move.middle, move.to)
    negascout(game, depth)
  })
}

/// Negascout is a variant of negamax that uses
/// alpha-beta pruning with a null window to optimize the search.
/// 
/// It works by simulating all possible sequences of moves and choosing
/// the one that maximizes the player's minimum guaranteed outcome
fn negascout(game: Game, depth: Int) -> Int {
  // At the start of the algorithm, no traversal has occurred yet.
  // Therefore, the maximizer can only be guaranteed the worst possible score,
  // and the minimizer can only be guaranteed the best possible score.
  negascout_loop(
    game:,
    maximizer_lower_bound: lose_reward,
    minimizer_upper_bound: win_reward,
    depth:,
  )
}

/// `alpha` is the lower bound of the score that the maximizing player
/// can guarantee so far.
///
/// Example: If one move evaluates to +5, then `alpha = 5` because the
/// maximizer knows they can always choose that move and achieve at least 5.
///
/// `beta` is the upper bound of the score that the minimizing player
/// can guarantee so far.
///
/// Example: If one move evaluates to -3, then `beta = -3` because the
/// minimizer knows they can always choose that move and hold the score
/// to at most -3.
fn negascout_loop(
  game game: Game,
  maximizer_lower_bound alpha: Int,
  minimizer_upper_bound beta: Int,
  depth depth: Int,
) -> Int {
  case game.state {
    // If the game has been won, that means the winner made the last move.
    // Therefore, the current player is the loser and will be awarded the `lose_reward`
    game.Win(_) -> lose_reward
    // Equally good/bad for both players, unconditionally return `draw_reward`
    game.Draw -> draw_reward
    game.Ongoing ->
      case depth {
        // leaf node reached, evaluate game based on current player
        0 -> evaluate(game)
        // still going down the tree, continue recursing
        depth ->
          evaluate_moves(
            game,
            game.generate_legal_moves_for_player(game),
            alpha,
            beta,
            depth,
            True,
          )
      }
  }
}

/// Evaluates every legal move a player can make at a given game state
/// and returns the highest possible score that a move can generate for the maximizing player
fn evaluate_moves(
  game: Game,
  moves: List(game.LegalMove),
  alpha: Int,
  beta: Int,
  depth: Int,
  is_first_move: Bool,
) -> Int {
  case moves {
    // all moves evaluated, return the highest score that can be guaranteed
    [] -> alpha
    [move, ..rest] -> {
      // a piece should always exist at the start of a legal move, will fix later
      let assert board.Occupied(piece) = board.get(game.board, at: move.from)
      let assert Ok(new_game) =
        game.move(game, piece, move.from, move.middle, move.to)

      let score = case is_first_move {
        // First move in the list, search with a full alpha-beta window
        // We do this because we don't have a baseline score yet since
        // alpha is set by the moves.
        // Without a full window search, we could miss the *true* best move
        True ->
          negascout_loop(
            new_game,
            maximizer_lower_bound: int.negate(beta),
            minimizer_upper_bound: int.negate(alpha),
            depth: depth - 1,
          )
          |> int.negate()
        False -> {
          // For every move other than the first, we search with a null window:
          // (alpha to alpha+1)
          // We do this because most moves are unlikely to improve on the current best score (alpha)
          // so a null-window search can quickly prove this without having to do a full search
          let score =
            negascout_loop(
              new_game,
              maximizer_lower_bound: int.negate(alpha) - 1,
              minimizer_upper_bound: int.negate(alpha),
              depth: depth - 1,
            )
            |> int.negate()

          // If the null window search returns a score such that alpha < score < beta,
          // There's a chance that the move might actually be better than the current best move.
          // This is because null window search can underestimate the score so we have no choice
          // but to search with a full window to 100% know the real score
          //
          // Example (3 < 5 < 7): if the best score so far is 3 (alpha) and the theoretical
          // maximum achievable score is 7 (beta), a null-window search returning 5
          // indicates this move might improve on our current best. We then perform
          // a full-window search to determine the true score and see if we can get
          // closer to the maximum (beta).

          case alpha < score && score < beta {
            True ->
              negascout_loop(
                new_game,
                maximizer_lower_bound: int.negate(beta),
                minimizer_upper_bound: int.negate(alpha),
                depth: depth - 1,
              )
              |> int.negate()
            False -> score
          }
        }
      }

      // best move's score vs current move's score
      let alpha = int.max(alpha, score)

      // if alpha >= beta, we have reached the best possible alpha and no
      // remaining moves can improve the score.
      //
      // Remember that alpha is the best score the maximizer can guarantee
      // and beta is the best score the minimizer can allow.
      //
      // So alpha being larger than beta means that the minimizer will
      // never allow the maximizer to get a better score than alpha
      case alpha >= beta {
        True -> alpha
        False -> evaluate_moves(game, rest, alpha, beta, depth, False)
      }
    }
  }
}

/// Evaluates the game from the perspective of the active player using a simple heuristic
/// 
/// The current heuristic is based on the difference in piece counts between players
/// 
/// TODO: might add weighting for kings in the future
pub fn evaluate(game: Game) -> Int {
  let #(black_mappings, white_mappings) = #(
    game.black_data.mappings,
    game.white_data.mappings,
  )

  let black_piece_count = dict.size(black_mappings)
  let white_piece_count = dict.size(white_mappings)

  let multiplier = case game.active_color {
    board.Black -> 1
    board.White -> -1
  }

  let piece_advantage = black_piece_count - white_piece_count
  multiplier * piece_advantage
}
