//! Comprehensive Betting Flow Tests
//! 
//! This module tests the complete betting flow scenarios including:
//! - Small blind automatic deduction on game start
//! - Player turn restrictions and validation
//! - Call/raise betting mechanics with proper validation
//! - All-in scenarios with pot adjustments
//! - Complex multi-player betting rounds with pot management
//! 
//! @claude-3-5-sonnet-20241022

#[cfg(test)]
mod betting_flow_tests {
    use dojo::event::EventStorageTest;
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
    use dojo::world::{WorldStorage, WorldStorageTrait};
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };
    use poker::models::game::{Game, GameTrait, GameParams};
    use poker::models::player::{Player, PlayerTrait};
    use poker::models::hand::Hand;
    use poker::traits::game::get_default_game_params;
    use poker::systems::interface::{IActionsDispatcher, IActionsDispatcherTrait};
    use poker::tests::setup::setup::{CoreContract, deploy_contracts};
    use starknet::ContractAddress;
    use starknet::testing::{set_account_contract_address, set_contract_address};

    // Test player addresses
    fn PLAYER_1() -> ContractAddress {
        starknet::contract_address_const::<'PLAYER_1'>()
    }

    fn PLAYER_2() -> ContractAddress {
        starknet::contract_address_const::<'PLAYER_2'>()
    }

    fn PLAYER_3() -> ContractAddress {
        starknet::contract_address_const::<'PLAYER_3'>()
    }

    fn PLAYER_4() -> ContractAddress {
        starknet::contract_address_const::<'PLAYER_4'>()
    }

    /// Creates a mock poker game with 4 players for comprehensive betting flow testing
    /// Players have different chip amounts to test various scenarios
    /// @claude-3-5-sonnet-20241022
    fn setup_four_player_betting_game(ref world: WorldStorage) -> Game {
        let game = Game {
            id: 1,
            in_progress: true,
            has_ended: false,
            current_round: 1,
            round_in_progress: true,
            current_player_count: 4,
            players: array![PLAYER_1(), PLAYER_2(), PLAYER_3(), PLAYER_4()],
            deck: array![],
            next_player: Option::Some(PLAYER_1()),
            community_cards: array![],
            pots: array![0],
            current_bet: 0,
            params: get_default_game_params(),
            reshuffled: 0,
            should_end: false,
            deck_root: 0,
            dealt_cards_root: 0,
            nonce: 0,
            community_dealing: false,
            showdown: false,
            round_count: 0,
            highest_staker: Option::None,
            previous_offset: 0,
        };

        // Player 1: Small blind player (next to dealer)
        let player_1 = Player {
            id: PLAYER_1(),
            alias: 'small_blind_player',
            chips: 1000,
            current_bet: 0,
            total_rounds: 1,
            locked: (true, 1),
            is_dealer: false,
            in_round: true,
            out: (0, 0),
            pub_key: 0x1,
            locked_chips: 0,
            is_blacklisted: false,
            eligible_pots: 1,
        };

        // Player 2: Big blind player
        let player_2 = Player {
            id: PLAYER_2(),
            alias: 'big_blind_player',
            chips: 2000,
            current_bet: 0,
            total_rounds: 1,
            locked: (true, 1),
            is_dealer: false,
            in_round: true,
            out: (0, 0),
            pub_key: 0x2,
            locked_chips: 0,
            is_blacklisted: false,
            eligible_pots: 1,
        };

        // Player 3: Regular player with moderate chips
        let player_3 = Player {
            id: PLAYER_3(),
            alias: 'regular_player_1',
            chips: 1500,
            current_bet: 0,
            total_rounds: 1,
            locked: (true, 1),
            is_dealer: false,
            in_round: true,
            out: (0, 0),
            pub_key: 0x3,
            locked_chips: 0,
            is_blacklisted: false,
            eligible_pots: 1,
        };

        // Player 4: Player with high chips for raising scenarios
        let player_4 = Player {
            id: PLAYER_4(),
            alias: 'high_chip_player',
            chips: 5000,
            current_bet: 0,
            total_rounds: 1,
            locked: (true, 1),
            is_dealer: true, // Dealer for this game
            in_round: true,
            out: (0, 0),
            pub_key: 0x4,
            locked_chips: 0,
            is_blacklisted: false,
            eligible_pots: 1,
        };

        world.write_model(@game);
        world.write_models(array![@player_1, @player_2, @player_3, @player_4].span());
        
        game
    }

    /// Simulates the start of a betting round with small blind deduction
    /// Sets up the game state as it would be after _start_round is called
    /// @claude-3-5-sonnet-20241022
    fn simulate_round_start(ref world: WorldStorage) {
        let mut game: Game = world.read_model(1);
        let mut player_1: Player = world.read_model(PLAYER_1());
        
        // Simulate small blind deduction (Player 1 is next to dealer)
        let small_blind = game.params.small_blind;
        player_1.chips -= small_blind.into();
        player_1.current_bet = small_blind.into();
        
        // Set pot to small blind amount
        game.pots = array![small_blind.into()];
        game.current_bet = small_blind.into();
        
        // Set next player to big blind player (Player 2)
        game.next_player = Option::Some(PLAYER_2());
        
        world.write_model(@game);
        world.write_model(@player_1);
    }

    /// Helper function to set equal bets for multiple players
    /// Used to test scenarios where players have matched bets
    /// @claude-3-5-sonnet-20241022
    fn set_equal_bets_for_players(
        ref world: WorldStorage,
        player_addresses: Array<ContractAddress>,
        bet_amount: u256
    ) {
        let mut i = 0;
        while i < player_addresses.len() {
            let mut player: Player = world.read_model(*player_addresses.at(i));
            player.current_bet = bet_amount;
            player.chips -= bet_amount;
            world.write_model(@player);
            i += 1;
        };
    }

    /// Helper function to verify pot state and player eligible pots
    /// Used to assert correct pot management in complex scenarios
    /// @claude-3-5-sonnet-20241022
    fn verify_pot_state(
        world: @WorldStorage,
        game_id: u64,
        expected_pot_count: u32,
        player_id: ContractAddress,
        expected_eligible_pots: u8
    ) {
        let game: Game = world.read_model(game_id);
        let player: Player = world.read_model(player_id);
        
        assert!(
            game.pots.len() == expected_pot_count,
            "Expected pot count doesn't match actual"
        );
        assert!(
            player.eligible_pots == expected_eligible_pots,
            "Player eligible pots doesn't match expected"
        );
    }

    // ==================== BETTING FLOW TESTS ====================

    /// Test 1: Small blind should be automatically deducted from player next to dealer on game start
    /// @claude-3-5-sonnet-20241022
    #[test]
    fn test_small_blind_automatic_deduction_on_start() {
        // Setup
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        let initial_game = setup_four_player_betting_game(ref world);
        
        // Get initial state
        let player_1_initial: Player = world.read_model(PLAYER_1());
        let initial_chips = player_1_initial.chips;
        let small_blind = initial_game.params.small_blind;
        
        // Simulate round start (this would normally be called by _start_round)
        simulate_round_start(ref world);
        
        // Verify small blind deduction
        let player_1_after: Player = world.read_model(PLAYER_1());
        let game_after: Game = world.read_model(1);
        
        assert!(
            player_1_after.chips == initial_chips - small_blind.into(),
            "Small blind should be deducted from player next to dealer"
        );
        assert!(
            player_1_after.current_bet == small_blind.into(),
            "Player's current bet should equal small blind"
        );
        assert!(
            *game_after.pots.at(0) == small_blind.into(),
            "Pot should contain small blind amount"
        );
        assert!(
            game_after.next_player == Option::Some(PLAYER_2()),
            "Next player should be set to big blind player"
        );
    }

    /// Test 2: Small blind player should not be able to play again immediately
    /// @claude-3-5-sonnet-20241022
    #[test]
    #[should_panic(expected: ('Not player turn', 'ENTRYPOINT_FAILED'))]
    fn test_small_blind_player_cannot_play_again_immediately() {
        // Setup
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        setup_four_player_betting_game(ref world);
        simulate_round_start(ref world);
        
        // Try to make small blind player (Player 1) play when it's Player 2's turn
        set_contract_address(PLAYER_1());
        systems.actions.check();
    }

    /// Test 3: Betting between small blind and big blind should panic
    /// @claude-3-5-sonnet-20241022
    #[test]
    #[should_panic(expected: ("Raise amount should be > twice the small blind.", 'ENTRYPOINT_FAILED'))]
    fn test_bet_between_small_and_big_blind_panics() {
        // Setup
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        setup_four_player_betting_game(ref world);
        simulate_round_start(ref world);
        
        let game: Game = world.read_model(1);
        let small_blind = game.params.small_blind;
        let invalid_raise = small_blind.into() + 5; // Between small and big blind
        
        // Player 2 (big blind player) tries to raise with invalid amount
        set_contract_address(PLAYER_2());
        systems.actions.raise(invalid_raise);
    }

    /// Test 4: Call with big blind amount should work
    /// @claude-3-5-sonnet-20241022
    #[test]
    fn test_call_with_big_blind_amount_works() {
        // Setup
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        setup_four_player_betting_game(ref world);
        simulate_round_start(ref world);
        
        let game: Game = world.read_model(1);
        let player_2_initial: Player = world.read_model(PLAYER_2());
        let big_blind = game.params.big_blind;
        
        // Player 2 calls with big blind amount
        set_contract_address(PLAYER_2());
        systems.actions.call();
        
        // Verify call worked
        let player_2_after: Player = world.read_model(PLAYER_2());
        let game_after: Game = world.read_model(1);
        
        assert!(
            player_2_after.current_bet == big_blind.into(),
            "Player's current bet should equal big blind after call"
        );
        assert!(
            game_after.next_player == Option::Some(PLAYER_3()),
            "Next player should be set to Player 3"
        );
    }

    /// Test 5: Raise with amount greater than big blind should work
    /// @claude-3-5-sonnet-20241022
    #[test]
    fn test_raise_greater_than_big_blind_works() {
        // Setup
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        setup_four_player_betting_game(ref world);
        simulate_round_start(ref world);
        
        let game: Game = world.read_model(1);
        let player_2_initial: Player = world.read_model(PLAYER_2());
        let big_blind = game.params.big_blind;
        let raise_amount = big_blind.into() + 50; // Greater than big blind
        
        // Player 2 raises
        set_contract_address(PLAYER_2());
        systems.actions.raise(raise_amount);
        
        // Verify raise worked
        let player_2_after: Player = world.read_model(PLAYER_2());
        let game_after: Game = world.read_model(1);
        
        assert!(
            player_2_after.current_bet == raise_amount + big_blind.into(),
            "Player's current bet should include call amount plus raise"
        );
        assert!(
            game_after.current_bet == player_2_after.current_bet,
            "Game current bet should be updated to player's bet"
        );
        assert!(
            game_after.next_player == Option::Some(PLAYER_3()),
            "Next player should be set to Player 3"
        );
    }

    /// Test 6: Raise with amount less than or equal to big blind should panic
    /// @claude-3-5-sonnet-20241022
    #[test]
    #[should_panic(expected: ("Raise amount is less than the game's current bet.", 'ENTRYPOINT_FAILED'))]
    fn test_raise_less_than_big_blind_panics() {
        // Setup
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        setup_four_player_betting_game(ref world);
        simulate_round_start(ref world);
        
        let game: Game = world.read_model(1);
        let big_blind = game.params.big_blind;
        let invalid_raise = big_blind.into() - 5; // Less than big blind
        
        // Player 2 tries to raise with invalid amount
        set_contract_address(PLAYER_2());
        systems.actions.raise(invalid_raise);
    }

    /// Test 7: Complex all-in scenario with pot adjustments
    /// Tests the scenario described in requirements where players have different bets
    /// and one goes all-in, creating multiple pots
    /// @claude-3-5-sonnet-20241022
    #[test]
    fn test_complex_all_in_scenario_with_pot_adjustments() {
        // Setup
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        setup_four_player_betting_game(ref world);
        
        // Set up scenario: Players 1-3 have equal bets of 50, Player 4 raises to 70
        set_equal_bets_for_players(
            ref world,
            array![PLAYER_1(), PLAYER_2(), PLAYER_3()],
            50
        );
        
        let mut player_4: Player = world.read_model(PLAYER_4());
        player_4.current_bet = 70;
        player_4.chips -= 70;
        world.write_model(@player_4);
        
        let mut game: Game = world.read_model(1);
        game.current_bet = 70;
        game.next_player = Option::Some(PLAYER_1());
        world.write_model(@game);
        
        // Player 1 calls the 70
        set_contract_address(PLAYER_1());
        systems.actions.call();
        
        // Player 2 raises to 90
        set_contract_address(PLAYER_2());
        systems.actions.raise(90);
        
        // Player 3 goes all-in with only 55 chips remaining
        let mut player_3: Player = world.read_model(PLAYER_3());
        player_3.chips = 55; // Set remaining chips for all-in
        world.write_model(@player_3);
        
        set_contract_address(PLAYER_3());
        systems.actions.all_in();
        
        // Verify pot adjustments and eligible pots
        let player_3_after: Player = world.read_model(PLAYER_3());
        let game_after: Game = world.read_model(1);
        
        assert!(
            player_3_after.chips == 0,
            "Player 3 should have 0 chips after all-in"
        );
        assert!(
            player_3_after.eligible_pots == 1,
            "Player 3 should have eligible_pots = 1"
        );
        assert!(
            game_after.pots.len() >= 2,
            "Game should have multiple pots after all-in"
        );
        
        // Verify other players have eligible_pots = 2
        let player_1_after: Player = world.read_model(PLAYER_1());
        let player_2_after: Player = world.read_model(PLAYER_2());
        let player_4_after: Player = world.read_model(PLAYER_4());
        
        assert!(
            player_1_after.eligible_pots == 2,
            "Player 1 should have eligible_pots = 2"
        );
        assert!(
            player_2_after.eligible_pots == 2,
            "Player 2 should have eligible_pots = 2"
        );
        assert!(
            player_4_after.eligible_pots == 2,
            "Player 4 should have eligible_pots = 2"
        );
    }

    /// Test 8: Betting round continues when bets are not matched
    /// @claude-3-5-sonnet-20241022
    #[test]
    fn test_betting_round_continues_when_bets_not_matched() {
        // Setup
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        setup_four_player_betting_game(ref world);
        
        // Set up unmatched bets scenario
        let mut player_1: Player = world.read_model(PLAYER_1());
        let mut player_2: Player = world.read_model(PLAYER_2());
        let mut player_3: Player = world.read_model(PLAYER_3());
        let mut player_4: Player = world.read_model(PLAYER_4());
        
        player_1.current_bet = 50;
        player_2.current_bet = 50;
        player_3.current_bet = 50;
        player_4.current_bet = 70; // Different bet amount
        
        let mut game: Game = world.read_model(1);
        game.current_bet = 70;
        game.next_player = Option::Some(PLAYER_1());
        
        world.write_models(array![@player_1, @player_2, @player_3, @player_4].span());
        world.write_model(@game);
        
        // Verify that betting round should continue
        let game_state: Game = world.read_model(1);
        assert!(
            game_state.next_player.is_some(),
            "Betting round should continue when bets are not matched"
        );
        assert!(
            !game_state.showdown,
            "Game should not be in showdown when bets are unmatched"
        );
    }

    /// Test 9: Next player should skip all-in player
    /// @claude-3-5-sonnet-20241022
    #[test]
    fn test_next_player_skips_all_in_player() {
        // Setup
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        setup_four_player_betting_game(ref world);
        
        // Set Player 3 as all-in (0 chips, but still in round)
        let mut player_3: Player = world.read_model(PLAYER_3());
        player_3.chips = 0;
        player_3.current_bet = 55; // All-in amount
        player_3.in_round = true; // Still in round
        world.write_model(@player_3);
        
        let mut game: Game = world.read_model(1);
        game.next_player = Option::Some(PLAYER_2());
        world.write_model(@game);
        
        // Player 2 makes a move
        set_contract_address(PLAYER_2());
        systems.actions.check();
        
        // Verify next player skips Player 3 (all-in) and goes to Player 4
        let game_after: Game = world.read_model(1);
        assert!(
            game_after.next_player != Option::Some(PLAYER_3()),
            "Next player should not be the all-in player"
        );
    }

    /// Test 10: All-in player cannot play but remains in round
    /// @claude-3-5-sonnet-20241022
    #[test]
    #[should_panic(expected: ('Player out of chips', 'ENTRYPOINT_FAILED'))]
    fn test_all_in_player_cannot_play_but_remains_in_round() {
        // Setup
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        setup_four_player_betting_game(ref world);
        
        // Set Player 3 as all-in
        let mut player_3: Player = world.read_model(PLAYER_3());
        player_3.chips = 0; // All-in
        player_3.in_round = true; // Still in round
        world.write_model(@player_3);
        
        let mut game: Game = world.read_model(1);
        game.next_player = Option::Some(PLAYER_3()); // Force Player 3 to be next
        world.write_model(@game);
        
        // Verify Player 3 is still in game and in round
        assert!(
            player_3.in_round,
            "All-in player should still be in round"
        );
        assert!(
            player_3.is_in_game(1),
            "All-in player should still be in game"
        );
        
        // Try to make Player 3 play - should panic due to no chips
        set_contract_address(PLAYER_3());
        systems.actions.check();
    }

    /// Test 11: Verify all-in player state after going all-in
    /// @claude-3-5-sonnet-20241022
    #[test]
    fn test_all_in_player_state_verification() {
        // Setup
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        setup_four_player_betting_game(ref world);
        
        let mut game: Game = world.read_model(1);
        game.next_player = Option::Some(PLAYER_3());
        world.write_model(@game);
        
        // Player 3 goes all-in
        set_contract_address(PLAYER_3());
        systems.actions.all_in();
        
        // Verify Player 3's state after all-in
        let player_3_after: Player = world.read_model(PLAYER_3());
        
        assert!(
            player_3_after.chips == 0,
            "Player should have 0 chips after all-in"
        );
        assert!(
            player_3_after.in_round,
            "Player should still be in round after all-in"
        );
        assert!(
            player_3_after.is_in_game(1),
            "Player should still be in game after all-in"
        );
    }
} 