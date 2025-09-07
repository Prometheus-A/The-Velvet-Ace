#[cfg(test)]
pub mod tests {
    use dojo::event::EventStorageTest;
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
    use dojo::world::{WorldStorage, WorldStorageTrait};
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };
    use poker::models::game::{Game, GameTrait, GameParams, ShowdownType, Salts};
    use poker::models::deck::Deck;
    use poker::models::hand::Hand;
    use poker::traits::deck::DeckTrait;
    use poker::traits::handimpl::HandTrait;
    use poker::models::player::{Player, PlayerTrait};
    use poker::models::card::{Card, Suits, Royals};
    use poker::traits::game::get_default_game_params;
    use poker::systems::interface::{IActionsDispatcher, IActionsDispatcherTrait};
    use poker::tests::setup::setup::{CoreContract, deploy_contracts, Systems};
    use poker::utils::game::{MerkleState, MerkleTrait};
    use starknet::ContractAddress;
    use starknet::testing::{set_account_contract_address, set_contract_address};

    pub fn PLAYER_1() -> ContractAddress {
        starknet::contract_address_const::<'PLAYER_1'>()
    }

    pub fn PLAYER_2() -> ContractAddress {
        starknet::contract_address_const::<'PLAYER_2'>()
    }

    pub fn PLAYER_3() -> ContractAddress {
        starknet::contract_address_const::<'PLAYER_3'>()
    }

    pub fn PLAYER_4() -> ContractAddress {
        starknet::contract_address_const::<'PLAYER_4'>()
    }

    pub fn SHOWODWN_PLAYER1() -> ContractAddress {
        starknet::contract_address_const::<
            0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2,
        >()
    }

    pub fn SHOWODWN_PLAYER2() -> ContractAddress {
        starknet::contract_address_const::<
            0x4ae6af1665641e0745203aeb5bbd24674094d56914618aaae131402de9f81de,
        >()
    }

    // Flexible player mock
    pub fn mock_player(
        id: ContractAddress,
        alias: felt252,
        chips: u256,
        current_bet: u256,
        total_rounds: u64,
        locked: (bool, u64),
        is_dealer: bool,
        in_round: bool,
        out: (u64, u64),
    ) -> Player {
        let mut player: Player = Default::default();
        player.id = id;
        player.alias = alias;
        player.chips = chips;
        player.current_bet = current_bet;
        player.total_rounds = total_rounds;
        player.locked = locked;
        player.is_dealer = is_dealer;
        player.in_round = in_round;
        player.out = out;
        player.locked_chips = 0;
        player.eligible_pots = 1;

        player
    }

    // Flexible game mock
    pub fn mock_poker_game_flex(
        ref world: WorldStorage,
        in_progress: bool,
        has_ended: bool,
        current_round: u8,
        round_in_progress: bool,
        current_player_count: u32,
        players: Array<ContractAddress>,
        next_player: Option<ContractAddress>,
        community_cards: Array<Card>,
        current_bet: u256,
        player_states: Array<Player>,
    ) {
        let temp_player_states = player_states.span();
        let mut player_states = array![];
        for player in temp_player_states {
            player_states.append(player);
        };

        let mut game: Game = Default::default();
        game.id = 1;
        game.in_progress = in_progress;
        game.has_ended = has_ended;
        game.current_round = current_round;
        game.round_in_progress = round_in_progress;
        game.current_player_count = current_player_count;
        game.players = players;
        game.next_player = next_player;
        game.pots = array![0];
        game.current_bet = current_bet;
        game.params = get_default_game_params();
        world.write_model(@game);
        world.write_models(player_states.span());
    }

    // [Actions] - check() tests
    #[test]
    fn test_check_succeeds_when_player_current_bet_equals_game() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // [Setup State]
        let mut game: Game = world.read_model(1);
        game.current_bet = 1000;
        world.write_model(@game);

        let mut player_1: Player = world.read_model(PLAYER_1());
        player_1.current_bet = 1000;
        world.write_model(@player_1);

        set_contract_address(player_1.id);

        // [Execute]
        systems.actions.check();

        // [Assert]
        let game: Game = world.read_model(1);
        assert_eq!(game.current_bet, 1000, "Game current bet should remain 1000");
        assert_eq!(game.next_player, Option::Some(PLAYER_2()), "Next player should be PLAYER_2");
    }

    #[test]
    #[should_panic(
        expected: (
            "Your bet is not matched with the table. You must call, raise, or fold.",
            'ENTRYPOINT_FAILED',
        ),
    )]
    fn test_check_fails_when_player_has_not_equal_bet() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // [Setup State]
        let mut game: Game = world.read_model(1);
        game.current_bet = 1000;
        world.write_model(@game);

        let mut player_1: Player = world.read_model(PLAYER_1());
        player_1.current_bet = 1001;
        world.write_model(@player_1);

        set_contract_address(player_1.id);

        // [Execute]
        systems.actions.check();
    }

    #[test]
    #[should_panic(expected: ('Not player turn', 'ENTRYPOINT_FAILED'))]
    fn test_check_fails_when_not_players_turn() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // [Execute]
        // PLAYER_2 trying to play when it's PLAYER_1's turn
        set_contract_address(PLAYER_2());
        systems.actions.check();
    }

    #[test]
    fn test_check_skips_folded_players() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // [Setup State]
        let mut game: Game = world.read_model(1);
        game.current_bet = 1000;
        world.write_model(@game);

        // PLAYER_2 has folded
        let mut player_2: Player = world.read_model(PLAYER_2());
        player_2.in_round = false;
        world.write_model(@player_2);

        // Set PLAYER_1 current_bet to match game
        let mut player_1: Player = world.read_model(PLAYER_1());
        player_1.current_bet = 1000;
        world.write_model(@player_1);

        set_contract_address(PLAYER_1());

        // [Execute]
        systems.actions.check();

        // [Assert]
        let game: Game = world.read_model(1);
        assert_eq!(
            game.next_player,
            Option::Some(PLAYER_3()),
            "Next player should skip folded PLAYER_2 and go to PLAYER_3",
        );
    }

    #[test]
    #[should_panic(expected: ('Player not active in round', 'ENTRYPOINT_FAILED'))]
    fn test_check_fails_if_player_not_in_round() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // [Setup State]
        // PLAYER_1 is not in round
        let mut player_1: Player = world.read_model(PLAYER_1());
        player_1.in_round = false;
        world.write_model(@player_1);

        set_contract_address(PLAYER_1());

        // [Execute]
        systems.actions.check();
    }

    // [Actions] - call() tests
    #[test]
    fn test_call_succeeds_with_correct_amount() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // [Setup State]
        let mut game: Game = world.read_model(1);
        game.current_bet = 1000;
        world.write_model(@game);

        let mut player_1: Player = world.read_model(PLAYER_1());
        player_1.current_bet = 200;
        player_1.chips = 2000;
        world.write_model(@player_1);

        // [Execute]
        set_contract_address(PLAYER_1());
        systems.actions.call();

        // [Assert]
        let updated_player: Player = world.read_model(PLAYER_1());
        assert!(
            updated_player.current_bet == 1000, "player.current_bet should match game.current_bet",
        );
        assert!(updated_player.chips == 1200, "player.chips should be reduced by called amount");

        let updated_game: Game = world.read_model(1);
        assert!(
            updated_game.next_player == Option::Some(PLAYER_2()), "next_player should be PLAYER_2",
        );
        assert!(
            *updated_game.pots.at(0) == 800, "game.pot should be increased by the amount called",
        );
    }

    #[test]
    #[should_panic(expected: ("You don't have enough chips to call.", 'ENTRYPOINT_FAILED'))]
    fn test_call_fails_if_player_has_insufficient_chips() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // [Setup State]
        let mut game: Game = world.read_model(1);
        game.current_bet = 1000;
        world.write_model(@game);

        let mut player_1: Player = world.read_model(PLAYER_1());
        player_1.current_bet = 200;
        player_1.chips = 300;
        world.write_model(@player_1);

        // [Execute]
        set_contract_address(PLAYER_1());
        systems.actions.call();
    }

    #[test]
    #[should_panic(expected: ('Not player turn', 'ENTRYPOINT_FAILED'))]
    fn test_call_fails_when_not_players_turn() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // [Execute]
        // It's player 1's turn, but we try with player 2
        set_contract_address(PLAYER_2());
        systems.actions.call();
    }

    // [Actions] - fold() tests
    #[test]
    fn test_fold_sets_in_round_to_false() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // [Setup State]
        set_contract_address(PLAYER_1());
        systems.actions.fold();

        // [Assert]
        let updated_player: Player = world.read_model(PLAYER_1());
        assert!(!updated_player.in_round, "Player should be out of round after fold");

        let updated_game: Game = world.read_model(1);
        assert!(
            updated_game.next_player == Option::Some(PLAYER_2()),
            "Next player should be PLAYER_2 after fold",
        );
    }

    // [Actions] - raise() tests
    #[test]
    fn test_raise_increases_bet_and_chips_correctly() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // [Setup State]
        let mut game: Game = world.read_model(1);
        game.current_bet = 1000;
        world.write_model(@game);

        // Set up the player with a partial bet
        let mut player_1: Player = world.read_model(PLAYER_1());
        player_1.current_bet = 200;
        player_1.chips = 2000;
        world.write_model(@player_1);

        // [Execute]
        set_contract_address(PLAYER_1());
        let raise_amount = 1200;
        systems.actions.raise(raise_amount);

        // [Assert]
        let updated_player: Player = world.read_model(PLAYER_1());
        assert!(
            updated_player.current_bet == 1000 + raise_amount,
            "Player's bet should match game.current_bet + raise",
        );
        assert!(
            updated_player.chips == 2000 - 800 - raise_amount,
            "Player's chips should decrease by amount_to_call + raise",
        );

        let updated_game: Game = world.read_model(1);
        assert!(
            updated_game.current_bet == 1000 + raise_amount,
            "Game's current bet should be updated after raise",
        );
        assert!(
            *updated_game.pots.at(0) == 800 + raise_amount,
            "Pot should include called amount + raise",
        );
        assert!(
            updated_game.next_player == Option::Some(PLAYER_2()),
            "Next player should be PLAYER_2 after raise",
        );
    }

    // [Actions] - all_in() tests
    #[test]
    #[ignore]
    fn test_all_in_sets_chips_to_zero_and_increases_current_bet() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // [Setup State]
        let mut game: Game = world.read_model(1);
        game.current_bet = 2000;
        world.write_model(@game);

        let mut player_1: Player = world.read_model(PLAYER_1());
        player_1.chips = 1500;
        world.write_model(@player_1);

        // [Execute]
        set_contract_address(PLAYER_1());
        systems.actions.all_in();

        // [Assert]
        let updated_player: Player = world.read_model(PLAYER_1());
        assert!(updated_player.chips == 0, "All-in should reduce player's chips to zero");
        assert!(
            updated_player.current_bet == 1500,
            "Player's current bet should increase by all-in amount",
        );

        let updated_game: Game = world.read_model(1);
        assert!(
            *updated_game.pots.at(updated_game.pots.len() - 1) == 1500,
            "Pot should include the all-in amount",
        );
        assert!(
            updated_game.next_player == Option::Some(PLAYER_2()),
            "Next player should be PLAYER_2 after all-in",
        );
    }

    // [Betting Logic Tests] - Testing highest staker and bet reset functionality @kaylahray
    #[test]
    fn test_highest_staker_and_bet_reset() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // Player 1 (PLAYER_1) raises @kaylahray
        let mut game: Game = world.read_model(1);
        let raise_amount = game.params.small_blind * 4; // Example raise = 40
        set_contract_address(PLAYER_1());
        systems.actions.raise(raise_amount.into());

        // Check that highest_staker is set correctly
        game = world.read_model(1);
        assert!(game.highest_staker.is_some(), "Highest staker not set on raise");
        assert_eq!(game.highest_staker.unwrap(), PLAYER_1(), "Incorrect highest staker");
        assert_eq!(game.current_bet, raise_amount.into(), "Game bet not updated on raise");

        // Player 2 calls - should match game.current_bet
        set_contract_address(PLAYER_2());
        systems.actions.call();

        // Check player 2 state after call
        let player_2_after_call: Player = world.read_model(PLAYER_2());
        assert_eq!(
            player_2_after_call.current_bet, raise_amount.into(), "Player 2 didn't call correctly",
        );

        // Check if betting round completion would be detected at this point
        game = world.read_model(1);
        let player_1_mid: Player = world.read_model(PLAYER_1());
        // At this point: player1=40, player2=40, player3=0, game=40
        // So betting round should NOT be complete yet

        // Player 3 calls - this should complete the betting round and reset state
        set_contract_address(PLAYER_3());
        systems.actions.call();

        // Check all player states immediately after the call
        game = world.read_model(1);
        let player_1: Player = world.read_model(PLAYER_1());
        let player_2: Player = world.read_model(PLAYER_2());
        let player_3: Player = world.read_model(PLAYER_3());

        // At this point, all players should have current_bet = 40, game.current_bet = 40
        // The betting round should be complete and reset should have happened
        assert!(game.highest_staker.is_none(), "Highest staker not reset");
        assert_eq!(game.current_bet, 0, "Game current bet not reset");
        assert_eq!(player_1.current_bet, 0, "Player 1 bet not reset");
        assert_eq!(player_2.current_bet, 0, "Player 2 bet not reset");
        assert_eq!(player_3.current_bet, 0, "Player 3 bet not reset");
    }

    // @kaylahray Testing bet spacing logic
    #[test]
    #[should_panic(expected: ('Invalid raise spacing', 'ENTRYPOINT_FAILED'))]
    fn test_bet_spacing_fail() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        let game: Game = world.read_model(1);
        // Not a multiple of bet_spacing (which is small_blind)
        let raise_amount = game.params.small_blind * 2 + 1;
        set_contract_address(PLAYER_1());
        systems.actions.raise(raise_amount.into());
    }
    // @kaylahray Testing bet spacing success
    #[test]
    fn test_bet_spacing_success() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        let game: Game = world.read_model(1);
        let raise_amount = game.params.small_blind * 4; // 40 is multiple of bet_spacing (20)
        set_contract_address(PLAYER_1());
        systems.actions.raise(raise_amount.into());

        let updated_game: Game = world.read_model(1);
        assert_eq!(updated_game.current_bet, raise_amount.into(), "Bet spacing success failed");
    }
    //   @kaylahray Testing all-in sets highest staker
    #[test]
    fn test_all_in_sets_highest_staker() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // Player 1 goes all-in
        set_contract_address(PLAYER_1());
        systems.actions.all_in();

        let game: Game = world.read_model(1);
        let player_1: Player = world.read_model(PLAYER_1());

        assert!(game.highest_staker.is_some(), "Highest staker not set on all-in");
        assert_eq!(game.highest_staker.unwrap(), player_1.id, "Incorrect highest staker on all-in");
        assert_eq!(game.current_bet, player_1.current_bet, "Game bet not updated on all-in");
        assert_eq!(player_1.chips, 0, "Player should have 0 chips after all-in");
    }

    // @kaylahray Testing all-in works regardless of bet spacing
    #[test]
    fn test_all_in_ignores_bet_spacing() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // Set up game with bet_spacing requirement (default is small_blind = 10)
        let game: Game = world.read_model(1);
        let bet_spacing = game.params.bet_spacing; // Default is 20

        // Set player's chips to an amount that's NOT a multiple of bet_spacing
        let mut player_1: Player = world.read_model(PLAYER_1());
        player_1.chips = 135; // 135 % 20 = 15, so NOT a multiple of bet_spacing
        world.write_model(@player_1);

        // Set game current_bet to 0 for simplicity
        let mut game_updated: Game = world.read_model(1);
        game_updated.current_bet = 0;
        world.write_model(@game_updated);

        // [Execute] - All-in should succeed regardless of bet spacing
        set_contract_address(PLAYER_1());
        systems.actions.all_in();

        // [Assert] - All-in worked despite chips not being multiple of bet_spacing
        let updated_player: Player = world.read_model(PLAYER_1());
        let updated_game: Game = world.read_model(1);

        assert_eq!(updated_player.chips, 0, "Player chips should be 0 after all-in");
        assert_eq!(
            updated_player.current_bet, 135, "Player current_bet should equal all-in amount",
        );
        assert_eq!(
            updated_game.current_bet, 135, "Game current_bet should be updated to all-in amount",
        );
        assert!(updated_game.highest_staker.is_some(), "Highest staker should be set");
        assert_eq!(
            updated_game.highest_staker.unwrap(), PLAYER_1(), "Highest staker should be PLAYER_1",
        );
    }

    // @kaylahray Community dealing tests - Testing community card dealing functionality
    #[test]
    fn test_community_dealing_after_betting_round() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // Complete a betting round
        feign_betting_round(ref world, systems.actions);

        // Check that community_dealing is enabled after betting round completion
        let game_after_betting: Game = world.read_model(1);
        assert!(
            game_after_betting.community_dealing,
            "Community dealing should be enabled after betting round",
        );

        // Now deal three community cards (the flop)
        let card1 = Card { suit: 4, value: 1 }; // Hearts Ace
        let card2 = Card { suit: 1, value: 13 }; // Spades King
        let card3 = Card { suit: 3, value: 12 }; // Diamonds Queen

        systems.actions.deal_community_card(card1, 1);
        systems.actions.deal_community_card(card2, 1);
        systems.actions.deal_community_card(card3, 1);

        // Verify all three cards were dealt
        let game_after_dealing: Game = world.read_model(1);
        assert_eq!(
            game_after_dealing.community_cards.len(), 3, "Should have 3 community cards after flop",
        );
        assert!(
            !game_after_dealing.community_dealing,
            "Community dealing should be disabled after 3 cards",
        );
    }

    #[test]
    #[should_panic(expected: ('INVALID DEALING', 'ENTRYPOINT_FAILED'))]
    fn test_fourth_community_card_dealing_panics() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // Complete a betting round first
        feign_betting_round(ref world, systems.actions);

        // Deal three valid community cards
        let card1 = Card { suit: 4, value: 1 }; // Hearts Ace
        let card2 = Card { suit: 1, value: 13 }; // Spades King
        let card3 = Card { suit: 3, value: 12 }; // Diamonds Queen
        let card4 = Card { suit: 2, value: 11 }; // Clubs Jack

        systems.actions.deal_community_card(card1, 1);
        systems.actions.deal_community_card(card2, 1);
        systems.actions.deal_community_card(card3, 1);

        // Fourth card should panic
        systems.actions.deal_community_card(card4, 1);
    }

    #[test]
    fn test_betting_resumes_after_community_cards() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // Complete a betting round
        feign_betting_round(ref world, systems.actions);

        // Deal three community cards
        let card1 = Card { suit: 4, value: 1 }; // Hearts Ace
        let card2 = Card { suit: 1, value: 13 }; // Spades King
        let card3 = Card { suit: 3, value: 12 }; // Diamonds Queen

        systems.actions.deal_community_card(card1, 1);
        systems.actions.deal_community_card(card2, 1);
        systems.actions.deal_community_card(card3, 1);

        // Verify betting can resume - community_dealing should be false, allowing betting
        let game_after_dealing: Game = world.read_model(1);
        assert!(
            !game_after_dealing.community_dealing,
            "Community dealing should be disabled, allowing betting",
        );

        // Test that a player can now make a bet (check)
        set_contract_address(PLAYER_1());
        systems.actions.check(); // Should succeed

        let game_after_check: Game = world.read_model(1);
        assert_eq!(
            game_after_check.next_player,
            Option::Some(PLAYER_2()),
            "Betting should resume normally",
        );
    }

    //  Trying two functions 👇.

    #[test]
    #[should_panic(expected: ('INVALID CALL', 'ENTRYPOINT_FAILED'))]
    fn test_betting_fails_when_community_dealing_active() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // Complete a betting round to enable community_dealing
        feign_betting_round(ref world, systems.actions);

        // Verify community_dealing is active
        let game_after_betting: Game = world.read_model(1);
        assert!(game_after_betting.community_dealing, "Community dealing should be active");

        // Try to make a bet while community_dealing is active - should panic
        set_contract_address(PLAYER_1());
        systems.actions.check(); // Should panic with 'INVALID CALL'
    }

    #[test]
    #[should_panic(expected: ('INVALID CALL', 'ENTRYPOINT_FAILED'))]
    fn test_call_fails_when_community_dealing_active() {
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        feign_betting_round(ref world, systems.actions);

        set_contract_address(PLAYER_1());
        systems.actions.call(); // Should panic with 'INVALID CALL'
    }


    // Helper function to simulate a complete betting round
    fn feign_betting_round(ref world: WorldStorage, actions: IActionsDispatcher) {
        // Player 1 raises
        let game: Game = world.read_model(1);
        let raise_amount = game.params.small_blind * 4; // 40
        set_contract_address(PLAYER_1());
        actions.raise(raise_amount.into());

        // Player 2 calls
        set_contract_address(PLAYER_2());
        actions.call();

        // Player 3 calls - this completes the betting round
        set_contract_address(PLAYER_3());
        actions.call();

        // Verify betting round is complete and reset has occurred
        let game_after_betting: Game = world.read_model(1);
        println!("highes staker: {:?}", game_after_betting.highest_staker);
        assert!(game_after_betting.highest_staker.is_none(), "Betting round should be complete");
        assert_eq!(game_after_betting.current_bet, 0, "Current bet should be reset");
        assert!(game_after_betting.community_dealing, "Community dealing should be enabled");
    }

    fn card(suit: u8, value: u16) -> Card {
        Card { suit, value }
    }

    // @truthixify - Comprehensive showdown function tests

    /// Helper function to create a valid showdown setup with proper signatures
    fn setup_valid_showdown(
        ref world: WorldStorage,
    ) -> (
        u64, // game_id
        Array<Hand>, // hands
        Array<Array<felt252>>, // game_proofs
        Array<Array<felt252>>, // dealt_card_proofs
        Deck, // deck
        Array<felt252>, // game_salt
        Array<felt252>, // dealt_card_salt
        Array<felt252>, // signature_r
        Array<felt252>, // signature_s
        Array<bool>, // signature_y_parity
        u64 // nonce
    ) {
        // Setup game state for showdown
        let game_id = 1;
        let mut game: Game = world.read_model(game_id);
        game.showdown = true;
        game.round_in_progress = true;
        game
            .community_cards =
                array![card(0, 14), card(1, 13), card(2, 12), card(3, 11), card(0, 10)];
        game.nonce = 0;
        world.write_model(@game);

        // Setup player
        let player_address = SHOWODWN_PLAYER1();
        let mut player: Player = world.read_model(player_address);
        player.in_round = true;
        player.locked = (true, game_id);
        player.pub_key = 0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2;
        world.write_model(@player);

        // Create test data
        let mut deck: Deck = Deck { id: 1, cards: array![] };
        deck.new_deck();

        let game_salt = array!['Salt1', 'Salt2', 'Salt3'];
        let dealt_card_salt = array!['DSalt1', 'DSalt2', 'DSalt3'];
        let mut merkle_state = MerkleTrait::new(deck.cards.clone(), game_salt.clone());

        // Create dealt cards
        let dealt_cards = array![card(0, 14), card(1, 13), card(2, 12)];

        // The validation expects hands.len() == game_proofs.len() / 2
        // So for 1 hand, we need 2 game proofs
        let mut game_proofs: Array<Array<felt252>> = array![];
        let mut i: u64 = 0;
        while i != 2 {
            game_proofs.append(merkle_state.generate_proof_v2(i.into()));
            i += 1;
        };

        // For 1 hand, we need 2 dealt card proofs
        let mut dealt_card_proofs: Array<Array<felt252>> = array![];
        let mut i: u64 = 0;
        while i != 2 {
            dealt_card_proofs.append(merkle_state.generate_proof_v2(i.into()));
            i += 1;
        };

        let hand = Hand { player: player_address, cards: dealt_cards };
        let hands = array![hand];

        let signature_r = array![0x505150549b4024a7804bdfd846a480208c69ab04c82cb6911628470945861b];
        let signature_s = array![0x309fbfd5c149a63cd8842f4994f080070f795312c08164270904126e94c0a7b];
        let signature_y_parity = array![true];
        let nonce = 0;

        (
            game_id,
            hands,
            game_proofs,
            dealt_card_proofs,
            deck,
            game_salt,
            dealt_card_salt,
            signature_r,
            signature_s,
            signature_y_parity,
            nonce,
        )
    }

    #[test]
    fn test_showdown_valid_case() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // Setup game state for showdown
        let (
            game_id,
            hands,
            game_proofs,
            dealt_card_proofs,
            deck,
            game_salt,
            dealt_card_salt,
            signature_r,
            signature_s,
            signature_y_parity,
            _,
        ) =
            setup_valid_showdown(
            ref world,
        );

        // [Execute]
        systems
            .actions
            .showdown(
                game_id,
                hands,
                game_proofs,
                dealt_card_proofs,
                deck,
                game_salt,
                dealt_card_salt,
                signature_r,
                signature_s,
                signature_y_parity,
                0,
            );

        // [Assert]
        let updated_game: Game = world.read_model(game_id);
        assert(updated_game.nonce == 1, 'Nonce incremented');
    }

    #[test]
    #[should_panic(expected: ('INVALID NONCE', 'ENTRYPOINT_FAILED'))]
    fn test_showdown_replay_attack_invalid_nonce() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // Setup basic showdown state
        let game_id = 1;
        let mut game: Game = world.read_model(game_id);
        game.showdown = true;
        game.round_in_progress = true;
        game
            .community_cards =
                array![card(0, 14), card(1, 13), card(2, 12), card(3, 11), card(0, 10)];
        game.nonce = 0;
        world.write_model(@game);

        let player_address = SHOWODWN_PLAYER1();
        let mut player: Player = world.read_model(player_address);
        player.in_round = true;
        player.locked = (true, game_id);
        player.pub_key = 0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2;
        world.write_model(@player);

        let mut deck: Deck = Deck { id: 1, cards: array![] };
        deck.new_deck();

        let game_salt = array!['Salt1', 'Salt2', 'Salt3'];
        let dealt_card_salt = array!['DSalt1', 'DSalt2', 'DSalt3'];
        let mut merkle_state = MerkleTrait::new(deck.cards.clone(), game_salt.clone());

        let mut game_proofs: Array<Array<felt252>> = array![];
        let mut dealt_card_proofs: Array<Array<felt252>> = array![];
        let mut i: u64 = 0;
        while i != 3 {
            game_proofs.append(merkle_state.generate_proof_v2(i.into()));
            dealt_card_proofs.append(merkle_state.generate_proof_v2(i.into()));

            i += 1;
        };

        let hand = Hand {
            player: player_address, cards: array![card(0, 14), card(1, 13), card(2, 12)],
        };
        let hands = array![hand];

        let signature_r = array![0x505150549b4024a7804bdfd846a480208c69ab04c82cb6911628470945861b];
        let signature_s = array![0x309fbfd5c149a63cd8842f4994f080070f795312c08164270904126e94c0a7b];
        let signature_y_parity = array![true];

        // [Execute] - Using wrong nonce (replay attack simulation)
        let invalid_nonce = 5; // Game nonce is 0, so this should fail
        systems
            .actions
            .showdown(
                game_id,
                hands,
                game_proofs,
                dealt_card_proofs,
                deck,
                game_salt,
                dealt_card_salt,
                signature_r,
                signature_s,
                signature_y_parity,
                invalid_nonce,
            );
    }


    #[test]
    #[should_panic(expected: ('INVALID SALT', 'ENTRYPOINT_FAILED'))]
    fn test_showdown_invalid_salt_length() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // Setup basic showdown state
        let game_id = 1;
        let mut game: Game = world.read_model(game_id);
        game.showdown = true;
        game.round_in_progress = true;
        game
            .community_cards =
                array![card(0, 14), card(1, 13), card(2, 12), card(3, 11), card(0, 10)];
        game.nonce = 0;
        world.write_model(@game);

        let player_address = SHOWODWN_PLAYER1();
        let mut player: Player = world.read_model(player_address);
        player.in_round = true;
        player.locked = (true, game_id);
        player.pub_key = 0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2;
        world.write_model(@player);

        let mut deck: Deck = Deck { id: 1, cards: array![] };
        deck.new_deck();

        let mut merkle_state = MerkleTrait::new(
            deck.cards.clone(), array!['Salt1', 'Salt2', 'Salt3'],
        );

        let mut game_proofs: Array<Array<felt252>> = array![];
        let mut dealt_card_proofs: Array<Array<felt252>> = array![];
        let mut i: u64 = 0;
        while i != 3 {
            game_proofs.append(merkle_state.generate_proof_v2(i.into()));
            dealt_card_proofs.append(merkle_state.generate_proof_v2(i.into()));

            i += 1;
        };

        let hand = Hand {
            player: player_address, cards: array![card(0, 14), card(1, 13), card(2, 12)],
        };
        let hands = array![hand];

        let signature_r = array![0x505150549b4024a7804bdfd846a480208c69ab04c82cb6911628470945861b];
        let signature_s = array![0x309fbfd5c149a63cd8842f4994f080070f795312c08164270904126e94c0a7b];
        let signature_y_parity = array![true];

        // [Execute] - Using invalid salt lengths
        let invalid_game_salt = array!['Salt1', 'Salt2']; // Only 2 elements instead of 3
        let invalid_dealt_salt = array!['DSalt1']; // Only 1 element instead of 3

        systems
            .actions
            .showdown(
                game_id,
                hands,
                game_proofs,
                dealt_card_proofs,
                deck,
                invalid_game_salt,
                invalid_dealt_salt,
                signature_r,
                signature_s,
                signature_y_parity,
                0,
            );
    }

    #[test]
    #[should_panic(expected: ('SIGNATURE R LENGTH MISMATCH', 'ENTRYPOINT_FAILED'))]
    fn test_showdown_signature_length_mismatch() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        let (
            game_id,
            hands,
            game_proofs,
            dealt_card_proofs,
            deck,
            game_salt,
            dealt_card_salt,
            _,
            signature_s,
            signature_y_parity,
            nonce,
        ) =
            setup_valid_showdown(
            ref world,
        );

        // [Execute] - Mismatched signature array lengths
        let invalid_signature_r = array![]; // Empty array when hands has 1 element

        systems
            .actions
            .showdown(
                game_id,
                hands,
                game_proofs,
                dealt_card_proofs,
                deck,
                game_salt.clone(),
                dealt_card_salt.clone(),
                invalid_signature_r,
                signature_s,
                signature_y_parity,
                nonce,
            );
    }

    #[test]
    #[should_panic(expected: ('INVALID CALL', 'ENTRYPOINT_FAILED'))]
    fn test_showdown_game_not_in_showdown_state() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        let (
            game_id,
            hands,
            game_proofs,
            dealt_card_proofs,
            deck,
            game_salt,
            dealt_card_salt,
            signature_r,
            signature_s,
            signature_y_parity,
            nonce,
        ) =
            setup_valid_showdown(
            ref world,
        );

        // [Setup] - Set game to not be in showdown state
        let mut game: Game = world.read_model(game_id);
        game.showdown = false;
        world.write_model(@game);

        // [Execute] - Should fail because game is not in showdown state
        systems
            .actions
            .showdown(
                game_id,
                hands,
                game_proofs,
                dealt_card_proofs,
                deck,
                game_salt.clone(),
                dealt_card_salt.clone(),
                signature_r,
                signature_s,
                signature_y_parity,
                nonce,
            );
    }

    #[test]
    #[should_panic(expected: ('BAD REQUEST', 'ENTRYPOINT_FAILED'))]
    fn test_showdown_insufficient_community_cards() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        let (
            game_id,
            hands,
            game_proofs,
            dealt_card_proofs,
            deck,
            game_salt,
            dealt_card_salt,
            signature_r,
            signature_s,
            signature_y_parity,
            nonce,
        ) =
            setup_valid_showdown(
            ref world,
        );

        // [Setup] - Set insufficient community cards
        let mut game: Game = world.read_model(game_id);
        game.community_cards = array![card(0, 14), card(1, 13)]; // Only 2 cards instead of 5
        world.write_model(@game);

        // [Execute] - Should fail due to insufficient community cards
        systems
            .actions
            .showdown(
                game_id,
                hands,
                game_proofs,
                dealt_card_proofs,
                deck,
                game_salt.clone(),
                dealt_card_salt.clone(),
                signature_r,
                signature_s,
                signature_y_parity,
                nonce,
            );
    }

    #[test]
    #[should_panic(expected: ('PLAYER NOT IN ROUND', 'ENTRYPOINT_FAILED'))]
    fn test_showdown_player_not_in_round() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        let (
            game_id,
            hands,
            game_proofs,
            dealt_card_proofs,
            deck,
            game_salt,
            dealt_card_salt,
            signature_r,
            signature_s,
            signature_y_parity,
            nonce,
        ) =
            setup_valid_showdown(
            ref world,
        );

        // [Setup] - Set player as not in round
        let player_address = SHOWODWN_PLAYER1();
        let mut player: Player = world.read_model(player_address);
        player.in_round = false;
        world.write_model(@player);

        // [Execute] - Should fail because player is not in round
        systems
            .actions
            .showdown(
                game_id,
                hands,
                game_proofs,
                dealt_card_proofs,
                deck,
                game_salt.clone(),
                dealt_card_salt.clone(),
                signature_r,
                signature_s,
                signature_y_parity,
                nonce,
            );
    }

    #[test]
    #[should_panic(expected: ('SIGNATURE RECOVERY FAILED', 'ENTRYPOINT_FAILED'))]
    fn test_showdown_invalid_signature_recovery() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        let (
            game_id,
            hands,
            game_proofs,
            dealt_card_proofs,
            deck,
            game_salt,
            dealt_card_salt,
            _,
            _,
            _,
            nonce,
        ) =
            setup_valid_showdown(
            ref world,
        );

        // [Execute] - Using invalid signature values that will fail recovery
        let invalid_signature_r = array![0x0];
        let invalid_signature_s = array![0x0];
        let invalid_signature_y_parity = array![false];

        systems
            .actions
            .showdown(
                game_id,
                hands,
                game_proofs,
                dealt_card_proofs,
                deck,
                game_salt.clone(),
                dealt_card_salt.clone(),
                invalid_signature_r,
                invalid_signature_s,
                invalid_signature_y_parity,
                nonce,
            );
    }

    #[test]
    fn test_showdown_multiple_hands_valid() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_poker_game(ref world);

        // Setup multiple players for showdown
        let game_id = 1;
        let mut game: Game = world.read_model(game_id);
        game.showdown = true;
        game.round_in_progress = true;
        game
            .community_cards =
                array![card(0, 14), card(1, 13), card(2, 12), card(3, 11), card(0, 10)];
        game.nonce = 0;
        world.write_model(@game);

        // Setup salts
        let game_salt = array!['Salt1', 'Salt2', 'Salt3'];
        let dealt_card_salt = array!['DSalt1', 'DSalt2', 'DSalt3'];
        let (g1, g2, g3) = (*game_salt.at(0), *game_salt.at(1), *game_salt.at(2));
        let (d1, d2, d3) = (*dealt_card_salt.at(0), *dealt_card_salt.at(1), *dealt_card_salt.at(2));
        let game_salts = Salts { id1: g1, id2: g2, id3: g3, used: false };
        let dealt_salts = Salts { id1: d1, id2: d2, id3: d3, used: false };
        world.write_model(@game_salts);
        world.write_model(@dealt_salts);

        // Setup multiple players
        let player1 = SHOWODWN_PLAYER1();
        let player2 = SHOWODWN_PLAYER2();

        let mut p1: Player = world.read_model(player1);
        let mut p2: Player = world.read_model(player2);

        p1.in_round = true;
        p1.locked = (true, game_id);
        p1.pub_key = 0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2;

        p2.in_round = true;
        p2.locked = (true, game_id);
        p2.pub_key = 0x4ae6af1665641e0745203aeb5bbd24674094d56914618aaae131402de9f81de;

        world.write_model(@p1);
        world.write_model(@p2);

        // Create hands for both players
        let hand1 = Hand { player: player1, cards: array![card(0, 14), card(1, 13), card(2, 12)] };
        let hand2 = Hand { player: player2, cards: array![card(3, 11), card(0, 10), card(1, 9)] };
        let hands = array![hand1, hand2];

        // Create deck and proofs
        let mut deck: Deck = Deck { id: 1, cards: array![] };
        deck.new_deck();
        let mut merkle_state = MerkleTrait::new(deck.cards.clone(), game_salt.clone());

        // Build proofs: exactly 2 per hand (4 total for 2 hands)
        let mut game_proofs: Array<Array<felt252>> = array![];
        let mut dealt_card_proofs: Array<Array<felt252>> = array![];

        let needed: u32 = hands.len() * 2; // 2 proofs per hand

        let mut i: u32 = 0;
        while i != needed {
            game_proofs.append(merkle_state.generate_proof_v2(i.into()));
            dealt_card_proofs.append(merkle_state.generate_proof_v2(i.into()));
            i += 1;
        };

        // Multiple signatures (would be generated by TypeScript script)
        let signature_r = array![
            0x505150549b4024a7804bdfd846a480208c69ab04c82cb6911628470945861b,
            0x3857595249ec38af3cf0a34bc892a99c2da26bd876bf631aa20cea65425890d,
        ];
        let signature_s = array![
            0x309fbfd5c149a63cd8842f4994f080070f795312c08164270904126e94c0a7b,
            0x788d773c5e388e4475aea90a6522d0ab771dfa7ea7109a9e05a912034d3edb1,
        ];
        let signature_y_parity = array![true, true];
        let nonce = 0;

        // [Execute] - This should work with multiple valid hands
        systems
            .actions
            .showdown(
                game_id,
                hands,
                game_proofs,
                dealt_card_proofs,
                deck,
                game_salt.clone(),
                dealt_card_salt.clone(),
                signature_r,
                signature_s,
                signature_y_parity,
                nonce,
            );

        // [Assert]
        let updated_game: Game = world.read_model(game_id);
        assert(updated_game.nonce == 1, 'Nonce incremented');
    }

    // [Mocks]
    // Default mock usage for legacy tests
    pub fn mock_poker_game(ref world: WorldStorage) {
        let player_1 = mock_player(
            PLAYER_1(), 'dub_zn', 2000, 0, 1, (true, 1), false, true, (0, 0),
        );
        let player_2 = mock_player(
            PLAYER_2(), 'Birdmannn', 5000, 0, 1, (true, 1), false, true, (0, 0),
        );
        let player_3 = mock_player(
            PLAYER_3(), 'chiscookeke11', 5000, 0, 1, (true, 1), false, true, (0, 0),
        );
        let showdown_player1 = mock_player(
            SHOWODWN_PLAYER1(), 'bourbaki', 5000, 0, 1, (true, 1), false, true, (0, 0),
        );
        let showdown_player2 = mock_player(
            SHOWODWN_PLAYER2(), 'bourbaki', 5000, 0, 1, (true, 1), false, true, (0, 0),
        );
        mock_poker_game_flex(
            ref world,
            true, // in_progress
            false, // has_ended
            1, // current_round
            true, // round_in_progress
            2, // current_player_count
            array![PLAYER_1(), PLAYER_2(), PLAYER_3(), SHOWODWN_PLAYER1(), SHOWODWN_PLAYER2()],
            Option::Some(PLAYER_1()),
            array![],
            0,
            array![player_1, player_2, player_3, showdown_player1, showdown_player2],
        );
    }
}
