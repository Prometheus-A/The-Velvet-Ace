#[cfg(test)]
mod tests {
    use dojo::event::EventStorageTest;
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
    use dojo::world::{WorldStorage, WorldStorageTrait};
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };
    use poker::models::game::{Game, GameTrait};
    use poker::models::player::{Player, PlayerTrait};
    use poker::traits::game::get_default_game_params;
    use poker::systems::interface::{IActionsDispatcher, IActionsDispatcherTrait};
    use poker::tests::setup::setup::{CoreContract, deploy_contracts};
    use starknet::ContractAddress;
    use starknet::testing::{set_account_contract_address, set_contract_address};

    fn PLAYER_1() -> ContractAddress {
        starknet::contract_address_const::<'PLAYER_1'>()
    }

    fn PLAYER_2() -> ContractAddress {
        starknet::contract_address_const::<'PLAYER_2'>()
    }

    fn PLAYER_3() -> ContractAddress {
        starknet::contract_address_const::<'PLAYER_3'>()
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
        assert_eq!(player_2_after_call.current_bet, raise_amount.into(), "Player 2 didn't call correctly");

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

    // [Mocks]
    fn mock_poker_game(ref world: WorldStorage) {
        let game = Game {
            id: 1,
            in_progress: true,
            has_ended: false,
            current_round: 1,
            round_in_progress: true,
            current_player_count: 3,
            players: array![PLAYER_1(), PLAYER_2(), PLAYER_3()],
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

        let player_1 = Player {
            id: PLAYER_1(),
            alias: 'dub_zn',
            chips: 2000,
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

        let player_2 = Player {
            id: PLAYER_2(),
            alias: 'Birdmannn',
            chips: 5000,
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

        let player_3 = Player {
            id: PLAYER_3(),
            alias: 'chiscookeke11',
            chips: 5000,
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

        world.write_model(@game);
        world.write_models(array![@player_1, @player_2, @player_3].span());
    }
}
