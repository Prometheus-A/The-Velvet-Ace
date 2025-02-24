use poker::models::{Card, Hand, Deck, Suits, GameMode, GameParams, Player};
use core::starknet::ContractAddress;

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
    fn initialize_game(ref self: TContractState, game_params: Option<GameParams>) -> u64;
    fn join_game(ref self: TContractState, game_id: u64);
    fn leave_game(ref self: TContractState);

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
    fn buy_chips(ref self: TContractState, no_of_chips: u256);
    fn get_dealer(self: @TContractState) -> Option<Player>;
}


// dojo decorator
#[dojo::contract]
pub mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::model::{ModelStorage, ModelValueStorage};
    use dojo::event::EventStorage;
    use dojo::world::WorldStorage;
    // use dojo::world::{WorldStorage, WorldStorageTrait};
    use poker::models::{GameId, GameMode, Game, GameParams};
    use poker::models::{GameTrait};
    use poker::models::{Player, Card, Hand, Deck, GameErrors, Game};

    pub const ID: felt252 = 'id';
    pub const MAX_NO_OF_CHIPS: u128 = 100000; /// for test, 1 chip = 10 strk.

    #[abi(embed_v0)]
    impl ActionsImpl of super::IActions<ContractState> {
        fn initialize_game(ref self: ContractState, game_params: Option<GameParams>) -> u64 {
            // Check if the player exists, if not, create a new player.
            // If caller exists, call the player_in_game function.
            // Check the game mode. each format should have different rules
            let game_id: u64 = self.generate_game_id();
            // send initialized player into this function
            // send in the initialized player
            let game: Game = GameTrait::initialize_game(Option::None, game_params, game_id);
            game_id
        }

        fn join_game(
            ref self: ContractState, game_id: u64
        ) { // init a player (check if the player exists, if not, create a new one)
        // call the internal function player_in_game
        // check the number of chips
        // for each join, check the max no. of players allowed in the game params of the game_id, if
        // reached, start the session.
        // starting the session involves changing some variables in the game and dealing cards,
        // basically initializing the game.
        }

        fn leave_game(ref self: ContractState) { // assert if the player exists
        // extract game_id
        // assert if the game exists
        // assert player.locked == true
        // Check if the player is in the game
        // Check if the player has enough chips to leave the game
        }

        fn check(ref self: ContractState) {}

        fn call(ref self: ContractState) {}

        fn fold(ref self: ContractState) {}

        fn raise(ref self: ContractState, no_of_chips: u256) {}

        fn all_in(ref self: ContractState) { //
        // deduct all available no. of chips
        }

        fn buy_chips(ref self: ContractState, no_of_chips: u256) { // use a crate here
        // a package would be made for all transactions and nfts out of this contract package.
        }

        fn get_dealer(self: @ContractState) -> Option<Player> {
            Option::None
        }
    }


    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Use the default namespace "poker". This function is handy since the ByteArray
        /// can't be const.
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"poker")
        }

        fn generate_game_id(self: @ContractState) -> u64 {
            let mut world = self.world_default();
            let mut game_id: GameId = world.read_model(ID);
            let mut id = game_id.nonce + 1;
            game_id.nonce = id;
            world.write_model(@game_id);
            id
        }

        /// This function makes all assertions on if player is meant to call this function.
        fn before_play(
            self: @ContractState, caller: ContractAddress
        ) { // Check the chips available in the player model
        // check if player is locked to a session
        // check if the player is even in the game (might have left along the way)...call the below
        // function
        }

        /// This function performs all default actions immediately a player joins the game.
        /// May call the previous function. (should not, actually)
        fn player_in_game(
            self: @ContractState, caller: ContractAddress
        ) { // Check if player is already in the game
        // Check if player is locked (already in a game), check the player struct.
        // The above two checks seem similar, but they differ in the error messages they return.
        // Check if player has enough chips to join the game
        }

        fn after_play(
            self: @ContractState, caller: ContractAddress
        ) { // check if player has more chips, prompt 'OUT OF CHIPS'
        }

        fn extract_current_game_id(self: @ContractState, player: @Player) -> u64 {
            // extract current game id from the player
            // make an assertion that the id isn't zero, 'Player not in game'
            // returns the id.
            0
        }

        fn _get_dealer(self: @ContractState, player: @Player) -> Option<Player> {
            let game_id: u64 = self.extract_current_game_id(player);

            let mut world: WorldStorage = self.world_default();
            let mut game: Game = world.read_model(game_id);
            let players: Array<Option<Player>> = game.players;

            let mut current_dealer_index: Option<u8> = Option::None;
            let mut index: u8 = 0;

            for Option::Some(player) in players {
                if player.is_dealer {
                    current_dealer_index = Option::Some(index);
                    break;
                }
                index += 1;
            };
            assert!(current_dealer_index.is_some(), "No dealer found");

            let current_index: u8 = current_dealer_index.unwrap();
            let total_players: u8 = players.len().into();
            let next_index: u8 = (current_index + 1) % total_players;

            let mut current_dealer: Player = (*players.at(current_index.into())).unwrap();
            current_dealer.is_dealer = false;

            let mut next_dealer: Player = (*players.at(next_index.into())).unwrap();
            next_dealer.is_dealer = true;

            world.write_model(@game);

            Option::Some(current_dealer)
        }

        fn _deal_hands(ref players: Array<Player>) { // deal hands for each player in the array
        }

        fn _resolve_hands(
            ref players: Array<Player>
        ) { // after each round, resolve all players hands by removing all cards from each hand
        // and perhaps re-initialize and shuffle the deck.
        }
    }
}
