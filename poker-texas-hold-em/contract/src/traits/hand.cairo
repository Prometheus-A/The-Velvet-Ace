use starknet::ContractAddress;
use poker::models::hand::{Hand, HandRank};
use poker::models::card::{Card, DEFAULT_NO_OF_CARDS, Royals};
use poker::models::game::GameParams;
use core::num::traits::{Zero, One};
use core::dict::Felt252DictTrait;
use core::array::ArrayTrait;
use core::option::OptionTrait;

pub trait HandTrait {
    fn default() -> Hand;
    fn new_hand(ref self: Hand);
    fn rank(self: @Hand, community_cards: Array<Card>) -> (Hand, u16);
    fn compare_hands(
        hands: Array<Hand>, community_cards: Array<Card>, game_params: GameParams,
    ) -> Span<Hand>;
    fn remove_card(ref self: Hand, pos: usize) -> Card;
    fn reveal(self: @Hand) -> Span<Card>;
    fn add_card(ref self: Hand, card: Card);
    // TODO, add function that shows cards in bytearray, array of tuple (suit, and value)
// add to card trait.
}

pub impl HandImpl of HandTrait {
    /// Evaluates the rank of a player's hand by combining their cards with community cards
    ///
    /// This function determines the highest-ranking 5-card hand possible using the player's
    /// cards and the community cards. It generates all possible 5-card combinations and 
    /// evaluates each to find the best hand and its corresponding rank.
    ///
    /// # Arguments
    /// * `self` - A reference to the current Hand
    /// * `community_cards` - An array of community cards to combine with the player's hand
    ///
    /// # Returns
    /// A tuple containing:
    /// 1. A new Hand with the best 5 cards found
    /// 2. The rank of the hand as a u16 (using HandRank constants)
    ///
    /// # Panics
    /// Panics if the total number of cards is not exactly 7
    ///
    /// # Author
    /// [@pope-h]
    fn rank(self: @Hand, community_cards: Array<Card>) -> (Hand, u16) {
        // use HandRank to get the rank for a hand of one player
        // return using the HandRank::<the const>, and not the raw u16 value
        // compute the hand that makes up this rank you have computed
        // set the player value (a CA) to the player's CA with the particular hand
        // return both values in a tuple
        // document the function.

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
        let mut best_rank: u16 = HandRank::HIGH_CARD;
        let mut best_hand_cards: Array<Card> = array![];
        let mut i: usize = 0;

        while i < combinations.len() {
            let combo = combinations.at(i);
            let (hand_cards, rank) = evaluate_five_cards(combo.clone());
            if rank > best_rank {
                best_rank = rank;
                best_hand_cards = hand_cards.clone();
            };
            i += 1;
        };

        let best_hand = Hand { player: *self.player, cards: best_hand_cards };
        (best_hand, best_rank)
    }

    /// This function will compare the hands of all the players and return an array of Player
    /// contains the player with the winning hand
    /// this is only possible if the `kick_split` in game_params is true
    fn compare_hands(
        hands: Array<Hand>, community_cards: Array<Card>, game_params: GameParams,
    ) -> Span<Hand> {
        // for hand comparisons, there should be a kicker
        // kicker there-in that there are times two or more players have the same hand rank, so we
        // check the value of each card in hand.

        // TODO: Ace might be changed to a higher value.
        let mut highest_rank: u16 = 0;
        let mut current_winning_hand: Hand = Self::default();
        // let mut winning_players: Array<Option<Player>> = array![];
        let mut winning_hands: Array<Hand> = array![];
        for hand in hands {
            let (new_hand, current_rank) = hand.rank(community_cards.clone());
            if current_rank > highest_rank {
                highest_rank = current_rank;
                current_winning_hand = hand;
                // append details into `winning_hands` -- extracted using a bool variables
                // `hands_changed`
                // the hands has been changed, set to true
                hands_changed(ref winning_hands);
                // update the necessary arrays here.

            } else if current_rank == highest_rank {
                // implement kicker. Only works for the current_winner variable
                // retrieve the former current_winner already stored and the current player,
                // and compare both hands. This should be done in another internal function and be
                // called here.
                // The function should take in both `hand` and `current_winning_hand`, should return
                // the winning hand Implementation would be left to you
                // compare the player's CA in the returned hand to the current `winning_hand`
                // If not equal, update both `current_winner` and `winning_hand`

                // TODO: Check for a straight. The kicker is different for a straight. The person
                // with the highest straight wins (compare only the last straight.) The function
                // called here might take in a `hand_rank` u16 variable to check for this.

                // in rare case scenarios, a pot can be split based on the game params
                // here, an array shall be used. check kicker_split, if true, add two same hands in
                // the array Add the kicker hand first into the array, before the other...that's if
                // `game_params.kicker_split`
                // is true, if not, add only the kicker hand to the Array. For more than two
                // kickers, arrange the array accordingly. might be implemented by someone else.
                // here, hands have been changed, right?
                hands_changed(ref winning_hands);
                // do the necessary updates.
            }
        };

        winning_hands.span()
    }

    fn new_hand(ref self: Hand) {
        self.cards = array![];
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

    fn default() -> Hand {
        Hand { player: Zero::zero(), cards: array![] }
    }
}

/// Private Helper Functions
/// // To be audited
fn hands_changed(ref winning_hands: Array<Hand>) {
    for _ in 0..winning_hands.len() {
        // discard all existing objects in `winning_hands`. A clean slate.
        winning_hands.pop_front().unwrap();
    };
}

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
    let total = pow(2, n.try_into().unwrap()); // 2^n subsets
    let mut i: u32 = 0;

    while i < total {
        let mut subset: Array<Card> = array![];
        let mut j: usize = 0;
        while j < n {
            if bit_and(i, pow(2, j.try_into().unwrap())) != 0 {
                subset.append(*cards.at(j));
            };
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

// Helper: Power function
fn pow(base: u32, exp: u32) -> u32 {
    let mut result = 1_u32;
    let mut i = 0_u32;
    while i < exp {
        result *= base;
        i += 1;
    };
    result
}

// Evaluate a 5-card hand and return (cards, rank)
fn evaluate_five_cards(cards: Array<Card>) -> (Array<Card>, u16) {
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
    let mut sorted = bubble_sort(card_data.clone());

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
    let sorted_counts = bubble_sort_u8(counts.clone());

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

// Helper: Bubble sort for (value, poker_value, suit) tuples
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

// Helper: Bubble sort for u8 array
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

// Helper: Set element in array (immutable workaround)
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
