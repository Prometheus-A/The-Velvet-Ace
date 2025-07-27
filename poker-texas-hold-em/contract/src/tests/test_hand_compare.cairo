/// TODO

/// CHECK VALUES FOR KICKER_SPLIT EQUALS FALSE, ONLY WHEN `extract_kicker` HAS BEEN
/// IMPLEMENTED FOR KICKER_SPLIT EQUALS FALSE, winning_hands.len() == 1. USE TWO HANDS OF THE
/// SAME RANK
///
/// TODO: TEST COMPARE HANDS OF VARIOUS NUMBER OF HANDS.
/// // for the test
// assert that the array of kicking cards are present in the winning hands
// .. or make
//
#[cfg(test)]
mod tests {
    use core::num::traits::Zero;
    use starknet::{ContractAddress, contract_address_const};
    use crate::models::card::{Card, Royals, Suits};
    use crate::models::game::{GameMode, GameParams, ShowdownType};
    use crate::models::hand::{Hand, HandRank, HandTrait};

    // convenience constructor for cards
    fn c(value: u16, suit: u8) -> Card {
        Card { value, suit }
    }

    fn mk_initial_hand(player: ContractAddress, cards: Array<Card>) -> Hand {
        assert(cards.len() == 2, 'Cards must be exactly 2');
        Hand { player, cards }
    }

    fn setup_game_params(kicker_split: bool) -> GameParams {
        GameParams {
            game_mode: GameMode::CashGame,
            ownable: Option::None,
            max_no_of_players: 9,
            small_blind: 10,
            big_blind: 20,
            no_of_decks: 1,
            kicker_split: kicker_split,
            min_amount_of_chips: 2000,
            blind_spacing: 10,
            showdown_type: ShowdownType::Gathered,
        }
    }

    #[test]
    fn test_compare_one_pair_kicker_split_true() {
        let p1_addr = contract_address_const::<'P1'>();
        let p2_addr = contract_address_const::<'P2'>();

        // Player initial hands
        let p1_hand = mk_initial_hand(p1_addr, array![c(14, 0), c(13, 3)]); // A♠ K♥
        let p2_hand = mk_initial_hand(p2_addr, array![c(14, 1), c(12, 2)]); // A♣ Q♦

        // Community cards
        let community = array![
            c(14, 2), c(9, 0), c(7, 3), c(3, 2), c(2, 1),
        ]; // A♦ 9♠ 7♥ 3♦ 2♣

        let game_params_true = setup_game_params(true);

        let (winners, rank, kicker_cards) = HandTrait::compare_hands(
            array![p1_hand.clone(), p2_hand.clone()], community, game_params_true,
        );

        let hand_rank: ByteArray = rank.into();

        println!("COMPARE HAND RANK_U16: {:?}", hand_rank);

        // Assertions
        assert(winners.len() == 1, 'Expected one winner');
        assert(winners.at(0).player == @p1_addr, 'P1 should win with K kicker');
        // Check original cards are returned
        assert(winners.at(0).cards == @p1_hand.cards, 'Winner cards mismatch');
        assert(rank == HandRank::HIGH_CARD, 'Rank should be High Card');

        // P1's best 5 cards: A♠ A♦ K♥ 9♠ 7♥ (Order might vary based on evaluation)
        // We expect these cards to be returned as kickers when kicker_split=true and one winner
        assert(kicker_cards.len() == 5, 'Expected 5 kicker cards');
    }

    #[test]
    fn test_compare_one_pair_kicker_split_false() {
        let p1_addr = contract_address_const::<'P1'>();
        let p2_addr = contract_address_const::<'P2'>();

        // Player initial hands (2 cards each)
        let p1_initial_hand = mk_initial_hand(p1_addr, array![c(14, 0), c(13, 3)]); // A♠ K♥
        let p2_initial_hand = mk_initial_hand(p2_addr, array![c(14, 1), c(12, 2)]); // A♣ Q♦

        // Community cards (5 cards)
        let community = array![
            c(14, 2), c(9, 0), c(7, 3), c(3, 2), c(2, 1),
        ]; // A♦ 9♠ 7♥ 3♦ 2♣
        // P1 best 5: A♠ A♦ K♥ 9♠ 7♥ (Pair Aces, K kicker)
        // P2 best 5: A♣ A♦ Q♦ 9♠ 7♥ (Pair Aces, Q kicker)

        let game_params_false = setup_game_params(false);

        let (winners, rank, kicker_cards) = HandTrait::compare_hands(
            array![p1_initial_hand.clone(), p2_initial_hand.clone()], community, game_params_false,
        );

        // Assertions
        assert(winners.len() == 0, 'Expected no winners');

        assert(rank == HandRank::HIGH_CARD, 'Rank should be High Card');
        assert(kicker_cards.len() == 0, 'Expected no kicker cards');
    }
}
