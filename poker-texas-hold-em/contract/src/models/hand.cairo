use poker::traits::hand::HandTrait;
use starknet::ContractAddress;
use super::card::Card;

/// Created once and for all for every available player.
#[derive(Serde, Drop, Clone, Debug)]
#[dojo::model]
pub struct Hand {
    #[key]
    player: ContractAddress,
    cards: Array<Card>,
}

/// This is the hand ranks of player hand cards plus part of the community cards to make it 5 in
/// total
/// ROYAL_FLUSH: Ace, King, Queen, Jack and 10, all of the same suit.
/// STRAIGHT_FLUSH: Five cards in a row, all of the same suit.
/// FOUR_OF_A_KIND: Four cards of the same rank (or value as in the model)
/// FULL_HOUSE: Three cards of one rank (value) and two cards of another rank (value)
/// FLUSH: Five cards of the same suit
/// STRAIGHT: Five cards in a row, but not of the same suit
/// THREE_OF_A_KIND: Three cards of the same rank.
/// TWO_PAIR: Two cards of one rank, and two cards of another rank.
/// ONE_PAIR: Two cards of the same rank.
/// HIGH_CARD: None of the above.
pub mod HandRank {
    pub const ROYAL_FLUSH: u16 = 10;
    pub const STRAIGHT_FLUSH: u16 = 9;
    pub const FOUR_OF_A_KIND: u16 = 8;
    pub const FULL_HOUSE: u16 = 7;
    pub const FLUSH: u16 = 6;
    pub const STRAIGHT: u16 = 5;
    pub const THREE_OF_A_KIND: u16 = 4;
    pub const TWO_PAIR: u16 = 3;
    pub const ONE_PAIR: u16 = 2;
    pub const HIGH_CARD: u16 = 1;
}

#[cfg(test)]
mod tests {
    use array::{ArrayTrait, SpanTrait};
    use debug::PrintTrait;
    use poker::traits::hand::HandTrait;
    use starknet::{ContractAddress, contract_address_const};
    use super::super::card::{Card, Suit, Value};
    use super::{Hand, HandRank};

    // @ShantelPeters
    // Helper function to create a hand with specified cards for testing
    // Returns a Hand struct with the given cards and a default player address
    fn create_test_hand(cards: Array<Card>) -> Hand {
        Hand { player: contract_address_const::<0x1>(), cards: cards }
    }

    // @ShantelPeters
    // Create a card with specified suit and value
    // Convenience function to make test code more readable
    fn create_card(suit: u8, value: u8) -> Card {
        Card { suit: suit, value: value }
    }

    // @ShantelPeters
    // Test for Royal Flush
    // Verifies that the rank function correctly identifies a royal flush
    // and returns the appropriate rank value
    #[test]
    fn test_royal_flush() {
        // Create a royal flush in hearts (A, K, Q, J, 10 all hearts)
        let mut cards: Array<Card> = array![
            create_card(Suit::HEARTS, Value::ACE),
            create_card(Suit::HEARTS, Value::KING),
            create_card(Suit::HEARTS, Value::QUEEN),
            create_card(Suit::HEARTS, Value::JACK),
            create_card(Suit::HEARTS, Value::TEN),
        ];

        let hand = create_test_hand(cards);
        let rank = hand.rank();

        // Check that rank is correctly identified as ROYAL_FLUSH
        assert(rank == HandRank::ROYAL_FLUSH, 'Should be a royal flush');

        // Test royal flush in a different suit
        let mut spades_royal: Array<Card> = array![
            create_card(Suit::SPADES, Value::ACE),
            create_card(Suit::SPADES, Value::KING),
            create_card(Suit::SPADES, Value::QUEEN),
            create_card(Suit::SPADES, Value::JACK),
            create_card(Suit::SPADES, Value::TEN),
        ];

        let spades_hand = create_test_hand(spades_royal);
        assert(spades_hand.rank() == HandRank::ROYAL_FLUSH, 'Spades royal flush failed');
    }

