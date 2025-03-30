use poker::models::game::{Game, GameParams};
use poker::models::player::Player;
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
fn buy_chips(ref self: TContractState, no_of_chips: u256); // will call
fn get_dealer(self: @TContractState) -> Option<Player>;


/// All functions here might be extracted into a separate contract
fn get_player(self: @TContractState, player_id: ContractAddress) -> Player;
fn get_game(self: @ContractState, game_id: u64) -> Game;
fn set_alias(self: @TContractState, alias: felt252);
}


// dojo decorator
#[dojo::contract]
pub mod actions {
use starknet::{ContractAddress, get_caller_address};
use dojo::model::{ModelStorage, ModelValueStorage};
use dojo::event::EventStorage;
// use dojo::world::{WorldStorage, WorldStorageTrait};

use poker::models::base::{
    GameErrors, Id, GameInitialized, CardDealt, HandCreated, HandResolved,
    PlayerJoined, PlayerLeft, RoundResolved, BoughtChip, GameStarted
};
use poker::models::card::{Card, CardTrait};
use poker::models::deck::{Deck, DeckTrait};
use poker::models::game::{Game, GameMode, GameParams, GameTrait};
use poker::models::hand::{Hand, HandTrait};
use poker::models::player::{Player, PlayerTrait, get_default_player};
use poker::traits::game::get_default_game_params;

pub const GAME: felt252 = 'GAME';
pub const DECK: felt252 = 'DECK';
pub const MAX_NO_OF_CHIPS: u128 = 100000; /// for test, 1 chip = 1 usd.


#[abi(embed_v0)]
impl ActionsImpl of super::IActions<ContractState> {
    fn initialize_game(ref self: ContractState, game_params: Option<GameParams>) -> u64 {
        // Get the caller address
        let caller: ContractAddress = get_caller_address();
        let mut world = self.world_default();
        let mut player: Player = world.read_model(caller);

        // Ensure the player is not already in a game
        let (is_locked, _) = player.locked;
        assert(!is_locked, GameErrors::PLAYER_ALREADY_LOCKED);

        let game_id: u64 = self.generate_id(GAME);

        let mut deck_ids: Array<u64> = array![self.generate_id(DECK)];
        if let Option::Some(params) = game_params {
            // say the maximum number of decks is 10.
            let deck_len = params.no_of_decks;
            assert(deck_len > 0 && deck_len <= 10, GameErrors::INVALID_GAME_PARAMS);
            for _ in 0..deck_len - 1 {
                deck_ids.append(self.generate_id(DECK));
            };
        }

        // Create new game
        let mut game: Game = Default::default();
        let decks = game.init(game_params, game_id, deck_ids);

        player.enter(ref game);
        // Save updated player and game state
        world.write_model(@player);
        world.write_model(@game);

        // Save available decks
        for deck in decks {
            world.write_model(@deck);
        };

        world
            .emit_event(
                @GameInitialized {
                    game_id: game_id,
                    player: caller,
                    game_params: game.params,
                    time_stamp: starknet::get_block_timestamp(),
                },
            );

        // extracted default GameParams from traits::game
        // let default_param = get_default_game_params();

        // match game_params {
        //     Option::Some(value) => {
        //     world.emit_event(@GameInitialized {
        //         game_id: game_id,
        //         player: caller,
        //         game_params: value,
        //     })},
        //     Option::None => world.emit_event(@GameInitialized{
        //         game_id: game_id,
        //         player: caller,
        //         game_params: default_param,
        //     }),
        // };

        game_id
    }

