/// CONTRACT HANDLING THE POKER GAME

#[dojo::contract]
pub mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::model::{ModelStorage, ModelValueStorage};
    use dojo::event::EventStorage;
    // use dojo::world::{WorldStorage, WorldStorageTrait};

    use poker::models::base::{
        GameErrors, Id, GameInitialized, CardDealt, HandCreated, HandResolved, RoundResolved,
    };
    use poker::models::card::{Card, CardTrait};
    use poker::models::deck::{Deck, DeckTrait};
    use poker::models::game::{Game, GameMode, GameParams, GameTrait};
    use poker::models::hand::{Hand, HandTrait};
    use poker::models::player::{Player, PlayerTrait, get_default_player};
    use poker::traits::game::get_default_game_params;
    use super::super::interface::IActions;

    pub const GAME: felt252 = 'GAME';
    pub const DECK: felt252 = 'DECK';
    pub const MAX_NO_OF_CHIPS: u128 = 100000; /// for test, 1 chip = 1 usd.


    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
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

            game_id
        }

        fn join_game(
            ref self: ContractState, game_id: u64,
        ) { // check the game in_progress and has_ended values
        // check the number
        // if has_ended, panic
        // if in progress, then further checks in the gameparams are done, based on the game mode
        // and round in progress. optimize code as good as possible
        // init a player (check if the player exists, if not, create a new one)
        // call the internal function player_in_game
        // check the number of chips
        // for each join, check the max no. of players allowed in the game params of the game_id, if
        // reached, start the session.
        // starting the session involves changing some variables in the game and dealing cards,
        // basically initializing the game.
        // set player_in_round to true

        // when max number of participants have been reached, emit a GameStarted event
        // who joined event
        // world.emit_event(@PlayerJoined{game_id, player})
        }

        fn leave_game(ref self: ContractState) { // assert if the player exists
        // extract game_id
        // assert if the game exists
        // assert player.locked == true
        // Check if the player is in the game

        // Emit an event here
        // world.emit_event(@PlayerLeft{game_id, player})
        }

        fn end_game(ref self: ContractState, game_id: u64) {}

        fn check(ref self: ContractState) {}

        fn call(ref self: ContractState) {}

        fn fold(ref self: ContractState) {}

        fn raise(ref self: ContractState, no_of_chips: u256) {}

        fn all_in(ref self: ContractState) { //
        // deduct all available no. of chips
        }

        fn buy_chips(ref self: ContractState, no_of_chips: u256) { // use a crate here
        // a package would be made for all transactions and nfts out of this contract package.
        // world.emit_event(@BoughtChip{game_id, no_of_chips})
        }

        fn get_dealer(self: @ContractState) -> Option<Player> {
            Option::None
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

            world.write_model(@player);
        }
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
        ) { // Check the chips available in the player model
            // check if player is locked to a session
            // check if the player is even in the game (might have left along the way)...call the
            // below function
            // check if it's player's turn

            // Initialize the world state
            let mut world = self.world_default();

            // Retrieve the player model based on the caller (ContractAddress)
            let player: Player = world.read_model(caller);
            let (is_locked, game_id) = player.locked;

            // Check if the player is locked into a session; if not locked, they can't play
            assert(is_locked, GameErrors::PLAYER_NOT_IN_GAME);

            // Retrieve the game model associated with the player's game_id
            let game: Game = world.read_model(game_id);

            // Ensure the player has chips to play
            assert(player.chips > 0, GameErrors::PLAYER_OUT_OF_CHIPS);

            // Ensure the player is actively in the current round
            assert(player.in_round, 'Player not active in round');

            // Check if it is the player's turn
            match game.next_player {
                Option::Some(next_player) => {
                    // Assert that the next player to play is the caller
                    assert(next_player == caller, 'Not player turn');
                },
                Option::None => { // TODO: END GAME
                },
            }
        }

        /// This function performs all default actions immediately a player joins the game.
        /// May call the previous function. (should not, actually)
        fn player_in_game(
            self: @ContractState, caller: ContractAddress,
        ) { // Check if player is already in the game
            // Check if player is locked (already in a game), check the player struct.
            // The above two checks seem similar, but they differ in the error messages they return.
            // Check if player has enough chips to join the game

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

            world.write_model(@player);

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

                    world.write_model(@deck); // should work, ;)
                    current_index += 1;

                    world
                        .emit_event(
                            @CardDealt {
                                game_id: *game_id,
                                player_id: *player.id,
                                deck_id: deck.id,
                                time_stamp: starknet::get_block_timestamp(),
                            },
                        );
                };

                world.write_model(@hand);
                world.write_model(player);
            };
        }

        fn _resolve_hands(
            ref self: ContractState, ref players: Array<Player>,
        ) { // after each round, resolve all players hands by removing all cards from each hand
            // and perhaps re-initialize and shuffle the deck.
            // Extract current game_id from each player (ensuring all players are in the same game)
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
                assert(*player_game_id == game_id, 'Players in different games');

                i += 1;
            };

            let mut world = self.world_default();
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

                world.write_model(@hand);
                j += 1;
            };

            world.emit_event(@HandResolved { game_id: game_id, players: resolved_players });
        }

        /// dev: @psychemist
        ///
        /// Resolves the current round and prepares the game for the next round
        ///
        /// This function:
        /// 1. Resets player hands and decks by calling _resolve_hands
        /// 2. Updates game state (increments round counter, resets flags)
        /// 3. Resets player states for the next round
        /// 4. Checks if new players can join based on game parameters
        /// 5. Emits appropriate events
        ///
        /// # Arguments
        /// * `game_id` - The ID of the game whose round is being resolved
        fn _resolve_round(ref self: ContractState, game_id: u64) {
            // should call resolve_hands()
            // should write back the player and the game to the world
            // all players should be set back in the next round
            // increment number of rounds,
            // emit an event that a game_id round is open for others to join, only if necessary game
            // param checks have been cleared.

            let mut world = self.world_default();
            let mut game: Game = world.read_model(game_id);

            assert(game.in_progress, GameErrors::GAME_NOT_IN_PROGRESS);
            assert(game.round_in_progress, GameErrors::ROUND_NOT_IN_PROGRESS);

            // Collect all players from the game
            let mut players: Array<Player> = array![];
            for player_address in game.players.span() {
                let player: Player = world.read_model(*player_address);
                players.append(player);
            };

            // Reset player hands and decks
            self._resolve_hands(ref players);

            // Write the modified players back to the world storage first
            for player in players.span() {
                world.write_model(player);
            };

            // Update game state for the next round
            game.current_round += 1;
            game.round_in_progress = false;
            game.community_cards = array![];
            game.current_bet = 0;

            // Reset player states for the next round
            for player_ref in game.players.span() {
                // Read the player with resolved hands from the world
                let mut player_copy: Player = world.read_model(*player_ref);

                // Only set in_round to true for players still in the game (not folded)
                if player_copy.is_in_game(game_id) {
                    // Modify the copy
                    player_copy.current_bet = 0;
                    player_copy.in_round = true;

                    // Write the modified copy back to world
                    world.write_model(@player_copy);
                }
            };

            // dev: @Oluebube01
            // Collect hands of all players still in the game and in the round
            let mut active_hands: Array<Hand> = array![];
            for player_ref in game.players.span() {
                let player: Player = world.read_model(*player_ref);
                if player.is_in_game(game_id) && player.in_round {
                    let hand: Hand = world.read_model(*player.id);
                    active_hands.append(hand);
                }
            };

            // Ensure there are active hands to compare
            assert(!active_hands.is_empty(), 'No active hands to compare');

            // Determine the winning hand(s) using HandTrait::compare_hands
            let (winning_hands, best_combination) = HandTrait::compare_hands(@active_hands);

            // Emit an event with the winners of the round
            let mut winner_ids: Array<ContractAddress> = array![];
            for winning_hand in winning_hands.span() {
                winner_ids.append(*winning_hand.owner_id());
            };

            world.emit_event(@RoundResolved {
                game_id: game_id,
                winners: winner_ids,
                best_combination: best_combination,
            });


            // Check if the game allows new players to join based on game parameters
            let _can_join = game.is_allowable();

            world.write_model(@game);

            world.emit_event(@RoundResolved { game_id: game_id, can_join: _can_join });
        }


        /// dev: @psychemist
        ///
        /// Deals a community card to the game board
        ///
        /// This function:
        /// 1. Verifies that the game state allows adding a community card
        /// 2. Selects a deck to deal from
        /// 3. Deals a card and adds it to the community cards
        ///
        /// # Arguments
        /// * `game_id` - The ID of the game to deal a community card to
        ///
        /// # Returns
        /// * Array of Card - The updated community cards
        fn _deal_community_card(ref self: ContractState, game_id: u64) -> Array<Card> {
            let mut world = self.world_default();
            let mut game: Game = world.read_model(game_id);

            // Ensure game exists and is in a valid state
            assert(game.in_progress, GameErrors::GAME_NOT_IN_PROGRESS);
            assert(game.round_in_progress, GameErrors::ROUND_NOT_IN_PROGRESS);

            // Check if we can add more community cards (max 5)
            assert(game.community_cards.len() < 5, GameErrors::COMMUNITY_CARDS_FULL);

            let deck_ids = @game.deck;
            assert(!deck_ids.is_empty(), GameErrors::NO_DECKS_AVAILABLE);

            // Cyclically select a deck based on the current community card count
            // This distributes card dealing across all available decks
            let deck_index = game.community_cards.len() % deck_ids.len();
            let deck_id = *deck_ids.at(deck_index);
            let mut deck: Deck = world.read_model(deck_id);

            // Deal a card from the deck and add to community cards
            let card = deck.deal_card();

            game.community_cards.append(card);

            world.write_model(@deck);
            world.write_model(@game);

            game.community_cards
        }

        // extracts the winning hands
        fn extract_winner() -> (Array<Hand>, Option<Array<Card>>) {
            (array![], Option::None)
        }

        // dev: @Oluebube01
        /// Resolves the game by determining the winner(s) and distributing chips
        /// This function:
        /// 1. Ensures the game exists and is in a valid state for resolution.
        /// 2. Determines the winner(s) based on game rules.
        /// 3. Distributes chips to the winner(s).
        /// 4. Emits an event indicating the game has ended.
        /// 5. Cleans up game state and player states.
        ///
        /// # Arguments
        /// * `game_id` - The ID of the game to resolve.
        fn resolve_game(ref self: ContractState, game_id: u64) {
            let mut world = self.world_default();
            let mut game: Game = world.read_model(game_id);

            // Ensure the game exists and is in progress
            assert(game.in_progress, GameErrors::GAME_NOT_IN_PROGRESS);
            assert(!game.has_ended, GameErrors::GAME_ALREADY_ENDED);

            // Collect all players in the game
            let mut players: Array<Player> = array![];
            for player_address in game.players.span() {
            let player: Player = world.read_model(*player_address);
            players.append(player);
            };

            // Ensure there are players in the game
            assert(!players.is_empty(), 'No players in the game');

            // Resolve hands to determine the winner(s)
            let mut active_hands: Array<Hand> = array![];
            for player in players.span() {
            if player.is_in_game(game_id) && player.in_round {
                let hand: Hand = world.read_model(*player.id);
                active_hands.append(hand);
            }
            };

            // Ensure there are active hands to compare
            assert(!active_hands.is_empty(), 'No active hands to compare');

            let (winning_hands, best_combination) = HandTrait::compare_hands(@active_hands);

            // Distribute chips to the winner(s)
            let mut winner_ids: Array<ContractAddress> = array![];
            let chips_to_distribute = game.pot / winning_hands.len();
            for winning_hand in winning_hands.span() {
            let mut winner: Player = world.read_model(*winning_hand.owner_id());
            winner.chips += chips_to_distribute;
            winner_ids.append(*winner.id);
            world.write_model(@winner);
            };

            // Mark the game as ended
            game.has_ended = true;
            game.in_progress = false;
            world.write_model(@game);

            // Emit an event indicating the game has ended
            world.emit_event(@GameEnded {
            game_id: game_id,
            winners: winner_ids,
            best_combination: best_combination,
            pot: game.pot,
            time_stamp: starknet::get_block_timestamp(),
            });

            // Clean up player states
            for player in players.span() {
            let mut player_copy: Player = world.read_model(*player.id);
            player_copy.locked = (false, 0);
            player_copy.in_round = false;
            world.write_model(@player_copy);
            };

            // Check the ownable field in GameParams
            match game.params.ownable {
                Option::Some(owner_address) => {
                    // Ensure the caller matches the owner address
                    let caller: ContractAddress = get_caller_address();
                    assert(caller == owner_address, GameErrors::UNAUTHORIZED);
                },
                Option::None => {
                    // Panic if the game is not ownable
                    assert(false, GameErrors::GAME_CANNOT_BE_RESOLVED);
                },
            };
        }
    }
}
