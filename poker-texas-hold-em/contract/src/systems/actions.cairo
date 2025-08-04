/// POKER CONTRACT
#[dojo::contract]
pub mod actions {
    use core::ecdsa::{check_ecdsa_signature, recover_public_key};
    use core::num::traits::Zero;
    use core::poseidon::poseidon_hash_span;
    use dojo::event::EventStorage;
    use dojo::model::{Model, ModelStorage, ModelValueStorage};
    use dojo::world::WorldStorage;
    use poker::models::base::{
        CardDealt, CommunityCardDealt, GameConcluded, GameErrors, GameInitialized, HandCreated,
        HandResolved, Id, PlayerJoined, PlayerLeft, RoundEnded, RoundResolved, RoundStarted,
    };
    use poker::models::card::{Card, CardTrait};
    use poker::models::deck::{Deck, DeckTrait};
    use poker::models::game::{
        Game, GameMode, GameParams, GameStats, GameTrait, Salts, ShowdownType,
    };
    use poker::models::hand::{Hand, HandTrait, Proofs, HandRank};
    use poker::models::player::{Player, PlayerTrait};
    use poker::traits::{game::get_default_game_params, handtrait};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::systems::interface::IActions;
    use crate::utils::deck::verify_game;

    pub const GAME: felt252 = 'GAME';
    pub const DECK: felt252 = 'DECK';
    pub const MAX_NO_OF_CHIPS: u128 = 100000; /// for test, 1 chip = 1 usd.
    pub const DEFAULT_SHOWDOWN_DURATION: u64 = 60 * 6; // five minutes for showdown, default
    // might be changed accordingly based on the number of players

    // fn init() {

    // }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        /// Birdmannn
        fn initialize_game(
            ref self: ContractState, game_params: Option<GameParams>,
        ) -> u64 { // the game is not ownable for now
            // do not submit the original hand.
            let caller: ContractAddress = get_caller_address();
            let mut world = self.world_default();
            let mut player: Player = world.read_model(caller);

            // Ensure the player is not already in a game
            let (is_locked, _) = player.locked;
            assert(!is_locked, GameErrors::PLAYER_ALREADY_LOCKED);

            let game_id: u64 = self.generate_id(GAME);
            let mut game: Game = Default::default();
            game.init(game_params, game_id);
            player.enter(ref game);

            let game_initialized = GameInitialized {
                game_id: game_id,
                player: caller,
                game_params: game.params,
                time_stamp: get_block_timestamp(),
            };

            world.write_model(@game);
            world.write_model(@player);

            world.emit_event(@game_initialized);
            game_id
        }

        /// @Birdmannn
        fn start_round(
            ref self: ContractState,
            game_id: u64,
            deck_root: felt252,
            message: Array<Hand>,
            signature_r: Array<felt252>,
            signature_s: Array<felt252>,
            signature_y_parity: Array<bool>,
            nonce: u64,
        ) {
            // crosscheck that the message.len() == total number of players in the game.
            // assert the game is waiting... that is game.current_round == 0.
            let mut world = self.world_default();
            let mut game: Game = world.read_model(game_id);
            assert(game.current_round == 0, 'GAME NOT WAITING');

            // implement start logic here

            self
                .verify_signature_params(
                    ref world,
                    game_id,
                    message,
                    signature_r,
                    signature_s,
                    signature_y_parity,
                    game.nonce,
                    nonce,
                );

            game.current_round += 1;
            game.round_count += 1;
            let mut players: Array<Player> = world.read_models(game.players.span());
            self._start_round(game_id, ref players);
            world.write_model(@game);
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
                can_start,
            };

            world.emit_event(@player_joined);

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
            let game_id = *player.extract_current_game_id();
            let cb = selector!("current_bet");
            let game_current_bet = world.read_member(Model::<Game>::ptr_from_keys(game_id), cb);

            assert!(
                player.current_bet == game_current_bet,
                "Your bet is not matched with the table. You must call, raise, or fold.",
            );

