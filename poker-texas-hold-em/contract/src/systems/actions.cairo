/// POKER CONTRACT
#[dojo::contract]
pub mod actions {
    use core::num::traits::Zero;
    use dojo::event::EventStorage;
    use dojo::model::{Model, ModelStorage, ModelValueStorage};
    use poker::models::base::{
        CardDealt, GameConcluded, GameErrors, GameInitialized, HandCreated, HandResolved, Id,
        PlayerJoined, PlayerLeft, RoundResolved, RoundStarted, RoundSubmissions,
    };
    use poker::models::card::{Card, CardTrait};
    use poker::models::deck::{Deck, DeckTrait};
    use poker::models::game::{Game, GameMode, GameParams, GameStats, GameTrait, Salts};
    use poker::models::hand::{Hand, HandTrait};
    use poker::models::player::{Player, PlayerTrait};
    use poker::traits::game::get_default_game_params;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::systems::interface::IActions;
    use crate::utils::deck::verify_game;

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

            let game_initialized = GameInitialized {
                game_id: game_id,
                player: caller,
                game_params: game.params,
                time_stamp: get_block_timestamp(),
            };

            world.emit_event(@game_initialized);
            game_id
        }

        /// @Birdmannn
        fn join_game(ref self: ContractState, game_id: u64) {
            let mut world = self.world_default();
            let mut game: Game = world.read_model(game_id);
            assert(game.is_allowable(), GameErrors::ENTRY_DISALLOWED);

            let caller: ContractAddress = get_caller_address();
            let mut player: Player = world.read_model(caller);
            let can_start: bool = player.enter(ref game);

            let player_joined = PlayerJoined {
                game_id,
                player_id: caller,
                player_count: game.current_player_count,
                expected_no_of_players: game.params.max_no_of_players,
            };

            world.emit_event(@player_joined);

            // if can_start, then the game is ready to be started.
            if can_start { // TODO:
            // **************************************
            //      CALL START ROUND FUNCTION
            // **************************************
            // ASSERT THAT THE START_ROUND EMITS A GAMESTARTED EVENT.
            }

            world.write_model(@game);
            world.write_model(@player);
        }

        /// @Birdmannn
        fn leave_game(ref self: ContractState) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let mut player: Player = world.read_model(caller);

            let game_id = *player.extract_current_game_id();
            let mut game: Game = world.read_model(game_id);

            // you can leave and return only for CashGame GameModes
            let out = game.params.game_mode == Default::default();
            // this decrements the player count
            player.exit(ref game, out);

            let precision = 1_000_000;
            let ratio = precision / 5; // 1 out of 5 players, times precision
            let current_ratio = game.current_player_count * precision / game.players.len();
            if ratio >= current_ratio {
                // shuffle.
                let mut players = array![];
                for c in game.players {
                    let p: Player = world.read_model(c);
                    if p.is_in_game(game_id) {
                        players.append(c);
                    }
                };
                game.players = players;
                game.reshuffled += 1;
            }

            let player_left = PlayerLeft {
                game_id,
                player_id: caller,
                player_count: game.current_player_count,
                expected_no_of_players: game.params.max_no_of_players,
            };
            world.emit_event(@player_left);
            if game.current_player_count == 0 {
                // for the bool variable, the value is not really necessary because it's called
                // by this contract.
                self._resolve_game(ref game, get_contract_address(), true);
            }
            world.write_model(@game);
            world.write_model(@player);
        }

        /// @Birdmannn
        fn end_game(ref self: ContractState, game_id: u64, force: bool) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let mut game: Game = world.read_model(game_id);
            if game.has_ended {
                return;
            }
            // TODO: You can assign admin roles of the tournament that can bypass this check.
            // naturally, a `game` should end when all players leave the game
            self._resolve_game(ref game, caller, force);
            // would be audited in the future.
        }

        /// @dub_zn
        fn check(ref self: ContractState) {
            let mut world = self.world_default();
            let mut player: Player = world.read_model(get_caller_address());

            self.before_play(player.id);
            let game: Game = world.read_model(*player.extract_current_game_id());
            assert!(
                player.current_bet == game.current_bet,
                "Your bet is not matched with the table. You must call, raise, or fold.",
            );

            self.after_play(player.id);
        }

        /// @dub_zn
        fn call(ref self: ContractState) {
            let mut world = self.world_default();
            let mut player: Player = world.read_model(get_caller_address());
            self.before_play(player.id);

            let mut game: Game = world.read_model(*player.extract_current_game_id());
            let amount_to_call = game.current_bet - player.current_bet;

            assert!(amount_to_call > 0, "Your bet is already equal to the current bet.");

            assert!(player.chips >= amount_to_call, "You don't have enough chips to call.");

            player.chips -= amount_to_call;
            player.current_bet += amount_to_call;
            game.pot += amount_to_call;

            world.write_model(@player);
            world.write_model(@game);

            self.after_play(player.id);
        }

        /// @dub_zn
        fn fold(ref self: ContractState) {
            let mut world = self.world_default();
            let mut player: Player = world.read_model(get_caller_address());
            self.before_play(player.id);

            player.in_round = false;
            world.write_model(@player);

            self.after_play(player.id);
        }

        /// @dub_zn
        fn raise(ref self: ContractState, no_of_chips: u256) {
            let mut world = self.world_default();
            let mut player: Player = world.read_model(get_caller_address());
            self.before_play(player.id);

            let mut game: Game = world.read_model(*player.extract_current_game_id());

            let amount_to_call = game.current_bet - player.current_bet;
            let total_required = amount_to_call + no_of_chips;

            assert!(no_of_chips > 0, "Raise amount must be greater than zero.");

            assert!(player.chips >= total_required, "You don't have enough chips to raise.");

            player.chips -= total_required;
            player.current_bet += total_required;
            game.pot += total_required;
            game.current_bet = player.current_bet;

            world.write_model(@player);
            world.write_model(@game);

            self.after_play(player.id);
        }

        /// @dub_zn
        fn all_in(ref self: ContractState) {
            let mut world = self.world_default();
            let player: Player = world.read_model(get_caller_address());
            self.raise(player.chips);
        }

        fn get_rank(self: @ContractState, player_id: ContractAddress) -> ByteArray {
            let mut world = self.world_default();
            let player: Player = world.read_model(player_id);
            let game_id = player.extract_current_game_id();
            let game: Game = world.read_model(*game_id);
            let hand: Hand = world.read_model(player_id);
            let (_, rank) = hand.rank(game.community_cards);
            rank.into()
        }

        fn buy_in(ref self: ContractState, no_of_chips: u256) { // use a crate here
        // a package would be made for all transactions and nfts out of this contract package.
        // world.emit_event(@BoughtChip{game_id, no_of_chips})
        }

        fn get_dealer(self: @ContractState) -> Option<Player> {
            Option::None
        }

        fn deal_community_card(
            ref self: ContractState, card: Card, game_id: u256,
        ) { // verify signature on this function too.
        }

        fn showdown(
            ref self: ContractState,
            game_id: u64,
            hands: Array<Hand>,
            game_proofs: Array<Array<felt252>>,
            dealt_card_proofs: Array<Array<felt252>>,
            deck: Deck,
            game_salt: Array<felt252>,
            dealt_card_salt: Array<felt252>,
        ) {
            let (g, d) = (game_salt, dealt_card_salt);
            assert(g.len() == 3 && d.len() == 3, 'INVALID SALT');
            let mut world = self.world_default();

            // verify signatures here

            // these are snapshpts
            let g_key = (*g.at(0), *g.at(1), *g.at(2));
            let d_key = (*d.at(0), *d.at(1), *d.at(2));
            let mut G: Salts = world.read_model(g_key);
            let mut D: Salts = world.read_model(d_key);
            let mut game: Game = world.read_model(game_id);
            assert(!game.has_ended, GameErrors::GAME_ALREADY_ENDED);
            // write the salt to invalidate. A wrong showdown disqualifies the whole game if
            // actually any of the salts were valid.
            assert(!G.used && !D.used, 'INVALID SALT');
            world.write_member(Model::<Salts>::ptr_from_keys(g_key), selector!("used"), true);
            world.write_member(Model::<Salts>::ptr_from_keys(d_key), selector!("used"), true);
            assert(game.round_in_progress && game.community_cards.len() == 5, 'BAD REQUEST');

            let (mut gp, mut dcp, mut dc) = (game_proofs, dealt_card_proofs, deck);
            let deck_root: felt252 = game.deck_root;
            let dealt_root: felt252 = game.dealt_cards_root;
            // for now, the game houses the community cards. This will be changed.
            let community_cards: Array<Card> = game.community_cards.clone();

            let verified: bool = verify_game(
                community_cards.clone(), hands.clone(), gp, dcp, dc, deck_root, dealt_root, g, d,
            );

            self._resolve_round_v2(hands, community_cards, verified);
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
            assert(caller != Zero::zero(), 'ZERO CALLER');
            let mut world = self.world_default();
            let mut player: Player = world.read_model(caller);
            let check: Player = world.read_model(alias.clone());
            assert(check.id == Zero::zero(), 'ALIAS UPDATE FAILED');
            player.alias = alias;

            world.write_model(@player);
        }

        fn resolve_round(ref self: ContractState, game_id: u64) {
            self._resolve_round(game_id);
        }

        // @AugmentAgent
        /// Submits a player's cards with proofs for verification
        ///
        /// This function:
        /// 1. Validates that the player is in a round and has finished playing
        /// 2. Verifies the submitted cards and proofs against the game's merkle roots
        /// 3. If verification succeeds: stores the hand on-chain and increments submission count
        /// 4. If verification fails: deducts the staked amount from the player
        /// 5. Automatically calls resolve_game when all players have submitted
        ///
        /// # Arguments
        /// * `cards` - Array of cards being submitted by the player
        /// * `deck_proof` - Merkle proof for the deck state
        /// * `dealt_cards_proof` - Merkle proof for the dealt cards state
        /// * `staked_amount` - Amount of chips staked for this submission
        fn submit_card(
            ref self: ContractState,
            cards: Array<Card>,
            deck_proof: Array<felt252>,
            dealt_cards_proof: Array<felt252>,
            staked_amount: u256,
        ) {
            let caller = get_caller_address();
            let mut world = self.world_default();

            // Get player and validate they are in a round
            let mut player: Player = world.read_model(caller);
            let (is_locked, game_id) = player.locked;

            assert(is_locked, GameErrors::PLAYER_NOT_IN_GAME);
            assert(player.in_round, 'Player not in round');

            // Get game and validate state
            let mut game: Game = world.read_model(game_id);
            assert(game.in_progress, GameErrors::GAME_NOT_IN_PROGRESS);
            assert(game.round_in_progress, GameErrors::ROUND_NOT_IN_PROGRESS);

            // Ensure player has enough chips for staking
            assert(player.chips >= staked_amount, GameErrors::INSUFFICIENT_CHIP);

            // Verify the submitted cards against the game's merkle roots
            let verification_result = self.verify_card(
                cards.clone(),
                deck_proof,
                dealt_cards_proof,
                game.deck_root,
                game.dealt_cards_root,
            );

            if verification_result {
                // Verification succeeded - store the hand on-chain
                let mut hand: Hand = world.read_model(caller);
                hand.cards = cards;
                world.write_model(@hand);

                // Update submission tracking
                self._increment_submission_count(game_id, game.current_round, game.current_player_count);

                // Check if all players have submitted
                let submissions: RoundSubmissions = world.read_model((game_id, game.current_round));
                if submissions.submitted_count >= submissions.total_players {
                    // All players have submitted - automatically resolve the game
                    self._resolve_round(game_id);
                }
            } else {
                // Verification failed - deduct staked funds
                player.chips -= staked_amount;
                game.pot += staked_amount;
                world.write_model(@player);
                world.write_model(@game);
            }
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

        /// @AugmentAgent
        /// Verifies that the submitted cards and proofs are valid against the game's merkle roots
        ///
        /// # Arguments
        /// * `cards` - Array of cards to verify
        /// * `deck_proof` - Merkle proof for the deck state (single proof for simplicity)
        /// * `dealt_cards_proof` - Merkle proof for the dealt cards state (single proof for simplicity)
        /// * `deck_root` - The merkle root of the deck state
        /// * `dealt_cards_root` - The merkle root of the dealt cards state
        ///
        /// # Returns
        /// * `bool` - true if verification succeeds, false otherwise
        ///
        /// # Note
        /// For simplicity, this implementation uses a single proof for all cards.
        /// In a production system, each card would have its own proof.
        fn verify_card(
            self: @ContractState,
            cards: Array<Card>,
            deck_proof: Array<felt252>,
            dealt_cards_proof: Array<felt252>,
            deck_root: felt252,
            dealt_cards_root: felt252,
        ) -> bool {
            // Ensure we have cards to verify
            if cards.is_empty() {
                return false;
            }

            // For now, we'll do a simplified verification
            // In a real implementation, each card would need its own proof and index
            // This is a placeholder that will return false for invalid roots (0)
            // and true for valid-looking roots (non-zero)
            if deck_root == 0 || dealt_cards_root == 0 {
                return false;
            }

            // Use default salt arrays for verification (should match game initialization)
            let deck_salt = array!['DECK_SALT1', 'DECK_SALT2', 'DECK_SALT3'];
            let dealt_salt = array!['DEALT_SALT1', 'DEALT_SALT2', 'DEALT_SALT3'];

            // For demonstration purposes, verify the first card with index 0
            // In a real implementation, you'd need proper indexing for each card
            if cards.len() > 0 {
                let mut first_card = *cards.at(0);
                let deck_verified = self._verify_single_card(
                    deck_proof.clone(), deck_root, first_card, deck_salt.clone(), 0
                );
                let dealt_verified = self._verify_single_card(
                    dealt_cards_proof.clone(), dealt_cards_root, first_card, dealt_salt.clone(), 0
                );

                // Return true only if both verifications pass
                return deck_verified && dealt_verified;
            }

            false
        }

        /// @AugmentAgent
        /// Helper function to verify a single card against a merkle root
        ///
        /// # Arguments
        /// * `proof` - Merkle proof for the card
        /// * `root` - The merkle root to verify against
        /// * `card` - The card to verify
        /// * `salt` - Salt array for hashing
        /// * `index` - Index of the card in the merkle tree
        ///
        /// # Returns
        /// * `bool` - true if verification succeeds, false otherwise
        fn _verify_single_card(
            self: @ContractState,
            proof: Array<felt252>,
            root: felt252,
            mut card: Card,
            salt: Array<felt252>,
            index: usize,
        ) -> bool {
            use poker::utils::game::MerkleTrait;
            let card_hash = card.hash(salt);
            MerkleTrait::verify_v2(proof, root, card_hash, index)
        }

        /// @AugmentAgent
        /// Increments the submission count for the current round
        ///
        /// # Arguments
        /// * `game_id` - The ID of the game
        /// * `round_number` - The current round number
        /// * `total_players` - Total number of players in the game
        fn _increment_submission_count(
            ref self: ContractState,
            game_id: u64,
            round_number: u8,
            total_players: u32,
        ) {
            let mut world = self.world_default();

            let mut submissions: RoundSubmissions = world.read_model((game_id, round_number));

            // Initialize if this is the first submission for this round
            if submissions.submitted_count == 0 && submissions.total_players == 0 {
                submissions.game_id = game_id;
                submissions.round_number = round_number;
                submissions.total_players = total_players;
            }

            submissions.submitted_count += 1;
            world.write_model(@submissions);
        }

        // @LaGodxy
        /// This function makes all assertions on if player is meant to call this function.
        fn before_play(self: @ContractState, caller: ContractAddress) {
            let mut world = self.world_default();
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

        /// @Reentrancy
        fn after_play(ref self: ContractState, caller: ContractAddress) {
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

            // TODO: Crosscheck after_play, and adjust... may not be needed.
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

        // @nagxsan
        fn update(ref self: ContractState, game_id: u64, updated_game_stats: GameStats) {
            let mut world: dojo::world::WorldStorage = self.world_default();
            // remove this _game_stats in the future.
            let _game_stats: GameStats = world.read_model(game_id);
            world.write_model(@updated_game_stats);
        }

        // @nagxsan
        fn extract_mvp(self: @ContractState, game_id: u64) -> ContractAddress {
            let mut world: dojo::world::WorldStorage = self.world_default();
            let game_stats: GameStats = world.read_model(game_id);
            game_stats.mvp
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
            }

            // Calculate the index of the next dealer
            let mut next_dealer_index: usize = (current_dealer_index + 1) % num_players;
            // save initial dealer index to prevent infinite loop
            let mut initial_dealer_index: usize = current_dealer_index;

            let result = loop {
                // Get the address of the next dealer
                let next_dealer_address: ContractAddress = *players.at(next_dealer_index);
                let mut next_dealer: Player = world.read_model(next_dealer_address);

                if next_dealer.in_round {
                    // Remove the is_dealer from the current dealer
                    let mut current_dealer: Player = world
                        .read_model(*players.at(current_dealer_index));
                    current_dealer.is_dealer = false;
                    world.write_model(@current_dealer);

                    next_dealer.is_dealer = true;
                    world.write_model(@next_dealer);

                    break Option::Some(next_dealer);
                }

                next_dealer_index = (next_dealer_index + 1) % num_players;

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
                };

                world.write_model(@hand);
                world.write_model(player);
            };
        }

        fn _resolve_round_v2(
            ref self: ContractState,
            hands: Array<Hand>,
            community_cards: Array<Card>,
            verified: bool,
        ) { // resolve root
        // check if verified, by the way.
        // DO NOT DELETE.
        // in the future, check if the game should be verifiable, else, users should use the
        // submit card endpoint.
        // TODO: call `resolve_game()`, and update the `resolve_game()` with its appropriate
        // logic.
        // if game is not verified, read funds in the id, and split toegther with contract
        // accordingly.
        // perhaps let `resolve_game()` take in a bool to assert that the game was resolved
        // accordingly.
        // write a new internal function `resolve_v2`

        // assert that this game is valid
        // NOTE: CALLER CAN BE ZERO, FOR NOW.
        // check the game_params, if the game is verifiable
        // else, users should use the `submit_card` endpoint.
        // set both roots to zero in the `resolve_game`
        // set round_in_progress to false, by the way.
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

        /// @psychemist, @Birdmannn, @NathaliaBarreiros
        ///
        /// Resolves the current round and prepares the game for the next round.
        /// Implements issue #144: skips players with empty hands and resets game roots.
        ///
        /// This function:
        /// 1. Validates game state and separates players with valid hands from empty ones
        /// 2. Updates game state (increments round counter, resets flags)
        /// 3. Resets player states for ALL players (not just valid ones)
        /// 4. Cleans all player hands and resets merkle tree roots via _cleanup_game_data
        /// 5. Checks if new players can join based on game parameters
        /// 6. Emits appropriate events
        ///
        /// This function validates game state, processes players with valid hands,
        /// skips players with empty hands gracefully, resets all player hands,
        /// and ensures both merkle tree roots are reset to zero for security.
        ///
        /// # Arguments
        /// * `game_id` - The ID of the game whose round is being resolved
        fn _resolve_round(ref self: ContractState, game_id: u64) {
            let mut world = self.world_default();
            let mut game: Game = world.read_model(game_id);

            assert(game.in_progress, GameErrors::GAME_NOT_IN_PROGRESS);
            assert(game.round_in_progress, GameErrors::ROUND_NOT_IN_PROGRESS);

            // Collect players with valid hands, skipping those with empty hands
            let mut valid_players: Array<Player> = array![];
            let mut all_player_addresses: Array<ContractAddress> = array![];

            for player_address in game.players.span() {
                let player: Player = world.read_model(*player_address);
                let hand: Hand = world.read_model(*player_address);
                all_player_addresses.append(*player_address);

                // Skip players with empty hands (they didn't submit cards)
                if hand.cards.len() == 0 {
                    continue;
                }
                valid_players.append(player);
            };

            assert(valid_players.len() > 0, 'No valid hands to resolve round');

            // Update game state for the next round
            game.current_round += 1;
            game.round_in_progress = false;
            game.community_cards = array![];
            game.current_bet = 0;

            // Reset player states for ALL players (not just valid ones)
            for player_address in game.players.span() {
                let mut player_copy: Player = world.read_model(*player_address);
                if player_copy.is_in_game(game_id) {
                    player_copy.current_bet = 0;
                    player_copy.in_round = true;
                    world.write_model(@player_copy);
                }
            };

            // Save the game state before cleaning roots
            world.write_model(@game);

            // Clean up game state and reset merkle tree roots
            self._cleanup_game_data(game_id, all_player_addresses.span());

            // Check if the game allows new players to join
            let can_join = game.is_allowable();
            if game.should_end {
                self._resolve_game(ref game, get_contract_address(), false);
            }

            let (winning_hands, _) = self._extract_winner();
            let mut winners = array![];
            for i in 0..winning_hands.len() {
                let winner = winning_hands.at(i);
                winners.append(*winner.player);
            };
            let pot = game.pot;

            let round_resolved = RoundResolved {
                game_id: game_id, can_join: can_join, winners: winners, pot: pot,
            };
            world.emit_event(@round_resolved);
        }

        /// @NathaliaBarreiros
        ///
        /// Centralizes cleanup of all player hand data and resets game state.
        /// Ensures all stored cards are properly cleared from world state.
        ///
        /// # Arguments
        /// * `game_id` - The ID of the game being cleaned up
        /// * `players` - Span of all player addresses that participated in the game
        fn _cleanup_game_data(
            ref self: ContractState, game_id: u64, players: Span<ContractAddress>,
        ) {
            let mut world = self.world_default();
            let mut game: Game = world.read_model(game_id);

            // Reset both merkle tree roots to zero
            game.deck_root = 0;
            game.dealt_cards_root = 0;
            world.write_model(@game);

            // Clean up all player hands
            let mut i: u32 = 0;
            while i < players.len() {
                let player_address = *players.at(i);
                let mut hand: Hand = world.read_model(player_address);
                hand.new_hand(); // Clear all cards from this player's hand
                world.write_model(@hand);
                i += 1;
            };
        }

        // @Birdmannn, @nagxsan
        fn _resolve_game(
            ref self: ContractState, ref game: Game, caller: ContractAddress, force: bool,
        ) {
            let mut world = self.world_default();
            let round_in_progress = @game.round_in_progress;
            if caller != get_contract_address() {
                if *round_in_progress && !force {
                    game.should_end = true;
                    return;
                }
                // forced
                // TODO: Do a split in the pot here, and extract winner.
                // eject all players from the game
                let players = game.players.clone();
                for i in 0..players.len() {
                    let mut player: Player = world.read_model(*players.at(i));
                    player.exit(ref game, false);
                }
            }

            game.has_ended = true;
            game.next_player = Option::None;
            // the remaining fields would be left for stats
            let mvp = self.extract_mvp(game.id);
            let game_concluded = GameConcluded {
                game_id: game.id, time_stamp: get_block_timestamp(), mvp,
            };
            world.emit_event(@game_concluded);
        }

        /// @psychemist
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
            assert(game.community_cards.len() <= 5, GameErrors::COMMUNITY_CARDS_FULL);

            let deck_ids = @game.deck;
            assert(!deck_ids.is_empty(), GameErrors::NO_DECKS_AVAILABLE);

            // Cyclically select a deck based on the current community card count
            let deck_index = game.community_cards.len() % deck_ids.len();
            let deck_id = *deck_ids.at(deck_index);
            let mut deck: Deck = world.read_model(deck_id);

            // Deal a card from the deck and add to community cards
            let card = deck.deal_card();
            game.community_cards.append(card);

            world
                .emit_event(
                    @CardDealt {
                        game_id: game_id,
                        player_id: get_contract_address(),
                        deck_id: deck.id,
                        time_stamp: get_block_timestamp(),
                        card_suit: card.suit,
                        card_value: card.value,
                    },
                );

            world.write_model(@deck);
            world.write_model(@game);
            game.community_cards
        }

        // @OWK50GA
        // STEP 1: Change dealer/select dealer; this is because each round has a new dealer.
        // Remember the
        //     dealer
        //     choosing algorithm used in this project
        // STEP 2:
        // Initialize pots to take small blind and big blind. The small blind guy is the one
        // immediately next to the dealer (left hand), while the big blind guy is next to the small
        //     blind guy
        // STEP 3:
        // Reset all previous round game variables, including bets and player amounts. Clear round
        // actions as well so that you can record other actions. Also update the current_bet
        //     (minimum players must call to stay in)
        // STEP 4:
        // Shuffle, and then deal hole cards. The function is in this contract already
        // STEP 5:
        // Set player turn, to the player immediately right of the big blind, so that the engine
        //     Knows whose turn it is.
        // STEP 6:
        // Initialize community cards placeholder, and betting counter
        fn _start_round(ref self: ContractState, game_id: u64, ref players: Array<Player>) {
            // Load world and game
            let mut world = self.world_default();
            let mut game: Game = world.read_model(game_id);

            let next_dealer_opt: Option<Player> = self._get_dealer(players.at(0));
            assert(next_dealer_opt.is_some(), 'Dealer not found');
            let next_dealer = next_dealer_opt.unwrap();
            world.write_model(@next_dealer);

            // Get dealer index so that you can assign blinds
            let mut dealer_index = 0;
            let total_players = game.current_player_count;
            let mut i = 0;
            while i < total_players {
                let current_player = players.at(i);
                assert(current_player.is_in_game(game_id), GameErrors::PLAYER_NOT_IN_GAME);
                if current_player == @next_dealer {
                    dealer_index = i;
                    break;
                }
                i += 1;
            };

            // Post blinds now you have dealer index. Player to the left for small blind, right for
            //     big blind.
            // We are taking 0 to length as left to right, so dealer_index - 1 for small blind,
            //     dealer_index + 1 for big blind
            let sb_index = (dealer_index + 1) % total_players;
            let sb_address = players.at(sb_index);

            let mut sb_player: Player = world.read_model(*sb_address);
            let sb_amount = game.params.small_blind;
            sb_player.chips = sb_player.chips - sb_amount.into();
            sb_player.current_bet = sb_amount.into();
            world.write_model(@sb_player);

            let bb_amount = game.params.big_blind;
            game.pot = (sb_amount + bb_amount).into();
            game.current_bet = bb_amount.into();

            // Reset previous game state
            game.round_in_progress = true;
            game.community_cards = array![];
            // set raises remaining back to the maximum number
            // set the game actions taken back to 0

            // Shuffle decks
            for deck_id in game.deck.span() {
                let mut deck: Deck = world.read_model(*deck_id);
                deck.new_deck();
                deck.shuffle();
                world.write_model(@deck);
            };

            // Deal hole cards
            self._deal_hands(ref players);

            // set player turn, to the player immediately right of the big blind, so that the engine
            //     Knows whose turn it is.
            let next_player_index = (sb_index + 1) % total_players;
            let next_player = players.at(next_player_index);
            game.next_player = Option::Some(*next_player.id);

            world.write_model(@game);
            world
                .emit_event(
                    @RoundStarted {
                        game_id,
                        dealer: next_dealer.id,
                        current_game_bet: bb_amount.into(),
                        small_blind_player: sb_player.id,
                        next_player: *next_player.id,
                        no_of_players: players.len(),
                    },
                )
        }

        // extracts the winning hands
        fn _extract_winner(ref self: ContractState) -> (Array<Hand>, Option<Array<Card>>) {
            (array![], Option::None)
        }
    }
}
/// TODO: ALWAYS CHECK THE CURRENT_BET AND THE POT.