    // @ShantelPeters
    // Test for Straight Flush
    // Verifies that the rank function correctly identifies a straight flush
    // and handles different straight flush combinations properly
    #[test]
    fn test_straight_flush() {
        // Create a straight flush 9-10-J-Q-K in clubs
        let mut cards: Array<Card> = array![
            create_card(Suit::CLUBS, Value::NINE),
            create_card(Suit::CLUBS, Value::TEN),
            create_card(Suit::CLUBS, Value::JACK),
            create_card(Suit::CLUBS, Value::QUEEN),
            create_card(Suit::CLUBS, Value::KING),
        ];

        let hand = create_test_hand(cards);
        let rank = hand.rank();

        // Check that rank is correctly identified as STRAIGHT_FLUSH
        assert(rank == HandRank::STRAIGHT_FLUSH, 'Should be straight flush');

        // Test the lowest straight flush (A-2-3-4-5)
        let mut low_straight_flush: Array<Card> = array![
            create_card(Suit::DIAMONDS, Value::ACE),
            create_card(Suit::DIAMONDS, Value::TWO),
            create_card(Suit::DIAMONDS, Value::THREE),
            create_card(Suit::DIAMONDS, Value::FOUR),
            create_card(Suit::DIAMONDS, Value::FIVE),
        ];

        let low_hand = create_test_hand(low_straight_flush);
        assert(low_hand.rank() == HandRank::STRAIGHT_FLUSH, 'Low straight flush failed');
    }

    // @ShantelPeters
    // Test for Four of a Kind
    // Verifies that the rank function correctly identifies four of a kind
    // and properly handles kickers
    #[test]
    fn test_four_of_a_kind() {
        // Create four of a kind: four 8s with a King kicker
        let mut cards: Array<Card> = array![
            create_card(Suit::HEARTS, Value::EIGHT),
            create_card(Suit::DIAMONDS, Value::EIGHT),
            create_card(Suit::CLUBS, Value::EIGHT),
            create_card(Suit::SPADES, Value::EIGHT),
            create_card(Suit::HEARTS, Value::KING),
        ];

        let hand = create_test_hand(cards);
        let rank = hand.rank();

        // Check that rank is correctly identified as FOUR_OF_A_KIND
        assert(rank == HandRank::FOUR_OF_A_KIND, 'Should be four of a kind');

        // Test with a different kicker
        let mut diff_kicker: Array<Card> = array![
            create_card(Suit::HEARTS, Value::EIGHT),
            create_card(Suit::DIAMONDS, Value::EIGHT),
            create_card(Suit::CLUBS, Value::EIGHT),
            create_card(Suit::SPADES, Value::EIGHT),
            create_card(Suit::HEARTS, Value::FIVE),
        ];

        let diff_hand = create_test_hand(diff_kicker);
        assert(diff_hand.rank() == HandRank::FOUR_OF_A_KIND, 'Four of kind with diff kicker');
    }

    // @ShantelPeters
    // Test for Full House
    // Verifies that the rank function correctly identifies a full house
    // and handles different full house combinations properly
    #[test]
    fn test_full_house() {
        // Create a full house: three 7s and two Jacks
        let mut cards: Array<Card> = array![
            create_card(Suit::HEARTS, Value::SEVEN),
            create_card(Suit::DIAMONDS, Value::SEVEN),
            create_card(Suit::CLUBS, Value::SEVEN),
            create_card(Suit::HEARTS, Value::JACK),
            create_card(Suit::DIAMONDS, Value::JACK),
        ];

        let hand = create_test_hand(cards);
        let rank = hand.rank();

        // Check that rank is correctly identified as FULL_HOUSE
        assert(rank == HandRank::FULL_HOUSE, 'Should be a full house');

        // Test with different three of a kind and pair values
        let mut diff_full_house: Array<Card> = array![
            create_card(Suit::HEARTS, Value::ACE),
            create_card(Suit::DIAMONDS, Value::ACE),
            create_card(Suit::CLUBS, Value::ACE),
            create_card(Suit::HEARTS, Value::TWO),
            create_card(Suit::DIAMONDS, Value::TWO),
        ];

        let diff_hand = create_test_hand(diff_full_house);
        assert(diff_hand.rank() == HandRank::FULL_HOUSE, 'Aces full of twos failed');
    }