            self.after_play(player.id);
        }

        /// @dub_zn
        fn call(ref self: ContractState) {
            let mut world = self.world_default();
            let mut player: Player = world.read_model(get_caller_address());
            self.before_play(player.id);

            let game_id = *player.extract_current_game_id();

            let cb = selector!("current_bet");
            let game_current_bet = world.read_member(Model::<Game>::ptr_from_keys(game_id), cb);

            let params_ = selector!("params");
            let pot_ = selector!("pots");
            let mut game_pots: Array<u256> = world
                .read_member(Model::<Game>::ptr_from_keys(game_id), pot_);
            let params: GameParams = world
                .read_member(Model::<Game>::ptr_from_keys(game_id), params_);

            // fix this pot.
            let mut game_pot = *game_pots.at(game_pots.len() - 1);
            let mut amount_to_call: u256 = 0;
            if game_pot == params.small_blind.into() {
                amount_to_call = params.small_blind.into() * 2;
            } else {
                amount_to_call = game_current_bet - player.current_bet;
            }

            assert!(amount_to_call > 0, "Your bet is already equal to the current bet.");

            assert!(player.chips >= amount_to_call, "You don't have enough chips to call.");

            if !self.adjust_stake(game_id, amount_to_call, ref player) {
                player.chips -= amount_to_call;
                player.current_bet += amount_to_call;
                game_pot += amount_to_call;
            }

            let mut updated_game_pots: Array<u256> = ArrayTrait::new();
            let mut i = 0;
            while i != game_pots.len() - 1 {
                updated_game_pots.append(*game_pots.at(i));
                i += 1;
            };
            updated_game_pots.append(game_pot);

            world.write_model(@player);
            // Fixed bug here by replacing game_pot with game_pots @truthixify
            world.write_member(Model::<Game>::ptr_from_keys(game_id), pot_, updated_game_pots);

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

            let game_id = *player.extract_current_game_id();
            let cb = selector!("current_bet");
            let mut game_current_bet = world.read_member(Model::<Game>::ptr_from_keys(game_id), cb);

            let params_ = selector!("params");
            let pot_ = selector!("pots");
            let mut game_pots: Array<u256> = world
                .read_member(Model::<Game>::ptr_from_keys(game_id), pot_);
            let params: GameParams = world
                .read_member(Model::<Game>::ptr_from_keys(game_id), params_);

            assert!(
                no_of_chips > game_current_bet, "Raise amount is less than the game's current bet.",
            );

         // Validate bet spacing - raise amount must be in multiples of bet_spacing @kaylahray
            let bet_spacing = params.bet_spacing;
            // Only the increment after current_bet needs to be multiple of bet_spacing. @kaylahray
            let raise_delta = no_of_chips - game_current_bet;
            assert(
                raise_delta % bet_spacing.into() == 0, 'Invalid raise spacing'
            );

            // adjust this pot accordingly
            let mut game_pot = *game_pots.at(game_pots.len() - 1);

            let amount_to_call = game_current_bet - player.current_bet;
            let total_required = amount_to_call + no_of_chips;
            if game_pot == params.small_blind.into() {
                assert!(no_of_chips > game_pot * 2, "Raise must be > 2x blind.");
            }

            assert!(no_of_chips > 0, "Raise must be > 0.");
            assert!(player.chips >= total_required, "Insufficient chips to raise.");

            if !self.adjust_stake(game_id, amount_to_call, ref player) {
                player.chips -= total_required;
                player.current_bet += total_required;
                game_pot += total_required;
            }

            game_current_bet = player.current_bet;
            // @Kaylahray 👇
           world.write_member(Model::<Game>::ptr_from_keys(game_id), selector!("highest_staker"), Option::Some(player.id));
           
            

            let mut updated_game_pots: Array<u256> = ArrayTrait::new();
            let mut i = 0;
            while i != game_pots.len() - 1 {
                updated_game_pots.append(*game_pots.at(i));
                i += 1;
            };
            updated_game_pots.append(game_pot);

            world.write_model(@player);
            world.write_member(Model::<Game>::ptr_from_keys(game_id), cb, game_current_bet);
            world.write_member(Model::<Game>::ptr_from_keys(game_id), pot_, updated_game_pots);

            self.after_play(player.id);
        }

       
        /// @dub_zn
        fn all_in(ref self: ContractState) {
            let mut world = self.world_default();
            let mut player: Player = world.read_model(get_caller_address());
            self.before_play(player.id);
            // check the previous pot here.
            let game_id: u64 = *player.extract_current_game_id();
            let amount = player.chips;
            
            let cb = selector!("current_bet");
            let game_current_bet = world.read_member(Model::<Game>::ptr_from_keys(game_id), cb);

            // Update player state for all-in   @kaylahray
            player.current_bet += amount;
            player.chips = 0;

            // @kaylahray Set highest_staker if this all-in creates new highest bet
            if player.current_bet > game_current_bet {
                world.write_member(
                    Model::<Game>::ptr_from_keys(game_id), 
                    selector!("highest_staker"), 
                    Option::Some(player.id)
                );
                world.write_member(
                    Model::<Game>::ptr_from_keys(game_id), 
                    cb, 
                    player.current_bet
                );
            }

            // Handle side pot creation if needed
            if amount < game_current_bet {
                self.adjust_pot(game_id, ref player, game_current_bet);
            }
            
            world.write_model(@player);
            self.after_play(player.id);
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

        /// @Birdmannn
        fn deal_community_card(
            ref self: ContractState, card: Card, game_id: u64,
        ) { // verify signature on this function too. in the future
            // the caller of this function must have some amount of money staked in the game
            // if the showdown fails to be verified, then the stake is gone.
            let mut world = self.world_default();
            let mut c_deal: bool = world
                .read_member(Model::<Game>::ptr_from_keys(game_id), selector!("community_dealing"));
            let mut community_cards: Array<Card> = world
                .read_member(Model::<Game>::ptr_from_keys(game_id), selector!("community_cards"));
            assert(c_deal && community_cards.len() <= 5, 'INVALID DEALING');
            community_cards.append(card);
            world
                .write_member(
                    Model::<Game>::ptr_from_keys(game_id),
                    selector!("community_cards"),
                    community_cards.clone(),
                );
            if community_cards.len() > 2 {
                c_deal = false;
            }
            world
                .write_member(
                    Model::<Game>::ptr_from_keys(game_id), selector!("community_dealing"), c_deal,
                );

            let event = CommunityCardDealt { game_id, card };
            world.emit_event(@event);
        }

        /// @Birdmannn
        /// This function takes in a hand that contains hashed cards. When the Game uses a showdown
        /// type of `Splitted`, the SALT is never revealed, and the game is never "verified"
        /// TODO: In the future, the owner of the game would be forced to stake a huge amount
        /// when initializing the game, and also be forced to submit all game proofs after each
        /// round.
        fn submit_hand(ref self: ContractState, hand: Hand, proof: Array<Array<felt252>>) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let mut player: Player = world.read_model(caller);
            let game_id = *player.extract_current_game_id();

            assert(player.in_round, 'PLAYER NOT IN ROUND');
            let mut game: Game = world.read_model(game_id);

            assert(game.in_progress, GameErrors::GAME_NOT_IN_PROGRESS);
            assert(game.round_in_progress, GameErrors::ROUND_NOT_IN_PROGRESS);
            assert!(
                game.params.showdown_type != ShowdownType::Gathered,
                "INVALID CALL FOR GAME
                PARAMS",
            );

            let rt = selector!("round_end_time");
            let end_time = world.read_member(Model::<GameStats>::ptr_from_keys(game_id), rt);
            let duration = end_time + DEFAULT_SHOWDOWN_DURATION;
            assert(get_block_timestamp() <= duration, 'DURATION EXCEEDED');

            // When all hands have been counted and are complete, call the resolve_game_v2,
            // and adjust the function. to tally all hands and rank them
            assert(hand.player == caller, 'HAND ID NOT CALLER');
            world.write_model(@hand);
            let proof = Proofs { player: hand.player, proof };
            world.write_model(@proof);
        }

        fn compute_round(ref self: ContractState, game_id: u64, salt: Array<felt252>) {}

        /// @Birdmannn, @augustin-v
        fn showdown(
            ref self: ContractState,
            game_id: u64,
            hands: Array<Hand>,
            game_proofs: Array<Array<felt252>>,
            dealt_card_proofs: Array<Array<felt252>>,
            deck: Deck,
            game_salt: Array<felt252>,
            dealt_card_salt: Array<felt252>,
            signature_r: Array<felt252>,
            signature_s: Array<felt252>,
            signature_y_parity: Array<bool>, // to recover the public key
            nonce: u64,
        ) {
            let (g, d) = (game_salt, dealt_card_salt);
            assert(g.len() == 3 && d.len() == 3, 'INVALID SALT');

            let mut world = self.world_default();
            let mut game: Game = world.read_model(game_id);
            assert(game.showdown, 'INVALID CALL'); // check the position of this line.
            let game_nonce = game.nonce;
            game.nonce += 1;
            self
                .verify_signature_params(
                    ref world,
                    game_id,
                    hands.clone(),
                    signature_r,
                    signature_s,
                    signature_y_parity,
                    game_nonce,
                    nonce,
                );
            world.write_model(@game);

            let g_key = (*g.at(0), *g.at(1), *g.at(2));
            let d_key = (*d.at(0), *d.at(1), *d.at(2));
            let mut G: Salts = world.read_model(g_key);
            let mut D: Salts = world.read_model(d_key);
            assert(!game.has_ended, GameErrors::GAME_ALREADY_ENDED);
            // write the salt to invalidate. A wrong showdown disqualifies the whole game if
            // actually any of the salts were valid.
            world.write_member(Model::<Salts>::ptr_from_keys(g_key), selector!("used"), true);
            world.write_member(Model::<Salts>::ptr_from_keys(d_key), selector!("used"), true);
            assert(!G.used && !D.used, 'INVALID SALT');
            assert(game.round_in_progress && game.community_cards.len() == 5, 'BAD REQUEST');

            let (mut gp, mut dcp, mut dc) = (game_proofs, dealt_card_proofs, deck);
            let deck_root: felt252 = game.deck_root;
            let dealt_root: felt252 = game.dealt_cards_root;
            // for now, the game houses the community cards. This will be changed.
            let community_cards: Array<Card> = game.community_cards.clone();

            let verified: bool = verify_game(
                community_cards.clone(), hands.clone(), gp, dcp, dc, deck_root, dealt_root, g, d,
            );

            self._resolve_round_v2(game_id, hands, community_cards, verified);
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

        fn resolve_round(
            ref self: ContractState, game_id: u64,
        ) { // self._resolve_round_v2(game_id);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Use the default namespace "poker". This function is handy since the ByteArray
        /// can't be const.
        fn world_default(self: @ContractState) -> WorldStorage {
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

        fn adjust_stake(
            ref self: ContractState, game_id: u64, mut amount: u256, ref player: Player,
        ) -> bool {
            // This function would be used only for stakes greater than the game's current bet
            // matches the previous pot, and adds the remainder to the current pot
            let mut world = self.world_default();
            let pot_ = selector!("pots");
            let po = selector!("previous_offset");
            let mut game_pots: Array<u256> = world
                .read_member(Model::<Game>::ptr_from_keys(game_id), pot_);
            if player.eligible_pots.into() < game_pots.len() {
                // adjust previous pot and new pot, then proceed.
                // increment player's eligible pots, if applicable
                let index = player.eligible_pots.into() - 1;
                let mut previous_pot = *game_pots.at(index);
                // adjust with offset
                let previous_offset = world.read_member(Model::<Game>::ptr_from_keys(game_id), po);
                player.chips -= amount;
                amount -= previous_offset;
                previous_pot += previous_offset;

                let mut current_pot = *game_pots.at(game_pots.len() - 1);
                current_pot += amount;

                let game_pots_ = self.refresh_pots(game_pots, index, previous_pot, current_pot);
                world.write_member(Model::<Game>::ptr_from_keys(game_id), pot_, game_pots_);
                player.eligible_pots += 1;
                world.write_model(@player);
                return true;
            }
            false
        }

        fn adjust_pot(
            ref self: ContractState, game_id: u64, ref player: Player, game_current_bet: u256,
        ) {
            let mut world = self.world_default();
            let pot_ = selector!("pots");
            let p = selector!("players");
            let po = selector!("previous_offset");
            let mut game_pots: Array<u256> = world
                .read_member(Model::<Game>::ptr_from_keys(game_id), pot_);
            let game_players: Array<ContractAddress> = world
                .read_member(Model::<Game>::ptr_from_keys(game_id), p);

            let mut target_index = 0;
            let mut current_pot = *game_pots.at(game_pots.len() - 1);
            let amount = player.chips;
            // we are only adjusting the current pot, and resolving the next pot for the betting

            // let offset = game_current_bet - amount;
            // all player's current bet must match then, then create a new pot
            let stmt = player.eligible_pots.into() == game_pots.len();
            let mut new_pot_: bool = false;
            let mut new_pot: u256 = if stmt {
                new_pot_ = true;
                0
            } else {
                current_pot
            };

            if !stmt {
                target_index = player.eligible_pots.into() - 1;
                current_pot = *game_pots.at(target_index); // === game.pots.len() - 2
            }

            player.current_bet += amount;
            player.chips = 0;
            let players: Array<Player> = world.read_models(game_players.span());

            for i in 0..players.len() {
                let mut pp = *players.at(i);
                if pp.is_in_game(game_id)
                    && pp.in_round
                    && pp.eligible_pots.into() == game_pots.len() {
                    if pp.current_bet > player.current_bet {
                        let offset = pp.current_bet - player.current_bet;
                        // subtract the offset from the pot, and update state accordingly
                        current_pot -= offset;
                        new_pot += offset;
                        // NOTE:
                        // pp.current_bet = offset; This line is commented out to avoid
                        // miscalculation and loss of funds during the `call` operation. If it is to
                        // be used in the future by any means, then the `call` function must be
                        // adjusted appropriately.
                        pp.eligible_pots += 1;
                        world.write_model(@pp);
                        world.write_member(Model::<Game>::ptr_from_keys(game_id), po, offset);
                    }
                }
            };

            if new_pot_ {
                game_pots.append(new_pot);
            } else {
                // resolve pot at that index.
                game_pots = self.refresh_pots(game_pots, target_index, current_pot, new_pot);
            }
            // This doesn't go with what is expected in test
            // player.current_bet = 0; // the player is maxed out. This value is used for checks.

            world.write_member(Model::<Game>::ptr_from_keys(game_id), pot_, game_pots);
        }

        fn refresh_pots(
            ref self: ContractState,
            game_pots: Array<u256>,
            target_index: u32,
            current_pot: u256,
            new_pot: u256,
        ) -> Array<u256> {
            let mut game_pots_ref = array![];
            for i in 0..game_pots.len() {
                if i == target_index {
                    game_pots_ref.append(current_pot);
                    game_pots_ref.append(new_pot);
                    break; // usually the last two. break afterwards
                }
                game_pots_ref.append(*game_pots.at(i));
            };
            game_pots_ref
        }

        fn verify_signature_params(
            ref self: ContractState,
            ref world: WorldStorage,
            game_id: u64,
            hands: Array<Hand>,
            signature_r: Array<felt252>,
            signature_s: Array<felt252>,
            signature_y_parity: Array<bool>, // to recover the public key
            game_nonce: u64,
            nonce: u64,
        ) {
            // @augustin-v: verify signatures here
            let hands_len: u32 = hands.len();
            assert(signature_r.len() == hands_len, 'SIGNATURE R LENGTH MISMATCH');
            assert(signature_s.len() == hands_len, 'SIGNATURE S LENGTH MISMATCH');
            // for array bounds safety
            assert(signature_y_parity.len() == hands_len, 'SIGNATURE Y_PARITY LEN MISMATCH');

            assert(nonce == game_nonce, 'INVALID NONCE');

            // increment nonce to prevent replay attacks
            let mut i: u32 = 0;
            while i < hands_len {
                let hand: @Hand = hands.at(i);
                let r: felt252 = *signature_r.at(i);
                let s: felt252 = *signature_s.at(i);
                let y_parity: bool = *signature_y_parity.at(i);

                // message hash: Poseidon hash of hand + nonce
                let mut hash_input: Array<felt252> = array![];
                hand.serialize(ref hash_input);
                hash_input.append(nonce.into());
                let message_hash: felt252 = poseidon_hash_span(hash_input.span());

                // Recover public key as felt252
                let recovered_pubkey: Option<felt252> = recover_public_key(
                    message_hash, r, s, y_parity,
                );
                assert(recovered_pubkey.is_some(), 'SIGNATURE RECOVERY FAILED');
                let pubkey_felt: felt252 = recovered_pubkey.unwrap();

                // get player address from hand's player
                let player: Player = world.read_model(*hand.player);
                // compare recovered pubkey with stored pub_key
                assert(pubkey_felt == player.pub_key, 'INVALID PUB KEY');

                // verify player is in current game and in round
                assert(player.in_round && player.is_in_game(game_id), 'PLAYER NOT IN ROUND');

                // verify ECDSA signature as additional check
                let signature_valid: bool = check_ecdsa_signature(
                    message_hash, player.pub_key, r, s,
                );
                assert(signature_valid, 'INVALID SIGNATURE');

                i += 1;
            };
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
            assert(!game.community_dealing, 'INVALID CALL');

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

              /// @Reentrancy, @Birdmannn
        fn after_play(ref self: ContractState, caller: ContractAddress) {
            let mut world = self.world_default();
            let mut player: Player = world.read_model(caller);
            let (is_locked, game_id) = player.locked;

            // Ensure the player is in a game
            assert(is_locked, 'Player not in game');

            let mut game: Game = world.read_model(game_id);

            // Check if all community cards are dealt (5 cards in Texas Hold'em)
            if game.community_cards.len() == 5 {
                game.showdown = true;
            }

            // Find the caller's index in the players array
            let current_index_option: Option<usize> = self.find_player_index(@game.players, caller);
            assert(current_index_option.is_some(), 'Caller not in game');
            let current_index: usize = OptionTrait::unwrap(current_index_option);

            // Update game state with the player's action
            if player.current_bet > game.current_bet {
                game.current_bet = player.current_bet; // Raise updates the current bet
                game.highest_staker = Option::Some(caller);
            }

            // Write player state to storage BEFORE checking betting round completion
            world.write_model(@player);

            // Determine the next active player
            let next_player_option: Option<ContractAddress> = self
                .find_next_active_player(@game.players, current_index, @world);

            if next_player_option.is_none() {
                // No active players remain, resolve the round
                game.showdown = true;
            } else {
                game.next_player = next_player_option;
                
                // Check if betting round is complete (more gas efficient) @kaylahray
                if self.is_betting_round_complete(@game, @world) {
                    // Reset betting state efficiently
                    self.reset_betting_round(game_id, ref game, ref world);
                }
            }

            world.write_model(@game);

            if game.showdown {
                let timestamp = get_block_timestamp();
                let round_number = game.round_count;
                let no_of_players = game.current_player_count;
                let event = RoundEnded { game_id, timestamp, round_number, no_of_players };
                world
                    .write_member(
                        Model::<GameStats>::ptr_from_keys(game_id),
                        selector!("round_end_time"),
                        timestamp,
                    );
                world.emit_event(@event);
            }
        }

        /// betting round completion check @kaylahray
        fn is_betting_round_complete(
            self: @ContractState, 
            game: @Game, 
            world: @dojo::world::WorldStorage
        ) -> bool {
            let mut all_equal_bets = true;
            let mut active_players = 0_u32;
            
            // Single pass through players to check betting status  @kaylahray
            for player_addr in game.players.span() {
                let p: Player = world.read_model(*player_addr);
                if p.in_round {
                    active_players += 1;
                    if p.current_bet != *game.current_bet {
                        all_equal_bets = false;
                        break;
                    }
                }
            };

            // @kaylahray Betting round complete if all active players have equal bets and the game bet is not zero
            all_equal_bets && active_players > 1 && *game.current_bet > 0
        }

        /// @kaylahray batch reset of betting round
        fn reset_betting_round(
            ref self: ContractState,
            game_id: u64,
            ref game: Game,
            ref world: WorldStorage
        ) {
            // Reset game state
            game.highest_staker = Option::None;
            game.current_bet = 0;
            
            // Determine next phase
            if game.community_cards.len() == 5 {
                game.showdown = true;
            } else {
                game.community_dealing = true;
            }
            
            // Batch reset all players' current_bet using write_member for better gas efficiency
            for player_addr in game.players.span() {
                world.write_member(
                    Model::<Player>::ptr_from_keys(*player_addr),
                    selector!("current_bet"),
                    0_u256
                );
            }
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

        fn _resolve_round_v2(
            ref self: ContractState,
            game_id: u64,
            hands: Array<Hand>,
            community_cards: Array<Card>,
            verified: bool,
        ) {
            let mut world = self.world_default();
            let mut game: Game = world.read_model(game_id);
            assert(game.in_progress, GameErrors::GAME_NOT_IN_PROGRESS);
            assert(game.round_in_progress, GameErrors::ROUND_NOT_IN_PROGRESS);

            // if !verified && game.params.showdown_type == ShowdownType::Splitted { // deduct
            // funds. but first we need to initialize the game properly.
            // probably refresh the stake here.
            //     // TODO: Implement things that should be done only when the `submit_card`
            //     endpoint is called.
            //     // de
            // TODO: WE WILL USE THIS PARTICULAR LOGIC DURING THE `SUBMIT_CARD`

            // // Collect players with valid hands, skipping those with empty hands
            // let mut valid_players: Array<Player> = array![];
            // let mut all_player_addresses: Array<ContractAddress> = array![];

            // for player_address in game.players.span() {
            //     let player: Player = world.read_model(*player_address);
            //     let hand: Hand = world.read_model(*player_address);
            //     all_player_addresses.append(*player_address);

            //     // Skip players with empty hands (they didn't submit cards)
            //     if hand.cards.len() == 0 {
            //         continue;
            //     }
            //     valid_players.append(player);
            // };

            // assert(valid_players.len() > 0, 'No valid hands to resolve round');
            // }  OR PUT THIS FUNCTION IN THE SUBMIT_CARD DIRECTLY

            // // Update game state for the next round
            game.current_round += 1;
            game.round_in_progress = false;
            game.community_cards = array![];
            game.current_bet = 0;
            game.showdown = false;

            game.deck_root = 0;
            game.dealt_cards_root = 0;
            world.write_model(@game);

            let can_join = game.is_allowable();
            // if game.should_end {
            //     self._resolve_game(ref game, get_contract_address(), false);
            // }

            // Reset player states for ALL players (not just valid ones)
            for player_address in game.players.span() {
                let mut player: Player = world.read_model(*player_address);
                if player.is_in_game(game_id) && player.refresh_stake(ref game) {
                    player.current_bet = 0;
                    player.in_round = true;
                    player.eligible_pots = 0;
                    world.write_model(@player);
                }
            };

            let (winning_hands, _, _) = self._extract_winner(game_id, community_cards, hands);
            let mut winners = array![];
            for i in 0..winning_hands.len() {
                let winner = winning_hands.at(i);
                winners.append(*winner.player);
            };

            let mut tpot = 0; // total pot
            for pot in game.pots {
                tpot += pot;
            };

            let round_resolved = RoundResolved {
                game_id: game_id, can_join: can_join, winners: winners, pot: tpot,
            };
            world.emit_event(@round_resolved);
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

            let dealer_opt: Option<Player> = self._get_dealer(players.at(0));
            assert(dealer_opt.is_some(), 'Dealer not found');
            let dealer = dealer_opt.unwrap();
            world.write_model(@dealer);

            // Get dealer index so that you can assign blinds
            let mut dealer_index = 0;
            let total_players = game.current_player_count;
            let mut i = 0;
            while i < total_players {
                let current_player = players.at(i);
                assert(
                    current_player.is_in_game(game_id) && *current_player.in_round,
                    GameErrors::PLAYER_NOT_IN_GAME,
                );
                if current_player == @dealer {
                    dealer_index = i;
                    break;
                }
                i += 1;
            };

            // player to the right, small blind, then that's all.
            // set the next_player accordingly
            let sb_index = (dealer_index + 1) % total_players;
            let sb_address = players.at(sb_index);

            let mut sb_player: Player = world.read_model(*sb_address);
            let sb_amount = game.params.small_blind;
            sb_player.chips = sb_player.chips - sb_amount.into();
            sb_player.current_bet = sb_amount.into();
            world.write_model(@sb_player);

            game.pots = array![sb_amount.into()];

            // Reset previous game state
            game.round_in_progress = true;
            game.community_cards = array![];
            // set raises remaining back to the maximum number
            // set the game actions taken back to 0

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
                        dealer: dealer.id,
                        current_game_bet: sb_amount.into(),
                        small_blind_player: sb_player.id,
                        next_player: *next_player.id,
                        no_of_players: players.len(),
                    },
                )
        }

        // @ryzen_xp
        // extracts the winning hands
        fn _extract_winner(
            ref self: ContractState, game_id: u64, community_cards: Array<Card>, hands: Array<Hand>,
        ) -> (Span<Hand>, HandRank, Span<Card>) {
            let mut world = self.world_default();
            let game: Game = world.read_model(game_id);
            let game_params = game.params;

            HandTrait::compare_hands(hands, community_cards, game_params)
        }
    }
}
/// TODO: ALWAYS CHECK THE CURRENT_BET AND THE POT.


