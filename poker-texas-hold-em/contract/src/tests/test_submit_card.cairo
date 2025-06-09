/// @AugmentAgent
/// Tests for the submit_card functionality
///
/// This module tests the card submission and verification system including:
/// - Valid card submissions with correct proofs
/// - Invalid card submissions with incorrect proofs
/// - Automatic round resolution when all players submit
/// - Staked amount deduction on verification failure

#[cfg(test)]
mod test_submit_card {
    use dojo::model::{ModelStorage, ModelValueStorage};
    use dojo::world::{WorldStorage, WorldStorageTrait};
    use poker::models::base::{GameErrors, RoundSubmissions};
    use poker::models::card::{Card, Suits, Royals};
    use poker::models::game::{Game, GameTrait};
    use poker::models::hand::{Hand, HandTrait};
    use poker::models::player::{Player, PlayerTrait};
    use poker::systems::interface::{IActionsDispatcher, IActionsDispatcherTrait};
    use poker::tests::setup::setup::{CoreContract, deploy_contracts};
    use poker::traits::game::get_default_game_params;
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

    fn setup_world() -> (WorldStorage, IActionsDispatcher) {
        let contracts = array![CoreContract::Actions];
        let (world, systems) = deploy_contracts(contracts);
        (world, systems.actions)
    }

    fn create_test_cards() -> Array<Card> {
        array![
            Card { suit: Suits::SPADES, value: Royals::ACE },
            Card { suit: Suits::HEARTS, value: Royals::KING },
        ]
    }

    fn create_test_proofs() -> (Array<felt252>, Array<felt252>) {
        let deck_proof = array![
            0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0,
            0x987654321fedcba0987654321fedcba0987654321fedcba0987654321fedcba0,
        ];
        let dealt_proof = array![
            0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789,
            0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321,
        ];
        (deck_proof, dealt_proof)
    }

    #[test]
    fn test_submit_card_success() {
        let (mut world, actions_system) = setup_world();
        mock_poker_game_for_submit_card(ref world);

        // Set up player state for submission
        let mut player: Player = world.read_model(PLAYER_1());
        player.in_round = true;
        player.chips = 1000;
        world.write_model(@player);

        // Create test data
        let cards = create_test_cards();
        let (deck_proof, dealt_proof) = create_test_proofs();
        let staked_amount = 100;

        // Submit cards
        set_contract_address(PLAYER_1());
        actions_system.submit_card(cards, deck_proof, dealt_proof, staked_amount);

        // Verify hand was stored
        let hand: Hand = world.read_model(PLAYER_1());
        assert(hand.cards.len() == 2, 'Hand should have 2 cards');

        // Verify submission count was incremented
        let submissions: RoundSubmissions = world.read_model((1_u64, 1_u8));
        assert(submissions.submitted_count == 1, 'Submission count should be 1');
    }

    #[test]
    #[should_panic(expected: ('Player not in round',))]
    fn test_submit_card_player_not_in_round() {
        let (mut world, actions_system) = setup_world();
        
        // Set up player 1
        set_contract_address(PLAYER_1());
        let game_id = actions_system.initialize_game(Option::None);
        
        // Set up game state
        let mut game: Game = world.read_model(game_id);
        game.round_in_progress = true;
        world.write_model(@game);
        
        // Player is not in round (in_round = false by default)
        let cards = create_test_cards();
        let (deck_proof, dealt_proof) = create_test_proofs();
        
        // This should panic
        actions_system.submit_card(cards, deck_proof, dealt_proof, 100);
    }

    #[test]
    #[should_panic(expected: ('INSUFFICIENT_CHIP',))]
    fn test_submit_card_insufficient_chips() {
        let (mut world, actions_system) = setup_world();
        
        // Set up player 1
        set_contract_address(PLAYER_1());
        let game_id = actions_system.initialize_game(Option::None);
        
        // Set up game state
        let mut game: Game = world.read_model(game_id);
        game.round_in_progress = true;
        world.write_model(@game);
        
        // Set up player with insufficient chips
        let mut player: Player = world.read_model(PLAYER_1());
        player.in_round = true;
        player.chips = 50; // Less than staked amount
        world.write_model(@player);
        
        let cards = create_test_cards();
        let (deck_proof, dealt_proof) = create_test_proofs();
        
        // This should panic due to insufficient chips
        actions_system.submit_card(cards, deck_proof, dealt_proof, 100);
    }