    // @LaGodxy
    fn join_game(
        ref self: ContractState, game_id: u64,
    ) { 
        // Get player and game data
        let (caller, mut world, mut player, mut game) = self._get_player_and_game(game_id);
        
        // Ensure the game exists
        assert(game.id == game_id, GameErrors::GAME_NOT_FOUND);
        
        // Check if the game has ended
        assert(!game.has_ended, GameErrors::GAME_ALREADY_ENDED);
        
        // Ensure player is not already in a game
        let (is_locked, _) = player.locked;
        assert(!is_locked, GameErrors::PLAYER_ALREADY_LOCKED);
        
        // Check if the game is full
        let current_players = game.players.len();
        assert(
            current_players < game.params.max_no_of_players, 
            GameErrors::GAME_FULL
        );
        
        // Check if player has enough chips to join
        assert(
            player.chips >= game.params.min_amount_of_chips,
            GameErrors::PLAYER_OUT_OF_CHIPS
        );
        
        // Add player to the game
        player.enter(ref game);
        
        // Save updated player and game state
        world.write_model(@player);
        world.write_model(@game);
        
        // Emit player joined event
        self._emit_event(
            @PlayerJoined {
                game_id,
                player: caller,
                time_stamp: starknet::get_block_timestamp(),
            },
            ref world
        );
        
        // Check if the game should start (max players reached)
        if game.players.len() == game.params.max_no_of_players && !game.in_progress {
            // Start the game
            game.in_progress = true;
            
            // Deal cards to all players
            let mut players_array = self._get_active_players(ref world, ref game);
            
            self._deal_hands(ref players_array);
            
            // Update game state
            world.write_model(@game);
            
            // Emit game started event
            self._emit_event(
                @GameStarted {
                    game_id,
                    players: game.players,
                    time_stamp: starknet::get_block_timestamp(),
                },
                ref world
            );
        }
    }

    // @LaGodxy
    fn leave_game(ref self: ContractState) { 
        // Get the caller address and world storage
        let caller: ContractAddress = get_caller_address();
        let mut world = self.world_default();
        
        // Get player data
        let mut player: Player = world.read_model(caller);
        
        // Ensure player is in a game
        let (is_locked, game_id) = player.locked;
        assert(is_locked, GameErrors::PLAYER_NOT_IN_GAME);
        
        // Get game data
        let mut game: Game = world.read_model(game_id);
        
        // Ensure the game exists
        assert(game.id == game_id, GameErrors::GAME_NOT_FOUND);
        
        // Remove player from the game
        player.exit(ref game);
        
        // Check if this was the last player
        if game.players.is_empty() {
            // End the game if no players left
            game.has_ended = true;
        } else if player.is_dealer {
            // If the leaving player was the dealer, assign a new dealer
            let _ = self._get_dealer(@player);
        }
        
        // Save updated player and game state
        world.write_model(@player);
        world.write_model(@game);
        
        // Emit player left event
        self._emit_event(
            @PlayerLeft {
                game_id,
                player: caller,
                time_stamp: starknet::get_block_timestamp(),
            },
            ref world
        );
    }

    // @LaGodxy
    fn check(ref self: ContractState) {
        // Get the caller address
        let caller: ContractAddress = get_caller_address();
        
        // Perform pre-play validations
        self.before_play(caller);
        
        let mut world = self.world_default();
        let mut player: Player = world.read_model(caller);
        let (_, game_id) = player.locked;
        let mut game: Game = world.read_model(game_id);
        
        // Ensure it's the player's turn
        assert(game.current_player == caller, GameErrors::NOT_PLAYER_TURN);
        
        // Ensure the current bet is 0 or equal to player's current bet
        assert(
            game.current_bet == 0 || game.current_bet == player.current_bet,
            GameErrors::CANNOT_CHECK
        );
        
        // Mark player as having acted this round
        player.has_acted = true;
        
        // Update player and game state
        world.write_model(@player);
        
        // Perform post-play actions
        self.after_play(caller);
    }

    // @LaGodxy
    fn call(ref self: ContractState) {
        // Get the caller and validate
        let caller = get_caller_address();
        self.before_play(caller);
        
        // Get game state
        let (mut world, mut player, mut game) = self._get_player_game_state(caller);
        
        // Calculate the amount to call
        let call_amount = game.current_bet - player.current_bet;
        
        // Ensure player has enough chips
        assert(player.chips >= call_amount, GameErrors::PLAYER_OUT_OF_CHIPS);
        
        // Update player's chips and current bet
        player.chips -= call_amount;
        player.current_bet = game.current_bet;
        player.has_acted = true;
        
        // Add to the pot
        game.pot += call_amount;
        
        // Update player and game state
        world.write_model(@player);
        world.write_model(@game);
        
        // Perform post-play actions
        self.after_play(caller);
    }

