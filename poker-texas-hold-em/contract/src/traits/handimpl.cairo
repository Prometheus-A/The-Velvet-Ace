use starknet::ContractAddress;
use poker::models::hand::{Hand, HandRank};
use poker::models::card::{Card, DEFAULT_NO_OF_CARDS, Royals, CardTrait};
use poker::models::game::GameParams;
use core::num::traits::{Zero, One};
use core::dict::Felt252DictTrait;
use core::array::ArrayTrait;
use core::option::OptionTrait;
use super::handtrait::HandTrait;

pub impl HandImpl of HandTrait {
    fn default() -> Hand {
        Hand { player: Zero::zero(), cards: array![] }
    }

    fn new_hand(ref self: Hand) {
        self.cards = array![];
    }

    /// @pope-h
    fn rank(self: @Hand, community_cards: Array<Card>) -> (Hand, HandRank) {
        // this function can be called externally in the future.
        // (Self::default(), 0) // Temporary return value

        // Combine player's hand cards with community cards for evaluation
        let mut all_cards: Array<Card> = array![];

        // Add player's hand cards
        let mut i = 0;
        while i < self.cards.len() {
            all_cards.append(*self.cards[i]);
            i += 1;
        };

        // Add community cards
        let mut j = 0;
        while j < community_cards.len() {
            all_cards.append(*community_cards[j]);
            j += 1;
        };

        assert(all_cards.len() == 7, 'Invalid card count');

        // Use Felt252Dict for value and suit counts
        let mut value_counts: Felt252Dict<u8> = Default::default();
        let mut suit_counts: Felt252Dict<u8> = Default::default();

        // Initialize counts
        let mut k: u16 = 1;
        while k <= 14 {
            value_counts.insert(k.into(), 0);
            k += 1;
        };
        let mut s: u8 = 0;
        while s < 4 {
            suit_counts.insert(s.into(), 0);
            s += 1;
        };

        // Fill value and suit counts
        let mut c: usize = 0;
        while c < all_cards.len() {
            let card = *all_cards.at(c);
            let value: u16 = card.value;
            let suit: u8 = card.suit;
            value_counts.insert(value.into(), value_counts.get(value.into()) + 1);
            suit_counts.insert(suit.into(), suit_counts.get(suit.into()) + 1);
            c += 1;
        };

        // Generate all 5-card combinations (C(7,5) = 21)
        let combinations = generate_combinations(all_cards.clone(), 5);

        // Evaluate each combination to find the best hand
        let mut best_rank: u16 = HandRank::UNDEFINED.into();
        let mut best_hand_cards: Array<Card> = array![];
        let mut i: usize = 0;

        while i < combinations.len() {
            let combo = combinations.at(i);
            let (hand_cards, rank) = evaluate_five_cards(combo.clone());
            if rank.into() > best_rank {
                best_rank = rank.into();
                best_hand_cards = hand_cards.clone();
            };
            i += 1;
        };

        let best_hand = Hand { player: *self.player, cards: best_hand_cards };
        (best_hand, best_rank.into())
    }

    /// @Birdmannn
    fn compare_hands(
        hands: Array<Hand>, community_cards: Array<Card>, game_params: GameParams,
    ) -> (Span<Hand>, HandRank, Span<Card>) {
        let mut highest_rank: u16 = 0;
        let mut winning_hands: Array<Hand> = array![];
        let mut winning_new_hands: Array<Hand> = array![];
        let mut kicker_cards: Array<Card> = array![];

        for hand in hands {
            let (new_hand, current_rank): (Hand, HandRank) = hand.rank(community_cards.clone());
            if current_rank.into() > highest_rank {
                highest_rank = current_rank.into();
                winning_hands = array![hand];
                winning_new_hands = array![new_hand];
            } else if current_rank.into() == highest_rank {
                winning_hands.append(hand);
                winning_new_hands.append(new_hand);
            }
        };

        // if winning_hands.len() > 1, then it kicked. Extract kicker
        // add all hands into the array if game_params.kicker_split is true.
        // else add only the kicking hand.
        if winning_hands.len() > 1 {
            let mut hands: Array<Hand> = array![];
            let (kicker_hands, _cards): (Array<Hand>, Array<Card>) = extract_kicker(
                winning_new_hands, highest_rank,
            );

            if game_params.kicker_split {
                // the player address of each hand should be valid
                for hand in kicker_hands {
                    // the hand.player should be valid
                    assert(hand.player != Zero::zero(), 'EXTRACTION ERROR');
                    for i in 0..winning_hands.len() {
                        let w = winning_hands.at(i);
                        if hand.player == *w.player {
                            let wh = Hand { player: hand.player, cards: w.cards.clone() };
                            hands.append(wh);
                            break;
                        }
                    }
                };
                kicker_cards = _cards;
            }

            winning_hands = hands;
        }

        (winning_hands.span(), highest_rank.into(), kicker_cards.span())
    }

