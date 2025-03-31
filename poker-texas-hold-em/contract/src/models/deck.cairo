use super::card::Card;
use poker::traits::deck::DeckTrait;
#[derive(Serde, Drop, Clone, Default, PartialEq)]
#[dojo::model]
pub struct Deck {
    #[key]
    id: u64,
    cards: Array<Card>,
}

#[cfg(test)]
mod tests {
    use super::{Deck, Card};
    use poker::traits::deck::DeckTrait;

    // @augustin-v
    // Helper function to count unique cards in a deck
    // Returns the number of distinct cards based on their suit and value
    fn count_unique_cards(deck: @Deck) -> u32 {
        let mut count: u32 = 0;
        let mut seen: Felt252Dict<bool> = Default::default();

        let cards: @Array<Card> = deck.cards;
        let cards_len: u32 = cards.len();

        let mut i: u32 = 0;
        while i < cards_len {
            let card = *cards.at(i);
            // Create a unique key for each card (suit * 100 + value)
            let key: felt252 = (card.suit.into() * 100 + card.value.into()).into();

            if !seen.get(key) {
                seen.insert(key, true);
                count += 1;
            }

            i += 1;
        };

        count
    }

    // @augustin-v
    // Helper function to check if two decks have different card ordering
    // Returns true if the card orders differ, false if identical
    fn is_shuffled(deck1: @Deck, deck2: @Deck) -> bool {
        if deck1.cards.len() != deck2.cards.len() {
            return false;
        }

        // Check if at least one card is in a different position
        let mut found_difference: bool = false;
        let cards_len: u32 = deck1.cards.len();

        let mut i: u32 = 0;
        while i < cards_len {
            if *deck1.cards.at(i) != *deck2.cards.at(i) {
                found_difference = true;
                break;
            }
            i += 1;
        };

        found_difference
    }

    // @augustin-v
    // Test the new_deck function
    // Verifies:
    // 1. A new deck has exactly 52 cards
    // 2. All cards in the deck are unique
    // 3. The distribution of suits and values is correct
    #[test]
    fn test_new_deck() {
        let mut deck: Deck = Deck { id: 1, cards: array![] };
        deck.new_deck();

        // Test 1: Verify the deck has exactly 52 cards
        assert(deck.cards.len() == 52, 'Deck should have 52 cards');

        // Test 2: Verify all cards are unique
        let unique_count: u32 = count_unique_cards(@deck);
        assert(unique_count == 52, 'All cards should be unique');

        // Test 3: Verify distribution of suits and values
        let mut suit_counts: Felt252Dict<u32> = Default::default();
        let mut value_counts: Felt252Dict<u32> = Default::default();

        let mut i: u32 = 0;
        while i < deck.cards.len() {
            let card: Card = *deck.cards.at(i);
            let suit_key: felt252 = card.suit.into();
            let value_key: felt252 = (card.value - 1).into();

            suit_counts.insert(suit_key, suit_counts.get(suit_key) + 1);
            value_counts.insert(value_key, value_counts.get(value_key) + 1);
            i += 1;
        };

        // Check each suit has 13 cards
        i = 0;
        while i < 4 {
            let suit_key: felt252 = i.into();
            assert(suit_counts.get(suit_key) == 13, 'Each suit should have 13 cards');
            i += 1;
        };

        // Check each value appears 4 times (once for each suit)
        i = 0;
        while i < 13 {
            let value_key: felt252 = i.into();
            assert(value_counts.get(value_key) == 4, 'value should appear 4 times');
            i += 1;
        };
    }


    // @augustin-v
    // Test the shuffle function
    // Verifies:
    // 1. After shuffling, the deck still has 52 cards
    // 2. All cards remain unique after shuffling
    // 3. The order of cards has changed (deck is actually shuffled)
    // TODO: Fix the DeckTrait [`shuffle()`] function to make the test pass
    #[test]
    // #[ignore]
    fn test_shuffle() {
        let mut deck: Deck = Deck { id: 1, cards: array![] };
        deck.new_deck();

        let initial_deck: Deck = deck.clone();
        println!("deck len no shuffle: {}", deck.cards.len());
        deck.shuffle();
        println!("deck len after shuffle: {}", deck.cards.len());

        // Test 1: Verify the deck still has 52 cards
        assert(deck.cards.len() == 52, 'Deck should have 52 cards');

        // Test 2: Verify all cards are still unique
        let unique_count: u32 = count_unique_cards(@deck);
        println!("unique count: {}", unique_count);
        assert(unique_count == 52, 'All cards should be unique');

        // Test 3: Verify the order has changed
        // Note: There's a small probability this could fail even with a correct
        // shuffle implementation if the shuffled order happens to match the original
        assert(is_shuffled(@initial_deck, @deck), 'Deck should be shuffled');
    }

    // @augustin-v
    // Test the deal_card function
    // Verifies:
    // 1. Dealing a card reduces the deck size by one
    // 2. Multiple cards can be dealt correctly
    // 3. All cards can be dealt until the deck is empty
    #[test]
    fn test_deal_card() {
        let mut deck = Deck { id: 1, cards: array![] };
        deck.new_deck();

        // Test 1: Deal one card and verify deck size reduces
        let initial_size: u32 = deck.cards.len();
        deck.deal_card();
        assert(deck.cards.len() == initial_size - 1, 'Deck size should reduce by 1');

        // Test 2: Deal multiple cards and verify deck size
        let num_to_deal: u32 = 10;
        let mut i: u32 = 0;
        while i < num_to_deal {
            let _ = deck.deal_card();
            i += 1;
        };
        assert(deck.cards.len() == initial_size - num_to_deal - 1, 'Deck size should reduce');

        // Test 3: Verify we can deal all remaining cards
        let remaining: u32 = deck.cards.len();
        i = 0;
        while i < remaining {
            let _ = deck.deal_card();
            i += 1;
        };
        assert(deck.cards.len() == 0, 'Deck should be empty');
    }

    // @augustin-v
    // Test edge cases for new_deck function
    #[test]
    fn test_new_deck_edge_cases() {
        // Test with different ID values
        let mut deck1: Deck = Deck { id: 1, cards: array![] };
        let mut deck2: Deck = Deck { id: 42, cards: array![] };

        deck1.new_deck();
        deck2.new_deck();

        assert(deck1.id == 1, 'ID should be preserved');
        assert(deck2.id == 42, 'ID should be preserved');

        // Verify idempotence, calling new_deck twice should give same result
        let first_deck: Deck = deck1.clone();
        deck1.new_deck();
        assert(!is_shuffled(@first_deck, @deck1), 'deck should be in same order');

        assert(!is_shuffled(@deck1, @deck2), 'decks should have same order');
    }

    // @augustin-v
    // Test independence of multiple deck instances
    #[test]
    fn test_multiple_decks() {
        let mut deck1: Deck = Deck { id: 1, cards: array![] };
        let mut deck2: Deck = Deck { id: 2, cards: array![] };

        deck1.new_deck();
        deck2.new_deck();

        // Deal from deck1 and verify deck2 is unchanged
        let initial_deck2_count: u32 = deck2.cards.len();
        let _ = deck1.deal_card();

        assert(deck2.cards.len() == initial_deck2_count, 'Second deck should be unchanged');

        // Verify changing one deck doesn't affect the other
        let initial_deck1_count: u32 = deck1.cards.len();
        let _ = deck2.deal_card();

        assert(deck1.cards.len() == initial_deck1_count, 'First deck should be unchanged');
    }
}