    // @LaGodxy
    fn fold(ref self: ContractState) {
        // Get the caller and validate
        let caller = get_caller_address();
        self.before_play(caller);
        
        // Get game state
        let (mut world, mut player, mut game) = self._get_player_game_state(caller);
        
        // Mark player as folded and not in round
        player.has_folded = true;
        player.in_round = false;
        player.has_acted = true;
        
        // Update player state
        world.write_model(@player);
        
        // Check if only one player remains in the round
        let (active_players, last_active_player) = self._count_active_players(ref world, ref game);
        
        if active_players == 1 {
            // Award pot to the last remaining player
            let mut winner: Player = world.read_model(last_active_player);
            winner.chips += game.pot;
            game.pot = 0;
            
            // Reset for next round
            self._resolve_round(game.id);
            
            // Update winner state
            world.write_model(@winner);
        } else {
            // Perform post-play actions
            self.after_play(caller);
        }
    }

    // @LaGodxy
    fn raise(ref self: ContractState, no_of_chips: u256) {
        // Get the caller and validate
        let caller = get_caller_address();
        self.before_play(caller);
        
        // Get game state
        let (mut world, mut player, mut game) = self._get_player_game_state(caller);
        
        // Calculate the total amount needed (call amount + raise)
        let call_amount = game.current_bet - player.current_bet;
        let total_amount = call_amount + no_of_chips;
        
        // Ensure player has enough chips
        assert(player.chips >= total_amount, GameErrors::PLAYER_OUT_OF_CHIPS);
        
        // Ensure the raise is at least the minimum raise
        assert(
            no_of_chips >= game.params.min_raise_amount, 
            GameErrors::RAISE_TOO_SMALL
        );
        
        // Update player's chips and current bet
        player.chips -= total_amount;
        player.current_bet = game.current_bet + no_of_chips;
        player.has_acted = true;
        
        // Update game's current bet and pot
        game.current_bet = player.current_bet;
        game.pot += total_amount;
        
        // Reset has_acted for all other players since they need to respond to the raise
        self._reset_player_actions(ref world, ref game, caller);
        
        // Update player and game state
        world.write_model(@player);
        world.write_model(@game);
        
        // Perform post-play actions
        self.after_play(caller);
    }

    // @LaGodxy
    fn all_in(ref self: ContractState) {
        // Get the caller and validate
        let caller = get_caller_address();
        self.before_play(caller);
        
        // Get game state
        let (mut world, mut player, mut game) = self._get_player_game_state(caller);
        
        // Get player's available chips
        let available_chips = player.chips;
        assert(available_chips > 0, GameErrors::PLAYER_OUT_OF_CHIPS);
        
        // Create a side pot if necessary
        if player.current_bet + available_chips < game.current_bet {
            // Player can't match the current bet, create a side pot
            game.side_pots.append((player.id, player.current_bet + available_chips));
        } else if player.current_bet + available_chips > game.current_bet {
            // Player is raising with all-in, update current bet
            game.current_bet = player.current_bet + available_chips;
            
            // Reset has_acted for all other players
            self._reset_player_actions(ref world, ref game, caller);
        }
        
        // Update player's state
        player.current_bet += available_chips;
        player.chips = 0;
        player.is_all_in = true;
        player.has_acted = true;
        
        // Add to the pot
        game.pot += available_chips;
        
        // Update player and game state
        world.write_model(@player);
        world.write_model(@game);
        
        // Perform post-play actions
        self.after_play(caller);
    }

    // @LaGodxy
    fn buy_chips(ref self: ContractState, no_of_chips: u256) {
        // Get the caller address
        let caller: ContractAddress = get_caller_address();
        let mut world = self.world_default();
        
        // Ensure the requested amount is valid
        assert(no_of_chips > 0, 'INVALID_CHIP_AMOUNT');
        assert(no_of_chips <= MAX_NO_OF_CHIPS.into(), 'EXCEEDS_MAX_CHIPS');
        
        // Get player data
        let mut player: Player = world.read_model(caller);
        
        // Add chips to player's balance
        player.chips += no_of_chips;
        
        // Save updated player state
        world.write_model(@player);
        
        // Emit bought chip event
        let (is_locked, game_id) = player.locked;
        self._emit_event(
            @BoughtChip {
                game_id: if is_locked { game_id } else { 0 },
                player: caller,
                no_of_chips,
                time_stamp: starknet::get_block_timestamp(),
            },
            ref world
        );
    }