    fn remove_card(ref self: Hand, pos: usize) -> Card {
        // ensure card is removed.
        // though I haven't seen a need for this function.
        assert(self.cards.len() > 0, 'HAND IS EMPTY');
        assert(pos < self.cards.len(), 'POSITION OUT OF BOUNDS');
        // TODO: find a way to remove the card from that position
        // Use CardTrait or something
        Card { suit: 0, value: 0 }
    }

    fn reveal(self: @Hand) -> Span<Card> {
        // TODO lol
        array![].span()
    }

    fn add_card(ref self: Hand, card: Card) { // ensure card is added.
        self.cards.append(card);
    }

    fn to_bytearray(self: @Hand) -> ByteArray {
        let mut count = 1;
        let mut str: ByteArray = format!("Owner: {:?}\n", self.player);

        for i in 0..self.cards.len() {
            let card = self.cards[i];
            let word: ByteArray = format!("{}. {}\n", count, card.to_byte_array());
            str.append(@word);
            count += 1;
        };

        str
    }
}

/// Take in a HandRank::<const>, a u16 value
/// Takes in an array of hands of equal HandRank
/// To increase optimization, the ranks of each hand are never checked here,
/// but are assumed to be equal
///
/// returns a tuple of an array of the winning hands, and an array of the cards that did the kicking
/// The card in the winning hands are always equal
/// The hand returned here is usually one...unless all hands taken in as the parameter were exactly
/// equal.
fn extract_kicker(hands: Array<Hand>, hand_rank: u16) -> (Array<Hand>, Array<Card>) {
    // Implement kicker based on hand_rank
    // some hand_ranks have a different kicker implementation from the rest
    (array![], array![])
}

// for the test
// assert that the array of kicking cards are present in the winning hands
// .. or make
/// Generates all k-card combinations from a given array of cards
///
/// This function creates all possible combinations of `k` cards from the input array
/// using a bitwise subset generation approach.
///
/// # Arguments
/// * `cards` - An array of cards to generate combinations from
/// * `k` - The number of cards in each combination
///
/// # Returns
/// An array of arrays, where each inner array is a combination of `k` cards
///
/// # Author
/// [@pope-h]
fn generate_combinations(cards: Array<Card>, k: usize) -> Array<Array<Card>> {
    let n = cards.len();
    let mut result: Array<Array<Card>> = array![];
    let total: u32 = pow(2, n.try_into().unwrap()); // 2^n subsets
    let mut i: u32 = 0;

    while i < total {
        let mut subset: Array<Card> = array![];
        let mut j: usize = 0;
        while j < n {
            if i & pow(2, j.try_into().unwrap()) != 0 {
                subset.append(*cards.at(j));
            }
            // if bit_and(i, pow(2, j.try_into().unwrap())) != 0 {

            // };
            j += 1;
        };
        if subset.len() == k {
            result.append(subset);
        };
        i += 1;
    };
    result
}

