use poker::models::game::{Game, GameParams};
use poker::models::card::Card;
use poker::models::hand::Hand;
use poker::models::player::Player;
use poker::models::deck::Deck;
use starknet::ContractAddress;
use poker::traits::game::get_default_game_params;


/// TODO: Read the GameREADME.md file to understand the rules of coding this game.
/// TODO: What should happen when everyone leaves the game? Well, the pot should be
/// transferred to the last player. May be reconsidered.
///
/// TODO: for each function that requires

/// Interface functions for each action of the smart contract
#[starknet::interface]
trait IActions<TContractState> {
    /// Initializes the game with a game format. Returns a unique game id.
    /// game_params as Option::None initializes a default game.
    ///
    /// TODO: Might require a function that lets and admin eject a player
    fn initialize_game(ref self: TContractState, game_params: Option<GameParams>) -> u64;
    fn join_game(ref self: TContractState, game_id: u64);
    fn leave_game(ref self: TContractState);
    fn end_game(ref self: TContractState, game_id: u64, force: bool);

    /// ********************************* NOTE *************************************************
    ///
    ///                             TODO: NOTE
    /// These functions must require that the caller is already in a game.
    /// When calling all_in, for other raises, create a separate pot.
    fn check(ref self: TContractState);
    fn call(ref self: TContractState);
    fn fold(ref self: TContractState);
    fn raise(ref self: TContractState, no_of_chips: u256);
    fn all_in(ref self: TContractState);
    fn buy_in(ref self: TContractState, no_of_chips: u256); // will call
    fn get_dealer(self: @TContractState) -> Option<Player>;
    // remove
    fn get_rank(self: @TContractState, player_id: ContractAddress) -> ByteArray;
    // to be called by the dealer, for now.
    fn deal_community_card(ref self: TContractState, card: Card, game_id: u256);
    fn showdown(
        ref self: TContractState,
        game_id: u64,
        hands: Array<Hand>,
        game_proofs: Array<Array<felt252>>,
        dealt_card_proofs: Array<Array<felt252>>,
        deck: Deck,
        game_salt: Array<felt252>,
        dealt_card_salt: Array<felt252>,
    );

    /// All functions here might be extracted into a separate contract
    fn get_player(self: @TContractState, player_id: ContractAddress) -> Player;
    fn get_game(self: @TContractState, game_id: u64) -> Game;
    fn set_alias(self: @TContractState, alias: felt252);
    fn resolve_round(ref self: TContractState, game_id: u64);

    /// Submits a player's cards with proofs for verification
    ///
    /// # Arguments
    /// * `cards` - Array of cards being submitted by the player
    /// * `deck_proof` - Merkle proof for the deck state
    /// * `dealt_cards_proof` - Merkle proof for the dealt cards state
    /// * `staked_amount` - Amount of chips staked for this submission
    fn submit_card(
        ref self: TContractState,
        cards: Array<Card>,
        deck_proof: Array<felt252>,
        dealt_cards_proof: Array<felt252>,
        staked_amount: u256,
    );
}