    // @ShantelPeters
    // Test for Flush
    // Verifies that the rank function correctly identifies a flush
    // and properly handles high card comparisons within a flush
    #[test]
    fn test_flush() {
        // Create a flush in diamonds: A-Q-10-8-6
        let mut cards: Array<Card> = array![
            create_card(Suit::DIAMONDS, Value::ACE),
            create_card(Suit::DIAMONDS, Value::QUEEN),
            create_card(Suit::DIAMONDS, Value::TEN),
            create_card(Suit::DIAMONDS, Value::EIGHT),
            create_card(Suit::DIAMONDS, Value::SIX),
        ];

        let hand = create_test_hand(cards);
        let rank = hand.rank();

        // Check that rank is correctly identified as FLUSH
        assert(rank == HandRank::FLUSH, 'Should be a flush');

        // Test flush in a different suit with different card values
        let mut diff_flush: Array<Card> = array![
            create_card(Suit::CLUBS, Value::KING),
            create_card(Suit::CLUBS, Value::JACK),
            create_card(Suit::CLUBS, Value::NINE),
            create_card(Suit::CLUBS, Value::SEVEN),
            create_card(Suit::CLUBS, Value::THREE),
        ];

        let diff_hand = create_test_hand(diff_flush);
        assert(diff_hand.rank() == HandRank::FLUSH, 'Different flush failed');
    }

    // @ShantelPeters
    // Test for Straight
    // Verifies that the rank function correctly identifies a straight
    // and handles different straight combinations properly
    #[test]
    fn test_straight() {
        // Create a straight: 7-8-9-10-J of mixed suits
        let mut cards: Array<Card> = array![
            create_card(Suit::HEARTS, Value::SEVEN),
            create_card(Suit::DIAMONDS, Value::EIGHT),
            create_card(Suit::CLUBS, Value::NINE),
            create_card(Suit::SPADES, Value::TEN),
            create_card(Suit::HEARTS, Value::JACK),
        ];

        let hand = create_test_hand(cards);
        let rank = hand.rank();

        // Check that rank is correctly identified as STRAIGHT
        assert(rank == HandRank::STRAIGHT, 'Should be a straight');

        // Test the lowest straight (A-2-3-4-5)
        let mut low_straight: Array<Card> = array![
            create_card(Suit::HEARTS, Value::ACE),
            create_card(Suit::DIAMONDS, Value::TWO),
            create_card(Suit::CLUBS, Value::THREE),
            create_card(Suit::SPADES, Value::FOUR),
            create_card(Suit::HEARTS, Value::FIVE),
        ];

        let low_hand = create_test_hand(low_straight);
        assert(low_hand.rank() == HandRank::STRAIGHT, 'Low straight failed');

        // Test the highest straight (10-J-Q-K-A)
        let mut high_straight: Array<Card> = array![
            create_card(Suit::HEARTS, Value::TEN),
            create_card(Suit::DIAMONDS, Value::JACK),
            create_card(Suit::CLUBS, Value::QUEEN),
            create_card(Suit::SPADES, Value::KING),
            create_card(Suit::HEARTS, Value::ACE),
        ];

        let high_hand = create_test_hand(high_straight);
        assert(high_hand.rank() == HandRank::STRAIGHT, 'High straight failed');
    }

    // @ShantelPeters
    // Test for Three of a Kind
    // Verifies that the rank function correctly identifies three of a kind
    // and properly handles kickers
    #[test]
    fn test_three_of_a_kind() {
        // Create three of a kind: three Queens with Ace and 9 kickers
        let mut cards: Array<Card> = array![
            create_card(Suit::HEARTS, Value::QUEEN),
            create_card(Suit::DIAMONDS, Value::QUEEN),
            create_card(Suit::CLUBS, Value::QUEEN),
            create_card(Suit::HEARTS, Value::ACE),
            create_card(Suit::DIAMONDS, Value::NINE),
        ];

        let hand = create_test_hand(cards);
        let rank = hand.rank();

        // Check that rank is correctly identified as THREE_OF_A_KIND
        assert(rank == HandRank::THREE_OF_A_KIND, 'Should be three of a kind');

        // Test with different kickers
        let mut diff_kickers: Array<Card> = array![
            create_card(Suit::HEARTS, Value::QUEEN),
            create_card(Suit::DIAMONDS, Value::QUEEN),
            create_card(Suit::CLUBS, Value::QUEEN),
            create_card(Suit::HEARTS, Value::KING),
            create_card(Suit::DIAMONDS, Value::JACK),
        ];

        let diff_hand = create_test_hand(diff_kickers);
        assert(diff_hand.rank() == HandRank::THREE_OF_A_KIND, 'Three of kind diff kickers');
    }