    #[test]
    fn test_submit_card_verification_failure() {
        let (mut world, actions_system) = setup_world();
        
        // Set up player 1
        set_contract_address(PLAYER_1());
        let game_id = actions_system.initialize_game(Option::None);
        
        // Set up game state with invalid roots (will cause verification to fail)
        let mut game: Game = world.read_model(game_id);
        game.round_in_progress = true;
        game.deck_root = 0; // Invalid root
        game.dealt_cards_root = 0; // Invalid root
        world.write_model(@game);
        
        // Set up player state
        let mut player: Player = world.read_model(PLAYER_1());
        player.in_round = true;
        player.chips = 1000;
        world.write_model(@player);
        
        let initial_chips = player.chips;
        let cards = create_test_cards();
        let (deck_proof, dealt_proof) = create_test_proofs();
        let staked_amount = 100;
        
        // Submit cards (verification should fail)
        actions_system.submit_card(cards, deck_proof, dealt_proof, staked_amount);
        
        // Verify chips were deducted
        let updated_player: Player = world.read_model(PLAYER_1());
        assert(updated_player.chips == initial_chips - staked_amount, 'Chips should be deducted');
        
        // Verify pot was increased
        let updated_game: Game = world.read_model(game_id);
        assert(updated_game.pot == staked_amount, 'Pot should increase');
    }

    #[test]
    fn test_multiple_players_submit_cards() {
        let (mut world, actions_system) = setup_world();
        
        // Set up player 1
        set_contract_address(PLAYER_1());
        let game_id = actions_system.initialize_game(Option::None);
        
        // Set up player 2 and join game
        set_contract_address(PLAYER_2());
        actions_system.join_game(game_id);
        
        // Set up game state
        let mut game: Game = world.read_model(game_id);
        game.round_in_progress = true;
        game.deck_root = 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0;
        game.dealt_cards_root = 0x987654321fedcba0987654321fedcba0987654321fedcba0987654321fedcba0;
        world.write_model(@game);
        
        // Set up both players
        let mut player1: Player = world.read_model(PLAYER_1());
        player1.in_round = true;
        player1.chips = 1000;
        world.write_model(@player1);
        
        let mut player2: Player = world.read_model(PLAYER_2());
        player2.in_round = true;
        player2.chips = 1000;
        world.write_model(@player2);
        
        let cards = create_test_cards();
        let (deck_proof, dealt_proof) = create_test_proofs();
        
        // Player 1 submits cards
        set_contract_address(PLAYER_1());
        actions_system.submit_card(cards.clone(), deck_proof.clone(), dealt_proof.clone(), 100);
        
        // Verify submission count
        let submissions: RoundSubmissions = world.read_model((game_id, 1_u8));
        assert(submissions.submitted_count == 1, 'Should have 1 submission');
        
        // Player 2 submits cards (should trigger round resolution)
        set_contract_address(PLAYER_2());
        actions_system.submit_card(cards, deck_proof, dealt_proof, 100);
        
        // Verify final submission count
        let final_submissions: RoundSubmissions = world.read_model((game_id, 1_u8));
        assert(final_submissions.submitted_count == 2, 'Should have 2 submissions');
    }

    #[test]
    fn test_submit_card_empty_cards() {
        let (mut world, actions_system) = setup_world();

        // Set up player 1
        set_contract_address(PLAYER_1());
        let game_id = actions_system.initialize_game(Option::None);

        // Set up game state
        let mut game: Game = world.read_model(game_id);
        game.round_in_progress = true;
        game.deck_root = 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0;
        game.dealt_cards_root = 0x987654321fedcba0987654321fedcba0987654321fedcba0987654321fedcba0;
        world.write_model(@game);

        // Set up player state
        let mut player: Player = world.read_model(PLAYER_1());
        player.in_round = true;
        player.chips = 1000;
        world.write_model(@player);

        let empty_cards = array![];
        let (deck_proof, dealt_proof) = create_test_proofs();
        let initial_chips = player.chips;
        let staked_amount = 100;

        // Submit empty cards (verification should fail due to empty cards)
        actions_system.submit_card(empty_cards, deck_proof, dealt_proof, staked_amount);

        // Verify chips were deducted due to verification failure
        let updated_player: Player = world.read_model(PLAYER_1());
        assert(updated_player.chips == initial_chips - staked_amount, 'Chips should be deducted');

        // Verify pot was increased
        let updated_game: Game = world.read_model(game_id);
        assert(updated_game.pot == staked_amount, 'Pot should increase');
    }

    // [Mocks]
    fn mock_poker_game_for_submit_card(ref world: WorldStorage) {
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
            pot: 0,
            current_bet: 0,
            params: get_default_game_params(),
            reshuffled: 0,
            should_end: false,
            deck_root: 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0,
            dealt_cards_root: 0x987654321fedcba0987654321fedcba0987654321fedcba0987654321fedcba0,
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
        };

        world.write_model(@game);
        world.write_models(array![@player_1, @player_2, @player_3].span());
    }
}
