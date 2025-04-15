use crate::models::hand::{Hand, HandRank};
use crate::models::card::{Card, Royals};

/// @Birdmannn
fn extract_kicker(hands: Array<Hand>, hand_rank: u16) -> (Array<Hand>, Array<Card>) {
    // Implement kicker based on hand_rank
    // some hand_ranks have a different kicker implementation from the rest
    (array![], array![])
}

/// @pope-h
fn generate_combinations(cards: Array<Card>, k: usize) -> Array<Array<Card>> {
    let n = cards.len();
    let mut result: Array<Array<Card>> = array![];
    let total: u32 = pow(2, n.try_into().unwrap()); // 2^n subsets

    for i in 0..total {
        let mut subset: Array<Card> = array![];
        for j in 0..n {
            if i & pow(2, j.try_into().unwrap()) != 0 {
                subset.append(*cards.at(j));
            }
        };
        if subset.len() == k {
            result.append(subset);
        };
    };
    result
}

/// @pope-h, @Birdmannn
fn evaluate_cards(cards: Array<Card>) -> (Array<Card>, HandRank) {
    // Convert to array of (value, poker_value, suit) for Ace handling
    let mut card_data: Array<(u16, u16, u8)> = array![];
    for i in 0..cards.len() {
        let card = *cards.at(i);
        let poker_value = if card.value == Royals::ACE {
            14_u16
        } else {
            card.value
        };
        card_data.append((card.value, poker_value, card.suit));
    };

    // Sort by poker_value descending
    let mut sorted: Array<(u16, u16, u8)> = bubble_sort(card_data.clone());
    let (is_flush, is_straight): (bool, bool) = ashura(sorted.clone());

    // Count values for pairs, three of a kind, etc., using original_values
    let mut value_counts: Felt252Dict<u8> = Default::default();
    let mut values = array![];
    for i in 0..sorted.len() {
        let (val, _, _) = *sorted[i];
        values.append(val);
    };

    for i in 0..values.len() {
        let val = *values.at(i);
        value_counts.insert(val.into(), value_counts.get(val.into()) + 1);
    };

    let mut counts: Array<u8> = array![];
    for i in 1..14_u32 {
        let count = value_counts.get(i.into());
        if count > 0 {
            counts.append(count);
        };
    };
    let sorted_counts: Array<u8> = bubble_sort_u8(counts.clone());

    // Evaluate hand rank
    if is_flush && is_straight {
        let (_, poker_val0, _) = *sorted[0];
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

/// @pope-h
fn bubble_sort(mut arr: Array<(u16, u16, u8)>) -> Array<(u16, u16, u8)> {
    let mut swapped = true;
    while swapped {
        swapped = false;
        for i in 0..arr.len() - 1 {
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
        };
    };
    arr
}

/// @pope-h
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

/// @pope-h
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

/// @Birdmannn
fn min_u32(val1: u32, val2: u32) -> u32 {
    if val1 < val2 {
        return val1;
    }
    return val2;
}

/// Checks for flush and straight, if available.
/// @Birdmannn
fn ashura(arr: Array<(u16, u16, u8)>) -> (bool, bool) {
    let (mut is_flush, mut is_straight_high, mut is_straight_low): (bool, bool, bool) =
        Default::default();

    // Proceed if combo contains the max required poker hand size
    if arr.len() == 5 {
        is_flush = true;
        is_straight_high = true;
        let mut n = 5;
        let (val_ref, mut pval_ref, suit_ref) = *arr[0];
        is_straight_low = val_ref == Royals::ACE;
        for i in 1..arr.len() {
            let (val, pval, suit) = *arr[i];
            if is_straight_low {
                if val != n {
                    is_straight_low = false;
                }
                n -= 1;
            }
            if is_flush && suit != suit_ref {
                is_flush = false;
            }
            if is_straight_high && pval_ref != (pval + 1) {
                is_straight_high = false;
            }
            if is_straight_high {
                pval_ref = pval;
            }
            if !is_flush && !is_straight_low && !is_straight_high {
                break;
            }
        };
    }

    (is_flush, is_straight_high || is_straight_low)
}

/// FOR KICKER, SORT ALL CARDS AND COMPARE THEIR FIRST VALUES (POKER_VAL)
/// THE REST SHOULD BE HISTORY. :)
///
///
///
///
/// **************************************************************************
/// DOCS

/// fn extract_kicker(hands: Array<Hand>, hand_rank: u16) -> (Array<Hand>, Array<Card>)
/// @Birdmannn
/// Take in a HandRank::<const>, a u16 value
/// Takes in an array of hands of equal HandRank
/// To increase optimization, the ranks of each hand are never checked here,
/// but are assumed to be equal
///
/// returns a tuple of an array of the winning hands, and an array of the cards that did the kicking
/// The card in the winning hands are always equal
/// The hand returned here is usually one...unless all hands taken in as the parameter were exactly
/// equal.

/// fn generate_combinations(cards: Array<Card>, k: usize) -> Array<Array<Card>>
/// @pope-h
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

/// fn evaluate_cards(cards: Array<Card>) -> (Array<Card>, HandRank)
/// @pope-h, @Birdmannn
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

/// fn bubble_sort(mut arr: Array<(u16, u16, u8)>) -> Array<(u16, u16, u8)>
/// @pope-h
/// Performs bubble sort on an array of card tuples
///
/// Sorts card tuples in descending order based on their poker value.
///
/// # Arguments
/// * `arr` - An array of card tuples (original value, poker value, suit)
///
/// # Returns
/// A sorted array of card tuples

/// fn bubble_sort_u8(mut arr: Array<u8>) -> Array<u8>
/// @pope-h
/// Performs bubble sort on an array of u8 values
///
/// Sorts u8 values in descending order.
///
/// # Arguments
/// * `arr` - An array of u8 values
///
/// # Returns
/// A sorted array of u8 values

/// fn set_array_element<T, +Copy<T>, +Drop<T>>(mut arr: Array<T>, index: usize, value: T) ->
/// Array<T>
/// @pope-h
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