    // @ShantelPeters
    // Test for Two Pair
    // Verifies that the rank function correctly identifies two pair
    // and properly handles kickers and different pair combinations
    #[test]
    fn test_two_pair() {
        // Create two pair: pair of Tens, pair of Fours, with King kicker
        let mut cards: Array<Card> = array![
            create_card(Suit::HEARTS, Value::TEN),
            create_card(Suit::DIAMONDS, Value::TEN),
            create_card(Suit::CLUBS, Value::FOUR),
            create_card(Suit::SPADES, Value::FOUR),
            create_card(Suit::HEARTS, Value::KING),
        ];

        let hand = create_test_hand(cards);
        let rank = hand.rank();

        // Check that rank is correctly identified as TWO_PAIR
        assert(rank == HandRank::TWO_PAIR, 'Should be two pair');

        // Test with different pairs and kicker
        let mut diff_two_pair: Array<Card> = array![
            create_card(Suit::HEARTS, Value::ACE),
            create_card(Suit::DIAMONDS, Value::ACE),
            create_card(Suit::CLUBS, Value::EIGHT),
            create_card(Suit::SPADES, Value::EIGHT),
            create_card(Suit::HEARTS, Value::TWO),
        ];

        let diff_hand = create_test_hand(diff_two_pair);
        assert(diff_hand.rank() == HandRank::TWO_PAIR, 'Different two pair failed');
    }

    // @ShantelPeters
    // Test for One Pair
    // Verifies that the rank function correctly identifies one pair
    // and properly handles kickers
    #[test]
    fn test_one_pair() {
        // Create one pair: pair of Jacks with Ace, King, 7 kickers
        let mut cards: Array<Card> = array![
            create_card(Suit::HEARTS, Value::JACK),
            create_card(Suit::DIAMONDS, Value::JACK),
            create_card(Suit::CLUBS, Value::ACE),
            create_card(Suit::SPADES, Value::KING),
            create_card(Suit::HEARTS, Value::SEVEN),
        ];

        let hand = create_test_hand(cards);
        let rank = hand.rank();

        // Check that rank is correctly identified as ONE_PAIR
        assert(rank == HandRank::ONE_PAIR, 'Should be one pair');

        // Test with different pair and kickers
        let mut diff_one_pair: Array<Card> = array![
            create_card(Suit::HEARTS, Value::FIVE),
            create_card(Suit::DIAMONDS, Value::FIVE),
            create_card(Suit::CLUBS, Value::QUEEN),
            create_card(Suit::SPADES, Value::NINE),
            create_card(Suit::HEARTS, Value::THREE),
        ];

        let diff_hand = create_test_hand(diff_one_pair);
        assert(diff_hand.rank() == HandRank::ONE_PAIR, 'Different one pair failed');
    }

    // @ShantelPeters
    // Test for High Card
    // Verifies that the rank function correctly identifies a high card hand
    // and properly handles different high card combinations
    #[test]
    fn test_high_card() {
        // Create high card hand: A-K-Q-9-7 of mixed suits
        let mut cards: Array<Card> = array![
            create_card(Suit::HEARTS, Value::ACE),
            create_card(Suit::DIAMONDS, Value::KING),
            create_card(Suit::CLUBS, Value::QUEEN),
            create_card(Suit::SPADES, Value::NINE),
            create_card(Suit::HEARTS, Value::SEVEN),
        ];

        let hand = create_test_hand(cards);
        let rank = hand.rank();

        // Check that rank is correctly identified as HIGH_CARD
        assert(rank == HandRank::HIGH_CARD, 'Should be high card');

        // Test with different high card combinations
        let mut diff_high_card: Array<Card> = array![
            create_card(Suit::HEARTS, Value::KING),
            create_card(Suit::DIAMONDS, Value::JACK),
            create_card(Suit::CLUBS, Value::NINE),
            create_card(Suit::SPADES, Value::SEVEN),
            create_card(Suit::HEARTS, Value::THREE),
        ];

        let diff_hand = create_test_hand(diff_high_card);
        assert(diff_hand.rank() == HandRank::HIGH_CARD, 'Different high card failed');
    }

