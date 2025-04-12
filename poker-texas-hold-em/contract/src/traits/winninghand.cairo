use poker::models::hand::{Hand, HandRank};
use poker::models::card::Card;
use poker::models::game::GameParams;
use poker::models::player::Player;
use poker::models::game::Game;
use super::handtrait::HandTrait;

pub trait WinningHandTrait {
    /// Determines the winning hand(s) from a set of player hands in a game.
    ///
    /// This function evaluates all valid hands from players who are `in_round == true` and belong
    /// to the same game. It uses `HandTrait::compare_hands` internally for pairwise hand comparison
    /// logic and returns an array of winning hands.
    ///
    /// # Arguments
    /// * `hands` - An array of hands to evaluate.
    /// * `community_cards` - The community cards to combine with player hands.
    /// * `game_params` - The game parameters for evaluating hands.
    ///
    /// # Returns
    /// An array of winning hands representing the best hand(s) in the game.
    fn determine_winning_hands(
        hands: Array<Hand>,
        community_cards: Array<Card>,
        game_params: GameParams,
    ) -> Array<Hand>;
}

impl WinningHandTrait for Game {
    fn determine_winning_hands(
        hands: Array<Hand>,
        community_cards: Array<Card>,
        game_params: GameParams,
    ) -> Array<Hand> {
        // Filter hands to include only those from players who are in the round and in the same game
        let valid_hands: Array<Hand> = hands
            .iter()
            .filter(|hand| hand.player.in_round && hand.player.game_id == self.id)
            .collect();

        // Use HandTrait::compare_hands to find the best hands
        let hand_instance = Hand {}; // Create an instance of Hand
        let (winning_hands, _rank, _kicker_cards) =
            hand_instance.compare_hands(valid_hands, community_cards, game_params);
        winning_hands
    }
}