    // @LaGodxy
    fn get_dealer(self: @ContractState) -> Option<Player> {
        let caller: ContractAddress = get_caller_address();
        let world = self.world_default();
        let player: Player = world.read_model(caller);
        
        // Ensure player is in a game
        let (is_locked, _) = player.locked;
        if !is_locked {
            return Option::None;
        }
        
        self._get_dealer(@player)
    }

    fn get_player(self: @ContractState, player_id: ContractAddress) -> Player {
        let world = self.world_default();
        world.read_model(player_id)
    }

    fn get_game(self: @ContractState, game_id: u64) -> Game {
        let world = self.world_default();
        world.read_model(game_id)
    }

    fn set_alias(self: @ContractState, alias: felt252) {
        let caller: ContractAddress = get_caller_address();
        assert(caller.is_non_zero(), 'ZERO CALLER');
        let mut world = self.world_default();
        let mut player: Player = world.read_model(caller);
        let check: Player = world.read_model(alias.clone());
        assert(check.id.is_zero(), 'ALIAS UPDATE FAILED');
        player.alias = alias;
fn after_play(ref self: ContractState, caller: ContractAddress) {
    //@Reentrancy
    let mut world = self.world_default();
    let mut player: Player = world.read_model(caller);
    let (is_locked, game_id) = player.locked;

    // Ensure the player is in a game
    assert(is_locked, 'Player not in game');

    let mut game: Game = world.read_model(game_id);

    // Check if all community cards are dealt (5 cards in Texas Hold'em)
    if game.community_cards.len() == 5 {
        return self._resolve_round(game_id);
    }

    // Find the caller's index in the players array
    let current_index_option: Option<usize> = self.find_player_index(@game.players, caller);
    assert(current_index_option.is_some(), 'Caller not in game');
    let current_index: usize = OptionTrait::unwrap(current_index_option);

    // Update game state with the player's action
    if player.current_bet > game.current_bet {
        game.current_bet = player.current_bet; // Raise updates the current bet
    }

    world.write_model(@player); // Ensure player state is written

    // Determine the next active player or resolve the round
    let next_player_option: Option<ContractAddress> = self
        .find_next_active_player(@game.players, current_index, @world);

    if next_player_option.is_none() {
        // No active players remain, resolve the round
        self._resolve_round(game_id);
    } else {
        game.next_player = next_player_option;
    }

    world.write_model(@game);
}

fn find_player_index(
    self: @ContractState, players: @Array<ContractAddress>, player_address: ContractAddress,
) -> Option<usize> {
    let mut i = 0;
    let mut result: Option<usize> = Option::None;
    while i < players.len() {
        if *players.at(i) == player_address {
            result = Option::Some(i);
            break;
        }
        i += 1;
    };
    result
}


        fn find_next_active_player(
            self: @ContractState,
            players: @Array<ContractAddress>,
            current_index: usize,
            world: @dojo::world::WorldStorage,
        ) -> Option<ContractAddress> {
            let num_players = players.len();
            let mut next_index = (current_index + 1) % num_players;
            let mut attempts = 0;
            let mut result: Option<ContractAddress> = Option::None;

            while attempts < num_players {
                let player_address = *players.at(next_index);
                let p: Player = world.read_model(player_address);
                let (is_locked, _) = p
                    .locked; // Adjusted to check locked status instead of is_in_game
                if is_locked && p.in_round {
                    result = Option::Some(player_address);
                    break;
                }
                next_index = (next_index + 1) % num_players;
                attempts += 1;
            };
            result
        }

#[generate_trait]
impl InternalImpl of InternalTrait {
    /// Use the default namespace "poker". This function is handy since the ByteArray
    /// can't be const.
    fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
        self.world(@"poker")
    }

    fn generate_id(self: @ContractState, target: felt252) -> u64 {
        let mut world = self.world_default();
        let mut game_id: Id = world.read_model(target);
        let mut id = game_id.nonce + 1;
        game_id.nonce = id;
        world.write_model(@game_id);
        id
    }

    // @LaGodxy
    /// This function makes all assertions on if player is meant to call this function.
    fn before_play(
        self: @ContractState, caller: ContractAddress,
    ) {
        let world: dojo::world::WorldStorage = self.world_default();
        let player: Player = world.read_model(caller);
        
        // Ensure player exists
        assert(player.id.is_non_zero(), GameErrors::PLAYER_NOT_FOUND);
        
        // Check if player is locked to a game
        let (is_locked, game_id) = player.locked;
        assert(is_locked, GameErrors::PLAYER_NOT_IN_GAME);
        
        // Get game data
        let game: Game = world.read_model(game_id);
        
        // Ensure game exists and is in progress
        assert(game.id == game_id, GameErrors::GAME_NOT_FOUND);
        assert(game.in_progress, GameErrors::GAME_NOT_STARTED);
        assert(!game.has_ended, GameErrors::GAME_ALREADY_ENDED);
        
        // Check if player is in the round
        assert(player.in_round, GameErrors::PLAYER_NOT_IN_ROUND);
        
        // Check if player has folded
        assert(!player.has_folded, GameErrors::PLAYER_FOLDED);
        
        // Check if player is all-in
        assert(!player.is_all_in, GameErrors::PLAYER_ALL_IN);
        
        // Check if it's player's turn
        assert(game.current_player == caller, GameErrors::NOT_PLAYER_TURN);
        
        // Check if player has enough chips
        assert(player.chips > 0, GameErrors::PLAYER_OUT_OF_CHIPS);
    }

    // @LaGodxy
    /// This function performs all default actions immediately a player joins the game.
    /// May call the previous function. (should not, actually)
    fn player_in_game(
        self: @ContractState, caller: ContractAddress,
    ) {
        let world: dojo::world::WorldStorage = self.world_default();
        let player: Player = world.read_model(caller);
        let (is_locked, game_id) = player.locked;
        let game: Game = world.read_model(game_id);

        // Player can't be locked and not in a game
        // true is serialized as 1 => a non existing player can't be locked
        assert(is_locked, GameErrors::PLAYER_NOT_IN_GAME);
        assert(
            player.chips >= game.params.min_amount_of_chips, GameErrors::PLAYER_OUT_OF_CHIPS,
        );
    }

    // @LaGodxy
    fn after_play(
        self: @ContractState, caller: ContractAddress,
    ) {
        let mut world = self.world_default();
        let player: Player = world.read_model(caller);
        let (_, game_id) = player.locked;
        let mut game: Game = world.read_model(game_id);
        
        // Check if all active players have acted
        let (all_acted, next_player) = self._check_player_actions(ref world, ref game);
        
        // If all players have acted
        if all_acted {
            // Deal community cards or resolve the round
            let community_cards_len = game.community_cards.len();
            
            if community_cards_len < 5 {
                // Deal next community card(s)
                self._deal_community_card(ref game);
                
                // Reset player actions for the next betting round
                self._reset_all_player_actions(ref world, ref game);
                
                // Set the first active player as current
                game.current_player = self._get_first_active_player(ref world, ref game);
            } else {
                // All community cards dealt, resolve the round
                self._resolve_round(game_id);
                return;
            }
        } else {
            // Set the next player
            game.current_player = next_player;
        }
        
        // Update game state
        world.write_model(@game);
    }


    fn _get_dealer(self: @ContractState, player: @Player) -> Option<Player> {
        let mut world = self.world_default();
        let game_id: u64 = *player.extract_current_game_id();
        let game: Game = world.read_model(game_id);
        let players: Array<ContractAddress> = game.players;
        let num_players: usize = players.len();

        // Find the index of the current dealer
        let mut current_dealer_index: usize = 0;
        let mut found: bool = false;

        let mut i: usize = 0;
        while i < num_players {
            let player_address: ContractAddress = *players.at(i);
            let player_data: Player = world.read_model(player_address);

            if player_data.is_dealer {
                current_dealer_index = i;
                found = true;
                break;
            }
            i += 1;
        };

        // If no dealer is found, return None
        if !found {
            return Option::None;
        };

        // Calculate the index of the next dealer
        let mut next_dealer_index: usize = (current_dealer_index + 1) % num_players;
        // save initial dealer index to prevent infinite loop
        let mut initial_dealer_index: usize = current_dealer_index;

        let result = loop {
            // Get the address of the next dealer
            let next_dealer_address: ContractAddress = *players.at(next_dealer_index);

            // Load the next dealer's data
            let mut next_dealer: Player = world.read_model(next_dealer_address);

            // Check if the next dealer is in the round (assuming 'in_round' is a field in the
            // Player struct)
            if next_dealer.in_round {
                // Remove the is_dealer from the current dealer
                let mut current_dealer: Player = world
                    .read_model(*players.at(current_dealer_index));
                current_dealer.is_dealer = false;
                world.write_model(@current_dealer);

                // Set the next dealer to is_dealer
                next_dealer.is_dealer = true;
                world.write_model(@next_dealer);

                // Return the next dealer
                break Option::Some(next_dealer);
            }

            // Move to the next player
            next_dealer_index = (next_dealer_index + 1) % num_players;

            // If we've come full circle, panic
            if next_dealer_index == initial_dealer_index {
                assert(false, 'ONLY ONE PLAYER IN GAME');
                break Option::None;
            }
        };
        result
    }

    fn _deal_hands(
        ref self: ContractState, ref players: Array<Player>,
    ) { // deal hands for each player in the array
        assert(!players.is_empty(), 'Players cannot be empty');

        let first_player = players.at(0);
        let game_id = first_player.extract_current_game_id();

        for player in players.span() {
            let current_game_id = player.extract_current_game_id();
            assert(current_game_id == game_id, 'Players in different games');
        };

        let mut world = self.world_default();
        let game: Game = world.read_model(*game_id);
        // TODO: Check the number of decks, and deal card from each deck equally
        let deck_ids: Array<u64> = game.deck;

        // let mut deck: Deck = world.read_model(game_id);
        let mut current_index: usize = 0;
        for mut player in players.span() {
            let mut hand: Hand = world.read_model(*player.id);
            hand.new_hand();

            for _ in 0_u8..2_u8 {
                let index = current_index % deck_ids.len();
                let deck_id: u64 = *deck_ids.at(index);
                let mut deck: Deck = world.read_model(deck_id);
                hand.add_card(deck.deal_card());

                world
                    .emit_event(
                        @CardDealt {
                            game_id: *game_id,
                            player_id: *player.id,
                            deck_id: deck.id,
                            time_stamp: starknet::get_block_timestamp(),
                        },
                    );

                world.write_model(@deck); // should work, ;)
                current_index += 1;
            };

            world.write_model(@hand);
            world.write_model(player);

            world
                .emit_event(
                    @HandCreated {
                        game_id: *game_id,
                        player_id: *player.id,
                        time_stamp: starknet::get_block_timestamp(),
                    },
                );
        };
    }

    fn _resolve_hands(
        ref self: ContractState, ref players: Array<Player>,
    ) { // after each round, resolve all players hands by removing all cards from each hand
        // and perhaps re-initialize and shuffle the deck.
        // Extract current game_id from each player (ensuring all players are in the same game)
        // TODO: Fix this function
        let mut game_id: u64 = 0;
        let players_len = players.len();

        assert(players_len > 0, 'Players array is empty');

        // Extract game_id from the first player for comparison
        let first_player = players.at(0);
        let (is_locked, player_game_id) = first_player.locked;

        // Assert the first player is in a game
        assert(*is_locked, GameErrors::PLAYER_NOT_IN_GAME);
        assert(*player_game_id != 0, GameErrors::PLAYER_NOT_IN_GAME);

        game_id = *player_game_id;

        // Verify all players are in the same game
        let mut i: u32 = 1;
        while i < players_len {
            let player = players.at(i);
            let (player_is_locked, player_game_id) = player.locked;
        // Assert the player is in a game
        assert(*player_is_locked, GameErrors::PLAYER_NOT_IN_GAME);
        // Assert all players are in the same game
        assert(*player_game_id == game_id, "Players in different games");

        i += 1;

        // Read game state
        let mut world = self.world_default();
        let mut game: Game = world.read_model(game_id);


        // Get the world storage
        let mut world = self.world_default();

        // Read the game from the world using game_id
        let mut game: Game = world.read_model(game_id);

        // Read and reset the deck from the game
        let mut decks: Array<u64> = game.deck;

        // Re-initialize the deck with the same game_id, for each deck in decks
        for deck_id in decks {
            let mut deck: Deck = world.read_model(deck_id);
            deck.new_deck();
            deck.shuffle();
            world.write_model(@deck); // should work, I guess.
        };

        // Array of all the players
        let mut resolved_players = ArrayTrait::new();

        // Clear each player's hand and update it in the world
        let mut j: u32 = 0;
        while j < players_len {
            // Get player reference and create a mutable copy
            let mut player = players.at(j);

            // Clear the player's hand by creating a new empty hand
            let mut player_address = *player.id;

            // Added each player
            resolved_players.append(player_address);

            let mut hand: Hand = world.read_model(player_address);

            hand.new_hand();

fn _resolve_round(ref self: ContractState, game_id: u64) {
    let mut world = self.world_default();
    let mut game: Game = world.read_model(game_id);
    
    // Get all players in the round
    let mut active_players = ArrayTrait::new();
    
    for player_addr in game.players.span() {
        let mut player: Player = world.read_model(*player_addr);
        
        // Reset player state for next round
        if player.in_round {
            active_players.append(player);
        }
        
        player.has_acted = false;
        player.current_bet = 0;
        player.has_folded = false;
        player.in_round = true;
        
        world.write_model(@player);
    }
    
    // Resolve hands for active players
    self._resolve_hands(ref active_players);
    
    // Reset game state for next round
    game.current_bet = 0;
    game.pot = 0;
    game.community_cards = ArrayTrait::new();
    game.side_pots = ArrayTrait::new();
    game.round_number += 1;
    
    // Set the dealer for the next round
    if !game.players.is_empty() {
        let first_player: Player = world.read_model(*game.players.at(0));
        let _ = self._get_dealer(@first_player);
        
        // Set the first player after the dealer as the current player
        let mut dealer_found = false;
        for player_addr in game.players.span() {
            let player: Player = world.read_model(*player_addr);
            
            if dealer_found {
                game.current_player = *player_addr;
                break;
            }
            
            if player.is_dealer {
                dealer_found = true;
            }
        }
        
        // If dealer was last, start with the first player
        if dealer_found && game.current_player.is_zero() {
            game.current_player = *game.players.at(0);
        }
    }
    
    // Emit event signaling that a new round has started
    world.emit_event(@RoundResolved { game_id: game_id, is_open: true });

    // Write updated game state back to the world
    world.write_model(@game);
}

        
        // Update game state
        world.write_model(@game);
        
        // Emit round resolved event
        self._emit_event(
            @RoundResolved {
                game_id,
                is_open: game.players.len() < game.params.max_no_of_players,
                time_stamp: starknet::get_block_timestamp(),
            },
            ref world
        );
    }

    // @LaGodxy
    fn _deal_community_card(
        ref self: ContractState, ref game: Game,
    ) {
        let mut world = self.world_default();
        let deck_ids: Array<u64> = game.deck;
        
        // Determine how many cards to deal based on current community cards
        let current_cards = game.community_cards.len();
        let cards_to_deal = match current_cards {
            0 => 3, // Flop: deal 3 cards
            3 | 4 => 1, // Turn or River: deal 1 card
            _ => 0, // Invalid state or all cards dealt
        };
        
        if cards_to_deal == 0 {
            return;
        }
        
        // Deal the required number of cards
        let mut deck_index = 0;
        for _ in 0..cards_to_deal {
            // Get a deck in round-robin fashion
            let deck_id = *deck_ids.at(deck_index % deck_ids.len());
            let mut deck: Deck = world.read_model(deck_id);
            
            // Deal a card and add to community cards
            let card = deck.deal_card();
            game.community_cards.append(card);
            
            // Update deck
            world.write_model(@deck);
            deck_index += 1;
        }
        
        // Reset current bets for all players
        for player_addr in game.players.span() {
            let mut player: Player = world.read_model(*player_addr);
            player.current_bet = 0;
            world.write_model(@player);
        }
        
        // Reset game's current bet
        game.current_bet = 0;
        
        // Update game state
        world.write_model(@game);
    }
    
    // @LaGodxy
    /// Helper function to get player and game data
    fn _get_player_and_game(
        self: @ContractState, 
        game_id: u64
    ) -> (ContractAddress, dojo::world::WorldStorage, Player, Game) {
        let caller: ContractAddress = get_caller_address();
        let mut world = self.world_default();
        let player: Player = world.read_model(caller);
        let game: Game = world.read_model(game_id);
        
        (caller, world, player, game)
    }
    
    // @LaGodxy
    /// Helper function to get player and game state for a player
    fn _get_player_game_state(
        self: @ContractState, 
        caller: ContractAddress
    ) -> (dojo::world::WorldStorage, Player, Game) {
        let mut world = self.world_default();
        let player: Player = world.read_model(caller);
        let (_, game_id) = player.locked;
        let game: Game = world.read_model(game_id);
        
        (world, player, game)
    }
    
    // @LaGodxy
    /// Helper function to count active players and return the last active player
    fn _count_active_players(
        self: @ContractState, 
        ref world: dojo::world::WorldStorage, 
        ref game: Game
    ) -> (u32, ContractAddress) {
        let mut active_players = 0;
        let mut last_active_player: ContractAddress = ContractAddress::zero();
        
        for player_addr in game.players.span() {
            let current_player: Player = world.read_model(*player_addr);
            if current_player.in_round {
                active_players += 1;
                last_active_player = *player_addr;
            }
        }
        
        (active_players, last_active_player)
    }
    
    // @LaGodxy
    /// Helper function to reset actions for all players except the specified one
    fn _reset_player_actions(
        self: @ContractState, 
        ref world: dojo::world::WorldStorage, 
        ref game: Game, 
        except_player: ContractAddress
    ) {
        for player_addr in game.players.span() {
            if *player_addr != except_player {
                let mut other_player: Player = world.read_model(*player_addr);
                if other_player.in_round && !other_player.has_folded && !other_player.is_all_in {
                    other_player.has_acted = false;
                    world.write_model(@other_player);
                }
            }
        }
    }
    
    // @LaGodxy
    /// Helper function to reset actions for all players
    fn _reset_all_player_actions(
        self: @ContractState, 
        ref world: dojo::world::WorldStorage, 
        ref game: Game
    ) {
        for player_addr in game.players.span() {
            let mut player: Player = world.read_model(*player_addr);
            if player.in_round && !player.has_folded && !player.is_all_in {
                player.has_acted = false;
                world.write_model(@player);
            }
        }
    }
    
    // @LaGodxy
    /// Helper function to check if all players have acted and find the next player
    fn _check_player_actions(
        self: @ContractState, 
        ref world: dojo::world::WorldStorage, 
        ref game: Game
    ) -> (bool, ContractAddress) {
        let mut all_acted = true;
        let mut next_player = ContractAddress::zero();
        
        for player_addr in game.players.span() {
            let current_player: Player = world.read_model(*player_addr);
            if current_player.in_round && !current_player.has_folded && !current_player.is_all_in {
                if !current_player.has_acted {
                    all_acted = false;
                    next_player = *player_addr;
                    break;
                }
            }
        }
        
        (all_acted, next_player)
    }
    
    // @LaGodxy
    /// Helper function to get the first active player
    fn _get_first_active_player(
        self: @ContractState, 
        ref world: dojo::world::WorldStorage, 
        ref game: Game
    ) -> ContractAddress {
        for player_addr in game.players.span() {
            let player: Player = world.read_model(*player_addr);
            if player.in_round && !player.has_folded && !player.is_all_in {
                return *player_addr;
            }
        }
        
        // Fallback to first player if no active player found
        if !game.players.is_empty() {
            return *game.players.at(0);
        }
        
        ContractAddress::zero()
    }
    
    // @LaGodxy
    /// Helper function to get all active players
    fn _get_active_players(
        self: @ContractState, 
        ref world: dojo::world::WorldStorage, 
        ref game: Game
    ) -> Array<Player> {
        let mut active_players = ArrayTrait::new();
        
        for player_addr in game.players.span() {
            let player: Player = world.read_model(*player_addr);
            active_players.append(player);
        }
        
        active_players
    }
    
    // @LaGodxy
    /// Helper function to emit events
    fn _emit_event<T>(
        self: @ContractState, 
        event: @T, 
        ref world: dojo::world::WorldStorage
    ) {
        world.emit_event(event);
    }
}
}