/// Performs bitwise AND operation simulation
///
/// This function simulates a bitwise AND operation for 32-bit unsigned integers
/// by manually checking and combining bits.
///
/// # Arguments
/// * `a` - First 32-bit unsigned integer
/// * `b` - Second 32-bit unsigned integer
///
/// # Returns
/// Result of the bitwise AND operation
///
/// # Author
/// [@pope-h]
fn bit_and(a: u32, b: u32) -> u32 {
    let mut result = 0_u32;
    let mut position = 0_u32;
    let mut a_copy = a;
    let mut b_copy = b;

    while position < 32 {
        let bit_a = a_copy % 2;
        let bit_b = b_copy % 2;
        if bit_a == 1 && bit_b == 1 {
            result += pow(2, position);
        };
        a_copy /= 2;
        b_copy /= 2;
        position += 1;
    };
    result
}

/// Calculates the power of a number
///
/// Computes `base` raised to the power of `exp` using iterative multiplication.
///
/// # Arguments
/// * `base` - Base number
/// * `exp` - Exponent
///
/// # Returns
/// Result of base raised to the power of exp
///
/// # Author
/// [@pope-h]
fn pow(base: u32, exp: u32) -> u32 {
    let mut result = 1_u32;
    let mut i = 0_u32;
    while i < exp {
        result *= base;
        i += 1;
    };
    result
}

/// Evaluates a 5-card hand and determines its poker rank
///
/// Analyzes a 5-card hand to determine its poker rank, checking for various
/// hand combinations like flush, straight, pairs, etc.
///
/// # Arguments
/// * `cards` - An array of 5 cards to evaluate
///
/// # Returns
/// A tuple containing:
/// 1. The original cards
/// 2. The hand's rank as a u16 (using HandRank constants)
///
/// # Panics
/// Panics if the number of cards is not exactly 5
///
/// # Author
/// [@pope-h]
fn evaluate_five_cards(cards: Array<Card>) -> (Array<Card>, HandRank) {
    assert(cards.len() == 5, 'Must have 5 cards');

    // Convert to array of (value, poker_value, suit) for Ace handling
    let mut card_data: Array<(u16, u16, u8)> = array![];
    let mut i: usize = 0;
    while i < cards.len() {
        let card = *cards.at(i);
        let poker_value = if card.value == Royals::ACE {
            14_u16
        } else {
            card.value
        };
        card_data.append((card.value, poker_value, card.suit));
        i += 1;
    };

    // Sort by poker_value descending
    let mut sorted: Array<(u16, u16, u8)> = bubble_sort(card_data.clone());

    // Extract all tuple elements for each card
    let (orig_val0, poker_val0, suit0) = *sorted.at(0);
    let (orig_val1, poker_val1, suit1) = *sorted.at(1);
    let (orig_val2, poker_val2, suit2) = *sorted.at(2);
    let (orig_val3, poker_val3, suit3) = *sorted.at(3);
    let (orig_val4, poker_val4, suit4) = *sorted.at(4);

    // Check for flush using suits (already fixed)
    let is_flush = suit0 == suit1 && suit1 == suit2 && suit2 == suit3 && suit3 == suit4;

    // Check for high straight using poker_values
    let is_straight_high = poker_val0 == poker_val1
        + 1 && poker_val1 == poker_val2
        + 1 && poker_val2 == poker_val3
        + 1 && poker_val3 == poker_val4
        + 1;

    // Check for Ace-low straight using original_values
    let is_straight_low = orig_val0 == Royals::ACE
        && orig_val1 == 5
        && orig_val2 == 4
        && orig_val3 == 3
        && orig_val4 == 2;
    let is_straight = is_straight_high || is_straight_low;

    // Count values for pairs, three of a kind, etc., using original_values
    let mut value_counts: Felt252Dict<u8> = Default::default();
    let values = array![orig_val0, orig_val1, orig_val2, orig_val3, orig_val4];
    i = 0;
    while i < values.len() {
        let val = *values.at(i);
        value_counts.insert(val.into(), value_counts.get(val.into()) + 1);
        i += 1;
    };

    let mut counts: Array<u8> = array![];
    let mut k: u16 = 1;
    while k <= 14 {
        let count = value_counts.get(k.into());
        if count > 0 {
            counts.append(count);
        };
        k += 1;
    };
    let sorted_counts: Array<u8> = bubble_sort_u8(counts.clone());

    // Evaluate hand rank
    if is_flush && is_straight {
        if poker_val0 == 14 {
            return (cards.clone(), HandRank::ROYAL_FLUSH);
        }
        return (cards.clone(), HandRank::STRAIGHT_FLUSH);
    }
    if sorted_counts.len() > 0 && *sorted_counts.at(0) == 4 {
        return (cards.clone(), HandRank::FOUR_OF_A_KIND);
    }
    if sorted_counts.len() > 1 && *sorted_counts.at(0) == 3 && *sorted_counts.at(1) == 2 {
        return (cards.clone(), HandRank::FULL_HOUSE);
    }
    if is_flush {
        return (cards.clone(), HandRank::FLUSH);
    }
    if is_straight {
        return (cards.clone(), HandRank::STRAIGHT);
    }
    if sorted_counts.len() > 0 && *sorted_counts.at(0) == 3 {
        return (cards.clone(), HandRank::THREE_OF_A_KIND);
    }
    if sorted_counts.len() > 1 && *sorted_counts.at(0) == 2 && *sorted_counts.at(1) == 2 {
        return (cards.clone(), HandRank::TWO_PAIR);
    }
    if sorted_counts.len() > 0 && *sorted_counts.at(0) == 2 {
        return (cards.clone(), HandRank::ONE_PAIR);
    }
    (cards.clone(), HandRank::HIGH_CARD)
}

