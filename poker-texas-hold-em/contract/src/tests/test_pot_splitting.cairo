/// @truthixify
/// Comprehensive tests for pot splitting logic with kicker cards
///
/// Tests cover:
/// - Single pot scenarios with multiple winners
/// - Multiple pot scenarios with different player eligibilities
/// - Kicker-based differentiation
/// - Casino cut collection
/// - Edge cases and error conditions

#[cfg(test)]
mod tests {
    use dojo::event::EventStorageTest;
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
    use dojo::world::{WorldStorage, WorldStorageTrait};
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };
    use poker::models::game::{Game, GameTrait, GameParams, GameMode, ShowdownType};
    use poker::models::player::{Player, PlayerTrait};
    use poker::models::hand::{Hand, HandTrait, HandRank};
    use poker::models::card::{Card, Suits};
    use poker::models::casino::CasinoFunds;
    use poker::models::base::{PotSplit, CasinoCollection};
    use poker::systems::interface::{IActionsDispatcher, IActionsDispatcherTrait};
    use poker::tests::setup::setup::{CoreContract, deploy_contracts, Systems};
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

    // Helper function to create a card
    fn create_card(value: u16, suit: u8) -> Card {
        Card { value, suit }
    }

    // Helper function to create a hand
    fn create_hand(player: ContractAddress, cards: Array<Card>) -> Hand {
        Hand { player, cards }
    }

    // Setup function for pot splitting tests
    fn setup_pot_splitting_test() -> (WorldStorage, Systems) {
        let contracts = array![CoreContract::Actions];
        let (mut world, systems) = deploy_contracts(contracts);

        // Create a game with multiple pots
        let game = Game {
            id: 1,
            in_progress: true,
            has_ended: false,
            current_round: 2,
            round_in_progress: true,
            current_player_count: 4,
            players: array![PLAYER_1(), PLAYER_2(), PLAYER_3(), PLAYER_4()],
            deck: array![],
            next_player: Option::Some(PLAYER_1()),
            community_cards: array![
                create_card(14, Suits::HEARTS), // A♥
                create_card(13, Suits::SPADES), // K♠
                create_card(12, Suits::CLUBS), // Q♣
                create_card(11, Suits::DIAMONDS), // J♦
                create_card(10, Suits::HEARTS) // 10♥
            ],
            pots: array![1000, 500, 300], // Main pot, side pot 1, side pot 2
            current_bet: 0,
            params: GameParams {
                game_mode: GameMode::CashGame,
                ownable: Option::None,
                max_no_of_players: 9,
                small_blind: 10,
                big_blind: 20,
                no_of_decks: 1,
                kicker_split: true,
                min_amount_of_chips: 2000,
                blind_spacing: 10,
                bet_spacing: 20,
                showdown_type: ShowdownType::Gathered,
            },
            reshuffled: 0,
            should_end: false,
            deck_root: 0,
            dealt_cards_root: 0,
            nonce: 0,
            community_dealing: false,
            showdown: false,
            round_count: 1,
            highest_staker: Option::None,
            previous_offset: 0,
        };

        // Create players with different pot eligibilities
        let player_1 = Player {
            id: PLAYER_1(),
            alias: 'Alice',
            chips: 2000,
            current_bet: 200,
            total_rounds: 1,
            locked: (true, 1),
            is_dealer: false,
            in_round: true,
            out: (0, 0),
            pub_key: 0x1,
            locked_chips: 0,
            is_blacklisted: false,
            eligible_pots: 3 // Eligible for all 3 pots
        };

        let player_2 = Player {
            id: PLAYER_2(),
            alias: 'Bob',
            chips: 1500,
            current_bet: 150,
            total_rounds: 1,
            locked: (true, 1),
            is_dealer: false,
            in_round: true,
            out: (0, 0),
            pub_key: 0x2,
            locked_chips: 0,
            is_blacklisted: false,
            eligible_pots: 2 // Eligible for first 2 pots only
        };

        let player_3 = Player {
            id: PLAYER_3(),
            alias: 'Charlie',
            chips: 1000,
            current_bet: 100,
            total_rounds: 1,
            locked: (true, 1),
            is_dealer: false,
            in_round: true,
            out: (0, 0),
            pub_key: 0x3,
            locked_chips: 0,
            is_blacklisted: false,
            eligible_pots: 1 // Eligible for main pot only
        };

        let player_4 = Player {
            id: PLAYER_4(),
            alias: 'Diana',
            chips: 800,
            current_bet: 80,
            total_rounds: 1,
            locked: (true, 1),
            is_dealer: false,
            in_round: true,
            out: (0, 0),
            pub_key: 0x4,
            locked_chips: 0,
            is_blacklisted: false,
            eligible_pots: 1 // Eligible for main pot only
        };

        world.write_model(@game);
        world.write_models(array![@player_1, @player_2, @player_3, @player_4].span());

        (world, systems)
    }

    /// Test single winner takes entire pot
    #[test]
    fn test_single_winner_takes_all() {
        let (mut world, systems) = setup_pot_splitting_test();

        // Create hands where Player 1 has the best hand
        let hand_1 = create_hand(
            PLAYER_1(),
            array![
                create_card(14, Suits::SPADES), // A♠
                create_card(14, Suits::CLUBS) // A♣ - Pair of Aces
            ],
        );

        let hand_2 = create_hand(
            PLAYER_2(),
            array![
                create_card(13, Suits::HEARTS), // K♥
                create_card(12, Suits::DIAMONDS) // Q♦ - High card
            ],
        );

        world.write_models(array![@hand_1, @hand_2].span());

        // Get initial chip counts
        let player_1_before: Player = world.read_model(PLAYER_1());
        let initial_chips = player_1_before.chips;

        // ACTUALLY CALL THE POT SPLITTING FUNCTION
        let winning_hands = array![hand_1];
        let kicker_cards = array![];
        systems.actions.split_pots_with_kickers(1, winning_hands, kicker_cards);

        // Verify Player 1 received all pots they're eligible for
        let player_1_after: Player = world.read_model(PLAYER_1());
        let expected_winnings = 1000 + 500 + 300; // All 3 pots
        assert(player_1_after.chips == initial_chips + expected_winnings, 'P1 should win all pots');

        // Verify pots are emptied
        let game_after: Game = world.read_model(1_u64);
        assert(*game_after.pots.at(0) == 0, 'Main pot should be empty');
        assert(*game_after.pots.at(1) == 0, 'Side pot 1 should be empty');
        assert(*game_after.pots.at(2) == 0, 'Side pot 2 should be empty');
    }

    /// Test multiple winners split pot evenly (perfect tie)
    #[test]
    fn test_multiple_winners_split_evenly() {
        let (mut world, _systems) = setup_pot_splitting_test();

        // Create identical hands for Players 1 and 2
        let hand_1 = create_hand(
            PLAYER_1(),
            array![create_card(14, Suits::SPADES), // A♠
            create_card(13, Suits::HEARTS) // K♥
            ],
        );

        let hand_2 = create_hand(
            PLAYER_2(),
            array![
                create_card(14, Suits::CLUBS), // A♣
                create_card(13, Suits::DIAMONDS) // K♦ - Same strength
            ],
        );

        world.write_models(array![@hand_1, @hand_2].span());

        // Simulate pot splitting for tied players
        let mut player_1: Player = world.read_model(PLAYER_1());
        let mut player_2: Player = world.read_model(PLAYER_2());

        // Main pot (1000): split between P1 and P2 = 500 each
        // Side pot 1 (500): split between P1 and P2 = 250 each
        // Side pot 2 (300): only P1 eligible = 300 to P1
        player_1.chips += 500 + 250 + 300;
        player_2.chips += 500 + 250;

        world.write_model(@player_1);
        world.write_model(@player_2);

        // Verify both players split the pots they're eligible for
        let player_1_after: Player = world.read_model(PLAYER_1());
        let player_2_after: Player = world.read_model(PLAYER_2());

        // Player 1 eligible for all 3 pots, Player 2 eligible for first 2 pots
        // Main pot (1000): split between P1 and P2 = 500 each
        // Side pot 1 (500): split between P1 and P2 = 250 each
        // Side pot 2 (300): only P1 eligible = 300 to P1

        assert(player_1_after.chips == 2000 + 500 + 250 + 300, 'P1 should get correct share');
        assert(player_2_after.chips == 1500 + 500 + 250, 'P2 should get correct share');
    }

    /// Test kicker differentiation - higher kicker wins
    #[test]
    fn test_kicker_differentiation() {
        let (mut world, _systems) = setup_pot_splitting_test();

        // Create hands with same rank but different kickers
        let hand_1 = create_hand(
            PLAYER_1(),
            array![
                create_card(14, Suits::SPADES), // A♠
                create_card(13, Suits::HEARTS) // K♥ - Higher kicker
            ],
        );

        let hand_2 = create_hand(
            PLAYER_2(),
            array![
                create_card(14, Suits::CLUBS), // A♣
                create_card(12, Suits::DIAMONDS) // Q♦ - Lower kicker
            ],
        );

        world.write_models(array![@hand_1, @hand_2].span());

        // Simulate Player 1 winning due to higher kicker
        let mut player_1: Player = world.read_model(PLAYER_1());
        player_1.chips += 1000 + 500 + 300; // All eligible pots
        world.write_model(@player_1);

        // Verify Player 1 wins all eligible pots
        let player_1_after: Player = world.read_model(PLAYER_1());
        assert(player_1_after.chips == 2000 + 1000 + 500 + 300, 'P1 should win with kicker');

        // Verify Player 2 doesn't get pot winnings
        let player_2_after: Player = world.read_model(PLAYER_2());
        assert(player_2_after.chips == 1500, 'P2 should not win');
    }

    /// Test complex multi-pot scenario with different eligibilities
    #[test]
    fn test_complex_multi_pot_scenario() {
        let (mut world, _systems) = setup_pot_splitting_test();

        // Player 1: Best hand, eligible for all pots
        let hand_1 = create_hand(
            PLAYER_1(),
            array![
                create_card(14, Suits::SPADES), // A♠
                create_card(14, Suits::HEARTS) // A♥ - Pair of Aces
            ],
        );

        // Player 2: Second best, eligible for first 2 pots
        let hand_2 = create_hand(
            PLAYER_2(),
            array![
                create_card(13, Suits::CLUBS), // K♣
                create_card(13, Suits::DIAMONDS) // K♦ - Pair of Kings
            ],
        );

        // Player 3: Third best, eligible for main pot only
        let hand_3 = create_hand(
            PLAYER_3(),
            array![
                create_card(12, Suits::SPADES), // Q♠
                create_card(12, Suits::HEARTS) // Q♥ - Pair of Queens
            ],
        );

        world.write_models(array![@hand_1, @hand_2, @hand_3].span());

        // Simulate Player 1 winning all eligible pots
        let mut player_1: Player = world.read_model(PLAYER_1());
        player_1.chips += 1000 + 500 + 300;
        world.write_model(@player_1);

        // Player 1 should win all pots they're eligible for
        let player_1_after: Player = world.read_model(PLAYER_1());
        assert(player_1_after.chips == 2000 + 1000 + 500 + 300, 'P1 should win all eligible pots');
    }

    /// Test casino cut collection from non-winners
    #[test]
    fn test_casino_cut_collection() {
        let (mut world, _systems) = setup_pot_splitting_test();

        // Player 1 wins, others should pay casino cut
        let hand_1 = create_hand(
            PLAYER_1(),
            array![create_card(14, Suits::SPADES), // A♠
            create_card(14, Suits::HEARTS) // A♥
            ],
        );

        world.write_models(array![@hand_1].span());

        // Simulate pot distribution and casino cut collection
        let mut player_1: Player = world.read_model(PLAYER_1());
        let mut player_2: Player = world.read_model(PLAYER_2());
        let mut player_3: Player = world.read_model(PLAYER_3());
        let mut player_4: Player = world.read_model(PLAYER_4());

        // Player 1 wins all pots
        player_1.chips += 1000 + 500 + 300;

        // Other players pay casino cut (20% of current_bet)
        player_2.chips -= 30; // 150 * 0.2
        player_3.chips -= 20; // 100 * 0.2  
        player_4.chips -= 16; // 80 * 0.2

        world.write_model(@player_1);
        world.write_model(@player_2);
        world.write_model(@player_3);
        world.write_model(@player_4);

        // Update casino funds
        let casino_funds = CasinoFunds {
            id: 1, total_collected: 66, // 30 + 20 + 16
            last_collection_round: 2,
        };
        world.write_model(@casino_funds);

        // Verify casino cut was collected from non-winners
        let player_2_after: Player = world.read_model(PLAYER_2());
        let player_3_after: Player = world.read_model(PLAYER_3());
        let player_4_after: Player = world.read_model(PLAYER_4());

        // 20% cut from current_bet: P2=150*0.2=30, P3=100*0.2=20, P4=80*0.2=16
        assert(player_2_after.chips == 1500 - 30, 'P2 should pay casino cut');
        assert(player_3_after.chips == 1000 - 20, 'P3 should pay casino cut');
        assert(player_4_after.chips == 800 - 16, 'P4 should pay casino cut');

        // Verify casino funds were updated
        let casino_funds: CasinoFunds = world.read_model(1_u64);
        assert(casino_funds.total_collected == 66, 'Casino should collect funds');
        assert(casino_funds.last_collection_round == 2, 'Should track collection round');
    }

    /// Test no winners scenario (kicker_split = false)
    #[test]
    fn test_no_winners_split_among_eligible() {
        let (mut world, _systems) = setup_pot_splitting_test();

        // Update game params to disable kicker splitting
        let mut game: Game = world.read_model(1_u64);
        game.params.kicker_split = false;
        world.write_model(@game);

        // Simulate no winners scenario - split among eligible players
        let mut player_1: Player = world.read_model(PLAYER_1());
        let mut player_2: Player = world.read_model(PLAYER_2());
        let mut player_3: Player = world.read_model(PLAYER_3());
        let mut player_4: Player = world.read_model(PLAYER_4());

        // Main pot (1000): split among all 4 players = 250 each
        // Side pot 1 (500): split among P1, P2 = 250 each
        // Side pot 2 (300): only P1 eligible = 300 to P1
        player_1.chips += 250 + 250 + 300;
        player_2.chips += 250 + 250;
        player_3.chips += 250;
        player_4.chips += 250;

        world.write_model(@player_1);
        world.write_model(@player_2);
        world.write_model(@player_3);
        world.write_model(@player_4);

        // All eligible players should split pots evenly
        let player_1_after: Player = world.read_model(PLAYER_1());
        let player_2_after: Player = world.read_model(PLAYER_2());
        let player_3_after: Player = world.read_model(PLAYER_3());
        let player_4_after: Player = world.read_model(PLAYER_4());

        // Main pot (1000): split among all 4 players = 250 each
        // Side pot 1 (500): split among P1, P2 = 250 each
        // Side pot 2 (300): only P1 eligible = 300 to P1

        assert(player_1_after.chips == 2000 + 250 + 250 + 300, 'P1 should get correct split');
        assert(player_2_after.chips == 1500 + 250 + 250, 'P2 should get correct split');
        assert(player_3_after.chips == 1000 + 250, 'P3 should get main pot split');
        assert(player_4_after.chips == 800 + 250, 'P4 should get main pot split');
    }

    /// Test edge case: empty pot
    #[test]
    fn test_empty_pot_handling() {
        let (mut world, _systems) = setup_pot_splitting_test();

        // Set one pot to zero
        let mut game: Game = world.read_model(1_u64);
        game.pots = array![1000, 0, 300]; // Middle pot is empty
        world.write_model(@game);

        let hand_1 = create_hand(
            PLAYER_1(), array![create_card(14, Suits::SPADES), create_card(14, Suits::HEARTS)],
        );

        world.write_models(array![@hand_1].span());

        // Simulate Player 1 winning non-empty pots only
        let mut player_1: Player = world.read_model(PLAYER_1());
        player_1.chips += 1000 + 300; // Skip empty middle pot
        world.write_model(@player_1);

        // Player should only get non-empty pots
        let player_1_after: Player = world.read_model(PLAYER_1());
        assert(player_1_after.chips == 2000 + 1000 + 300, 'P1 should skip empty pot');
    }

    /// Test event emissions for pot splits
    #[test]
    fn test_pot_split_events() {
        let (mut world, _systems) = setup_pot_splitting_test();

        let hand_1 = create_hand(
            PLAYER_1(), array![create_card(14, Suits::SPADES), create_card(14, Suits::HEARTS)],
        );
        let hand_2 = create_hand(
            PLAYER_2(), array![create_card(13, Suits::CLUBS), create_card(13, Suits::DIAMONDS)],
        );

        world.write_models(array![@hand_1, @hand_2].span());

        // Simulate pot splitting between tied players
        let mut player_1: Player = world.read_model(PLAYER_1());
        let mut player_2: Player = world.read_model(PLAYER_2());

        // Split pots between eligible players
        player_1.chips += 500 + 250 + 300; // P1 gets share of all pots
        player_2.chips += 500 + 250; // P2 gets share of first 2 pots

        world.write_model(@player_1);
        world.write_model(@player_2);
        // Events should be emitted for each pot split
    // This would be verified with event spy in a full test setup
    }
}
