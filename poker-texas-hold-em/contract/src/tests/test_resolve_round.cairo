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
    use poker::models::hand::{Hand, HandTrait};
    use poker::models::card::{Card, Suits, Royals};
    use poker::models::base::{RoundResolved, HandResolved};
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

    // Helper function to create a card
    fn create_card(value: u16, suit: u8) -> Card {
        Card { value, suit }
    }

    // Helper function to create a hand with cards
    fn create_hand_with_cards(player: ContractAddress, cards: Array<Card>) -> Hand {
        Hand { player, cards }
    }

    // Helper function to create an empty hand
    fn create_empty_hand(player: ContractAddress) -> Hand {
        Hand { player, cards: array![] }
    }

    // Mock game with round in progress 
    fn mock_game_with_round_in_progress(ref world: WorldStorage) {
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
            deck_root: 0,
            dealt_cards_root: 0,
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

    /// Test #144 Requirement 1: Skip players with empty hands 
    #[test]
    fn test_resolve_round_skips_empty_hands() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_game_with_round_in_progress(ref world);
        
        // Setup hands: P1 and P3 have cards, P2 has empty hand
        let hand_1 = create_hand_with_cards(
            PLAYER_1(), 
            array![create_card(14, Suits::SPADES), create_card(13, Suits::HEARTS)]
        );
        let hand_2 = create_empty_hand(PLAYER_2()); // Empty hand - should be skipped
        let hand_3 = create_hand_with_cards(
            PLAYER_3(), 
            array![create_card(12, Suits::CLUBS), create_card(11, Suits::DIAMONDS)]
        );
        
        world.write_models(array![@hand_1, @hand_2, @hand_3].span());
        
        // [Execute] - Call resolve_round directly using the public method
        systems.actions.resolve_round(1);
        
        // [Assert] - Verify that hands were processed and cleaned
        let hand_1_after: Hand = world.read_model(PLAYER_1());
        let hand_2_after: Hand = world.read_model(PLAYER_2());
        let hand_3_after: Hand = world.read_model(PLAYER_3());
        
        // All hands should be empty after resolve (cleaned up)
        assert(hand_1_after.cards.len() == 0, 'P1 hand should be cleaned');
        assert(hand_2_after.cards.len() == 0, 'P2 hand should be cleaned');
        assert(hand_3_after.cards.len() == 0, 'P3 hand should be cleaned');
    }

    /// Test #144 Requirement 2: Clean all stored cards after each round
    #[test]
    fn test_resolve_round_cleans_all_cards() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_game_with_round_in_progress(ref world);
        
        // Setup all players with cards
        let hand_1 = create_hand_with_cards(
            PLAYER_1(),
            array![create_card(14, Suits::SPADES), create_card(13, Suits::HEARTS)]
        );
        let hand_2 = create_hand_with_cards(
            PLAYER_2(),
            array![create_card(12, Suits::CLUBS), create_card(11, Suits::DIAMONDS)]
        );
        let hand_3 = create_hand_with_cards(
            PLAYER_3(),
            array![create_card(10, Suits::SPADES), create_card(9, Suits::HEARTS)]
        );
        
        world.write_models(array![@hand_1, @hand_2, @hand_3].span());
        
        // Verify cards exist before resolution
        let player_1_hand_before: Hand = world.read_model(PLAYER_1());
        let player_2_hand_before: Hand = world.read_model(PLAYER_2());
        let player_3_hand_before: Hand = world.read_model(PLAYER_3());
        
        assert(player_1_hand_before.cards.len() > 0, 'P1 should have cards before');
        assert(player_2_hand_before.cards.len() > 0, 'P2 should have cards before');
        assert(player_3_hand_before.cards.len() > 0, 'P3 should have cards before');
        
        // [Execute] - Call resolve_round directly
        systems.actions.resolve_round(1);
        
        // [Assert] - All cards should be cleaned
        let player_1_hand_after: Hand = world.read_model(PLAYER_1());
        let player_2_hand_after: Hand = world.read_model(PLAYER_2());
        let player_3_hand_after: Hand = world.read_model(PLAYER_3());
        
        assert(player_1_hand_after.cards.len() == 0, 'P1 cards should be cleaned');
        assert(player_2_hand_after.cards.len() == 0, 'P2 cards should be cleaned');
        assert(player_3_hand_after.cards.len() == 0, 'P3 cards should be cleaned');
    }

    /// Test #144 Requirement 3: Reset both merkle tree roots to zero
    #[test]
    fn test_resolve_round_resets_game_roots() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_game_with_round_in_progress(ref world);
        
        // Set non-zero roots before resolution
        let mut game: Game = world.read_model(1_u64);
        game.deck_root = 123456789;
        game.dealt_cards_root = 987654321;
        world.write_model(@game);
        
        // Setup all players with cards
        let hand_1 = create_hand_with_cards(
            PLAYER_1(),
            array![create_card(14, Suits::SPADES), create_card(13, Suits::HEARTS)]
        );
        let hand_2 = create_hand_with_cards(
            PLAYER_2(),
            array![create_card(12, Suits::CLUBS), create_card(11, Suits::DIAMONDS)]
        );
        let hand_3 = create_hand_with_cards(
            PLAYER_3(),
            array![create_card(10, Suits::SPADES), create_card(9, Suits::HEARTS)]
        );
        
        world.write_models(array![@hand_1, @hand_2, @hand_3].span());
        
        // Verify roots are non-zero before
        let game_before: Game = world.read_model(1_u64);
        assert(game_before.deck_root != 0, 'deck_root_not_zero');
        assert(game_before.dealt_cards_root != 0, 'dealt_root_not_zero');
        
        // [Execute] - Call resolve_round directly
        systems.actions.resolve_round(1);
        
        // [Assert] - Both roots should be reset to zero
        let game_after: Game = world.read_model(1_u64);
        assert(game_after.deck_root == 0, 'deck_root_should_be_zero');
        assert(game_after.dealt_cards_root == 0, 'dealt_root_should_be_zero');
        
        // Verify game state is updated correctly
        assert(!game_after.round_in_progress, 'round_not_ended');
        assert(game_after.current_round > 1, 'round_not_incremented');
    }

    /// Test edge case: All players have empty hands
    #[test]
    #[should_panic(expected: ('No valid hands to resolve round', 'ENTRYPOINT_FAILED'))]
    fn test_resolve_round_fails_when_all_hands_empty() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_game_with_round_in_progress(ref world);
        
        // Setup all players with empty hands
        let hand_1 = create_empty_hand(PLAYER_1());
        let hand_2 = create_empty_hand(PLAYER_2());
        let hand_3 = create_empty_hand(PLAYER_3());
        
        world.write_models(array![@hand_1, @hand_2, @hand_3].span());
        
        // [Execute] - Should panic because no valid hands exist
        systems.actions.resolve_round(1);
    }

    /// Test that game state is updated correctly during round resolution
    #[test]
    fn test_resolve_round_updates_game_state() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_game_with_round_in_progress(ref world);
        
        // Setup all players with cards
        let hand_1 = create_hand_with_cards(
            PLAYER_1(),
            array![create_card(14, Suits::SPADES), create_card(13, Suits::HEARTS)]
        );
        let hand_2 = create_hand_with_cards(
            PLAYER_2(),
            array![create_card(12, Suits::CLUBS), create_card(11, Suits::DIAMONDS)]
        );
        let hand_3 = create_hand_with_cards(
            PLAYER_3(),
            array![create_card(10, Suits::SPADES), create_card(9, Suits::HEARTS)]
        );
        
        world.write_models(array![@hand_1, @hand_2, @hand_3].span());
        
        // [Execute] - Call resolve_round directly
        systems.actions.resolve_round(1);
        
        // [Assert] - Game state should be updated
        let game: Game = world.read_model(1_u64);
        assert(!game.round_in_progress, 'Round should not be in progress');
        assert(game.current_round > 1, 'Round number should increment');
        assert(game.community_cards.len() == 0, 'Community cards should be empty');
        assert(game.current_bet == 0, 'Current bet should be reset');
    }

    /// Test player state reset after round resolution
    #[test]
    fn test_resolve_round_resets_player_states() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_game_with_round_in_progress(ref world);
        
        // Setup players with different current bets
        let mut player_1: Player = world.read_model(PLAYER_1());
        let mut player_2: Player = world.read_model(PLAYER_2());
        let mut player_3: Player = world.read_model(PLAYER_3());
        
        player_1.current_bet = 500;
        player_2.current_bet = 300;
        player_3.current_bet = 200;
        
        world.write_models(array![@player_1, @player_2, @player_3].span());
        
        // Setup all players with cards
        let hand_1 = create_hand_with_cards(
            PLAYER_1(),
            array![create_card(14, Suits::SPADES), create_card(13, Suits::HEARTS)]
        );
        let hand_2 = create_hand_with_cards(
            PLAYER_2(),
            array![create_card(12, Suits::CLUBS), create_card(11, Suits::DIAMONDS)]
        );
        let hand_3 = create_hand_with_cards(
            PLAYER_3(),
            array![create_card(10, Suits::SPADES), create_card(9, Suits::HEARTS)]
        );
        
        world.write_models(array![@hand_1, @hand_2, @hand_3].span());
        
        // [Execute] - Call resolve_round directly
        systems.actions.resolve_round(1);
        
        // [Assert] - Player states should be reset
        let player_1_after: Player = world.read_model(PLAYER_1());
        let player_2_after: Player = world.read_model(PLAYER_2());
        let player_3_after: Player = world.read_model(PLAYER_3());
        
        assert(player_1_after.current_bet == 0, 'P1 current_bet should be reset');
        assert(player_2_after.current_bet == 0, 'P2 current_bet should be reset');
        assert(player_3_after.current_bet == 0, 'P3 current_bet should be reset');
        
        assert(player_1_after.in_round == true, 'P1 should be in next round');
        assert(player_2_after.in_round == true, 'P2 should be in next round');
        assert(player_3_after.in_round == true, 'P3 should be in next round');
    }

    /// Test mixed scenario: some players with cards, some with empty hands
    #[test]
    fn test_resolve_round_mixed_hands_scenario() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_game_with_round_in_progress(ref world);
        
        // Setup mixed scenario: P1 has cards, P2 empty, P3 has cards
        let hand_1 = create_hand_with_cards(
            PLAYER_1(),
            array![create_card(14, Suits::SPADES), create_card(13, Suits::HEARTS)]
        );
        let hand_2 = create_empty_hand(PLAYER_2()); // Empty hand
        let hand_3 = create_hand_with_cards(
            PLAYER_3(),
            array![create_card(10, Suits::SPADES), create_card(9, Suits::HEARTS)]
        );
        
        world.write_models(array![@hand_1, @hand_2, @hand_3].span());
        
        // [Execute] - Call resolve_round directly
        systems.actions.resolve_round(1);
        
        // [Assert] - All hands should be cleaned regardless of initial state
        let hand_1_after: Hand = world.read_model(PLAYER_1());
        let hand_2_after: Hand = world.read_model(PLAYER_2());
        let hand_3_after: Hand = world.read_model(PLAYER_3());
        
        assert(hand_1_after.cards.len() == 0, 'P1 hand should be cleaned');
        assert(hand_2_after.cards.len() == 0, 'P2 hand should remain empty');
        assert(hand_3_after.cards.len() == 0, 'P3 hand should be cleaned');
        
        // Game should still progress normally
        let game: Game = world.read_model(1_u64);
        assert(!game.round_in_progress, 'Round should not be in progress');
        assert(game.deck_root == 0, 'Deck root should be reset');
        assert(game.dealt_cards_root == 0, 'Dealt root should be reset');
    }

    /// Test community cards are cleared after round resolution
    #[test]
    fn test_resolve_round_clears_community_cards() {
        // [Setup]
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);
        mock_game_with_round_in_progress(ref world);
        
        // Add community cards to the game
        let mut game: Game = world.read_model(1_u64);
        game.community_cards = array![
            create_card(14, Suits::HEARTS),
            create_card(13, Suits::SPADES),
            create_card(12, Suits::CLUBS)
        ];
        world.write_model(@game);
        
        // Setup all players with cards
        let hand_1 = create_hand_with_cards(
            PLAYER_1(),
            array![create_card(14, Suits::SPADES), create_card(13, Suits::HEARTS)]
        );
        let hand_2 = create_hand_with_cards(
            PLAYER_2(),
            array![create_card(12, Suits::CLUBS), create_card(11, Suits::DIAMONDS)]
        );
        let hand_3 = create_hand_with_cards(
            PLAYER_3(),
            array![create_card(10, Suits::SPADES), create_card(9, Suits::HEARTS)]
        );
        
        world.write_models(array![@hand_1, @hand_2, @hand_3].span());
        
        // Verify community cards exist before
        let game_before: Game = world.read_model(1_u64);
        assert(game_before.community_cards.len() > 0, 'cards_not_empty');
        
        // [Execute] - Call resolve_round directly
        systems.actions.resolve_round(1);
        
        // [Assert] - Community cards should be cleared
        let game_after: Game = world.read_model(1_u64);
        assert(game_after.community_cards.len() == 0, 'cards_not_cleared');
    }
}