/// Performs bubble sort on an array of card tuples
///
/// Sorts card tuples in descending order based on their poker value.
///
/// # Arguments
/// * `arr` - An array of card tuples (original value, poker value, suit)
///
/// # Returns
/// A sorted array of card tuples
///
/// # Author
/// [@pope-h]
fn bubble_sort(mut arr: Array<(u16, u16, u8)>) -> Array<(u16, u16, u8)> {
    let mut swapped = true;
    while swapped {
        swapped = false;
        let mut i: usize = 0;
        while i < arr.len() - 1 {
            // Destructure the tuples to access poker_value
            let (orig_val_curr, poker_val_curr, suit_curr) = *arr.at(i);
            let (orig_val_next, poker_val_next, suit_next) = *arr.at(i + 1);

            // Compare poker_values for descending order
            if poker_val_curr < poker_val_next {
                // Swap elements if current poker_value is less than next
                arr = set_array_element(arr.clone(), i, (orig_val_next, poker_val_next, suit_next));
                arr = set_array_element(arr, i + 1, (orig_val_curr, poker_val_curr, suit_curr));
                swapped = true;
            };
            i += 1;
        };
    };
    arr
}

/// Performs bubble sort on an array of u8 values
///
/// Sorts u8 values in descending order.
///
/// # Arguments
/// * `arr` - An array of u8 values
///
/// # Returns
/// A sorted array of u8 values
///
/// # Author
/// [@pope-h]
fn bubble_sort_u8(mut arr: Array<u8>) -> Array<u8> {
    let mut swapped = true;
    while swapped {
        swapped = false;
        let mut i: usize = 0;
        while i < arr.len() - 1 {
            let current = *arr.at(i);
            let next = *arr.at(i + 1);
            if current < next {
                arr = set_array_element(arr.clone(), i, next);
                arr = set_array_element(arr, i + 1, current);
                swapped = true;
            };
            i += 1;
        };
    };
    arr
}

/// Immutably sets an element in an array
///
/// Creates a new array with a specific element replaced at the given index.
///
/// # Arguments
/// * `arr` - The original array
/// * `index` - The index of the element to replace
/// * `value` - The new value to set at the specified index
///
/// # Returns
/// A new array with the specified element replaced
///
/// # Author
/// [@pope-h]
fn set_array_element<T, +Copy<T>, +Drop<T>>(mut arr: Array<T>, index: usize, value: T) -> Array<T> {
    let mut new_arr: Array<T> = array![];
    let mut i: usize = 0;
    while i < arr.len() {
        if i == index {
            new_arr.append(value);
        } else {
            new_arr.append(*arr.at(i));
        };
        i += 1;
    };
    new_arr
}
