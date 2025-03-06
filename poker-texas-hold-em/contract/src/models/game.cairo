use starknet::ContractAddress;
use super::card::Card;
use poker::traits::game::GameTrait;

/// CashGame. same as the `true` value for the Tournament. CashGame should allow incoming players...
/// may be refactored in the future.
/// Tournament. for Buying back-in after a certain period of time (can be removed),
/// false for Elimination when chips are out.
#[derive(Copy, Drop, Serde, Default, Introspect, PartialEq)]
pub enum GameMode {
    #[default]
    CashGame,
    Tournament: bool,
}

/// The kicker_split is checked when comparing hands.
#[derive(Copy, Drop, Serde, Default, Introspect, PartialEq)]
pub struct GameParams {
    game_mode: GameMode,
    max_no_of_players: u8,
    small_blind: u64,
    big_blind: u64,
    no_of_decks: u8,
    kicker_split: bool,
    min_amount_of_chips: u256,
}

/// id - the game id
/// in_progress - boolean if the game is in progress or not
/// has_ended - if the game has ended. Note that the difference between this and the former is
/// to check for "init" and "waiting". A game is initialized, and waiting for players, but the game
/// is not in progress yet. for waiting, check the has_ended and the in_progress.
///
/// current_round - stores the current round of the game for future operations
/// round_in_progress - set to true and false, when a round starts and when it ends respectively
/// this is to assert that any incoming player of a default game doesn't join when a round is in
/// progress
///
/// players - The players in the current game
/// deck - the decks in the game (id, referenced to the deck model)
/// next_player - the next player to take a turn
/// community - cards - the available community cards in the game
/// pot - the pot returning the pot size
/// params - the gameparams used to initialize the game.
#[derive(Drop, Default, Serde)]
#[dojo::model]
pub struct Game {
    #[key]
    id: u64,
    in_progress: bool,
    has_ended: bool,
    current_round: u8,
    round_in_progress: bool,
    players: Array<ContractAddress>,
    deck: Array<u64>,
    next_player: Option<ContractAddress>,
    community_cards: Array<Card>,
    pot: u256,
    params: GameParams,
}