    // @ShantelPeters
    // Test for Edge Cases
    // Verifies that the rank function handles edge cases properly,
    // such as borderline hands and hands that might be misclassified
    #[test]
    fn test_edge_cases() {
        // Test case: Almost a straight flush, but not quite (9♠, 10♠, J♠, Q♠, K♥)
        let mut almost_straight_flush: Array<Card> = array![
            create_card(Suit::SPADES, Value::NINE),
            create_card(Suit::SPADES, Value::TEN),
            create_card(Suit::SPADES, Value::JACK),
            create_card(Suit::SPADES, Value::QUEEN),
            create_card(Suit::HEARTS, Value::KING) // Different suit breaks straight flush
        ];

        let hand = create_test_hand(almost_straight_flush);
        assert(hand.rank() == HandRank::FLUSH, 'Should be a flush, not straight flush');

        // Test case: Almost a straight, but not quite (2, 3, 4, 5, 7)
        let mut almost_straight: Array<Card> = array![
            create_card(Suit::HEARTS, Value::TWO),
            create_card(Suit::DIAMONDS, Value::THREE),
            create_card(Suit::CLUBS, Value::FOUR),
            create_card(Suit::SPADES, Value::FIVE),
            create_card(Suit::HEARTS, Value::SEVEN) // Gap breaks straight
        ];

        let hand2 = create_test_hand(almost_straight);
        assert(hand2.rank() == HandRank::HIGH_CARD, 'Should be high card, not straight');

        // Test case: Full house vs. four of a kind edge case
        let mut full_house_not_four: Array<Card> = array![
            create_card(Suit::HEARTS, Value::QUEEN),
            create_card(Suit::DIAMONDS, Value::QUEEN),
            create_card(Suit::CLUBS, Value::QUEEN),
            create_card(Suit::HEARTS, Value::JACK),
            create_card(Suit::DIAMONDS, Value::JACK),
        ];

        let hand3 = create_test_hand(full_house_not_four);
        assert(hand3.rank() == HandRank::FULL_HOUSE, 'Should be full house, not four of kind');
    }

    // @ShantelPeters
    // Test for Comparing Similar Hands
    // Verifies that the rank function correctly differentiates between
    // hands of the same category but with different card values
    #[test]
    fn test_hand_comparisons() {
        // Two straight flush hands with different high cards
        let mut sf_king_high: Array<Card> = array![
            create_card(Suit::HEARTS, Value::NINE),
            create_card(Suit::HEARTS, Value::TEN),
            create_card(Suit::HEARTS, Value::JACK),
            create_card(Suit::HEARTS, Value::QUEEN),
            create_card(Suit::HEARTS, Value::KING),
        ];

        let mut sf_ten_high: Array<Card> = array![
            create_card(Suit::DIAMONDS, Value::SIX),
            create_card(Suit::DIAMONDS, Value::SEVEN),
            create_card(Suit::DIAMONDS, Value::EIGHT),
            create_card(Suit::DIAMONDS, Value::NINE),
            create_card(Suit::DIAMONDS, Value::TEN),
        ];

        let hand1 = create_test_hand(sf_king_high);
        let hand2 = create_test_hand(sf_ten_high);

        // Both should be straight flushes
        assert(hand1.rank() == HandRank::STRAIGHT_FLUSH, 'Should be straight flush (King high)');
        assert(hand2.rank() == HandRank::STRAIGHT_FLUSH, 'Should be straight flush (Ten high)');

        // Compare kickers for two hands with the same three of a kind
        let mut trips_ace_king: Array<Card> = array![
            create_card(Suit::HEARTS, Value::FIVE),
            create_card(Suit::DIAMONDS, Value::FIVE),
            create_card(Suit::CLUBS, Value::FIVE),
            create_card(Suit::HEARTS, Value::ACE),
            create_card(Suit::DIAMONDS, Value::KING),
        ];

        let mut trips_ace_queen: Array<Card> = array![
            create_card(Suit::HEARTS, Value::FIVE),
            create_card(Suit::DIAMONDS, Value::FIVE),
            create_card(Suit::CLUBS, Value::FIVE),
            create_card(Suit::HEARTS, Value::ACE),
            create_card(Suit::DIAMONDS, Value::QUEEN),
        ];

        let hand3 = create_test_hand(trips_ace_king);
        let hand4 = create_test_hand(trips_ace_queen);

        // Both should be three of a kind
        assert(
            hand3.rank() == HandRank::THREE_OF_A_KIND, 'Should be three of a kind (A-K kickers)',
        );
        assert(
            hand4.rank() == HandRank::THREE_OF_A_KIND, 'Should be three of a kind (A-Q kickers)',
        );
    }
}
