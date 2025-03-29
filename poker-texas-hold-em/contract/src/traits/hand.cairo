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
        let mut highest_rank: u16 = 0;
        let mut current_winning_hand: Hand = Self::default();
        let mut winning_hands: Array<Hand> = array![];

        for hand in hands {
            let (new_hand, current_rank) = hand.rank(community_cards.clone());
            if current_rank > highest_rank {
                highest_rank = current_rank;
                current_winning_hand = hand;
                winning_hands = array![hand];
            } else if current_rank == highest_rank {
                // Use extract_kicker to compare hands of same rank
                let (winners, _) = extract_kicker(array![current_winning_hand, hand], highest_rank);
                if winners.len() > 1 && game_params.kicker_split {
                    winning_hands.append(hand);
                } else if winners.len() == 1 && winners[0].player == hand.player {
                    winning_hands = array![hand];
                    current_winning_hand = hand;
                }
            }
        };

        winning_hands.span()
    }

    fn new_hand(ref self: Hand) {
        self.cards = array![];
    }

    fn remove_card(ref self: Hand, pos: usize) -> Card {
        assert(self.cards.len() > 0, 'HAND IS EMPTY');
        assert(pos < self.cards.len(), 'POSITION OUT OF BOUNDS');
        Card { suit: 0, value: 0 }
    }

    fn reveal(self: @Hand) -> Span<Card> {
        array![].span()
    }

    fn add_card(ref self: Hand, card: Card) {
        self.cards.append(card);
    }

    fn default() -> Hand {
        Hand { player: Zero::zero(), cards: array![] }
    }
}

/// @pope-h, @gelluisaac
/// Compares hands of the same rank and returns the winning hand(s) with their kicker cards
/// 
/// # Arguments
/// * `hands` - Array of Hand structs to compare (must all be of same rank)
/// * `hand_rank` - The HandRank value indicating what type of hands we're comparing
///
/// # Returns
/// A tuple containing:
/// 1. Array of winning hands (can be multiple in case of ties)
/// 2. Array of corresponding kicker cards for each winning hand
fn extract_kicker(hands: Array<Hand>, hand_rank: u16) -> (Array<Hand>, Array<Card>) {
    if hands.is_empty() {
        return (array![], array![]);
    }

    match hand_rank {
        HandRank::HIGH_CARD => compare_high_card_hands(hands),
        HandRank::ONE_PAIR => compare_one_pair_hands(hands),
        HandRank::TWO_PAIR => compare_two_pair_hands(hands),
        HandRank::THREE_OF_A_KIND => compare_three_of_a_kind_hands(hands),
        HandRank::STRAIGHT => compare_straight_hands(hands),
        HandRank::FLUSH => compare_flush_hands(hands),
        HandRank::FULL_HOUSE => compare_full_house_hands(hands),
        HandRank::FOUR_OF_A_KIND => compare_four_of_a_kind_hands(hands),
        HandRank::STRAIGHT_FLUSH => compare_straight_flush_hands(hands),
        HandRank::ROYAL_FLUSH => (hands, array![]), // All royal flushes are equal
        _ => (array![], array![]),
    }
}

/// @gelluisaac
/// Helper function to compare high card hands
fn compare_high_card_hands(hands: Array<Hand>) -> (Array<Hand>, Array<Card>) {
    let mut winning_hands = array![];
    let mut highest_cards = array![];
    let mut current_highest = 0;

    for hand in hands {
        let sorted = sort_cards_by_value_desc(hand.cards);
        let high_card = *sorted.at(0);
        
        if high_card.value > current_highest {
            current_highest = high_card.value;
            winning_hands = array![hand];
            highest_cards = array![high_card];
        } else if high_card.value == current_highest {
            match compare_kickers(sorted, highest_cards) {
                Ordering::Greater => {
                    winning_hands = array![hand];
                    highest_cards = array![high_card];
                },
                Ordering::Equal => {
                    winning_hands.append(hand);
                    highest_cards.append(high_card);
                },
                _ => (),
            };
        }
    }

    (winning_hands, highest_cards)
}

/// @gelluisaac
/// Helper function to compare one pair hands
fn compare_one_pair_hands(hands: Array<Hand>) -> (Array<Hand>, Array<Card>) {
    let mut winning_hands = array![];
    let mut highest_pair_value = 0;
    let mut best_kickers = array![];

    for hand in hands {
        let (pair_value, kickers) = get_pair_and_kickers(hand.cards);
        
        if pair_value > highest_pair_value {
            highest_pair_value = pair_value;
            winning_hands = array![hand];
            best_kickers = kickers;
        } else if pair_value == highest_pair_value {
            match compare_kickers(kickers, best_kickers) {
                Ordering::Greater => {
                    winning_hands = array![hand];
                    best_kickers = kickers;
                },
                Ordering::Equal => {
                    winning_hands.append(hand);
                },
                _ => (),
            };
        }
    }

    (winning_hands, best_kickers)
}

/// @gelluisaac
/// Enum to represent comparison results
enum Ordering {
    Greater,
    Equal,
    Less,
}

/// @gelluisaac
/// Helper function to compare kicker cards between hands
fn compare_kickers(kickers1: Array<Card>, kickers2: Array<Card>) -> Ordering {
    let mut i = 0;
    while i < kickers1.len() && i < kickers2.len() {
        let card1 = *kickers1.at(i);
        let card2 = *kickers2.at(i);
        
        if card1.value > card2.value {
            return Ordering::Greater;
        } else if card1.value < card2.value {
            return Ordering::Less;
        }
        i += 1;
    }
    
    Ordering::Equal
}

/// @gelluisaac
/// Helper function to get pair value and kickers from a one-pair hand
fn get_pair_and_kickers(cards: Array<Card>) -> (u16, Array<Card>) {
    let sorted = sort_cards_by_value_desc(cards);
    let mut value_counts = Default::default();
    
    // Count card frequencies
    for card in sorted {
        value_counts.insert(card.value.into(), value_counts.get(card.value.into()) + 1);
    }

    // Find the pair and kickers
    let mut pair_value = 0;
    let mut kickers = array![];
    
    for card in sorted {
        if value_counts.get(card.value.into()) == 2 {
            pair_value = card.value;
        } else {
            kickers.append(card);
        }
    }

    (pair_value, kickers)
}

/// @gelluisaac
/// Helper function to sort cards by value in descending order
fn sort_cards_by_value_desc(mut cards: Array<Card>) -> Array<Card> {
    let mut sorted = false;
    while !sorted {
        sorted = true;
        let mut i = 0;
        while i < cards.len() - 1 {
            if *cards.at(i).value < *cards.at(i + 1).value {
                let temp = *cards.at(i);
                cards = set_array_element(cards, i, *cards.at(i + 1));
                cards = set_array_element(cards, i + 1, temp);
                sorted = false;
            }
            i += 1;
        }
    }
    cards
}

// Additional comparison functions for other hand ranks would follow here...

/// @pope-h
/// Generates all k-card combinations from a given array of cards
fn generate_combinations(cards: Array<Card>, k: usize) -> Array<Array<Card>> {
    let n = cards.len();
    let mut result: Array<Array<Card>> = array![];
    let total: u32 = pow(2, n.try_into().unwrap());
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

/// @pope-h
/// Performs bitwise AND operation simulation
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

/// @pope-h
/// Calculates the power of a number
fn pow(base: u32, exp: u32) -> u32 {
    let mut result = 1_u32;
    let mut i = 0_u32;
    while i < exp {
        result *= base;
        i += 1;
    };
    result
}

/// @pope-h
/// Evaluates a 5-card hand and determines its poker rank
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
    let mut sorted: Array<(u16, u16, u8)> = bubble_sort(card_data.clone());

    // Extract all tuple elements for each card
    let (orig_val0, poker_val0, suit0) = *sorted.at(0);
    let (orig_val1, poker_val1, suit1) = *sorted.at(1);
    let (orig_val2, poker_val2, suit2) = *sorted.at(2);
    let (orig_val3, poker_val3, suit3) = *sorted.at(3);
    let (orig_val4, poker_val4, suit4) = *sorted.at(4);

    // Check for flush using suits
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

/// @pope-h
/// Performs bubble sort on an array of card tuples
fn bubble_sort(mut arr: Array<(u16, u16, u8)>) -> Array<(u16, u16, u8)> {
    let mut swapped = true;
    while swapped {
        swapped = false;
        let mut i: usize = 0;
        while i < arr.len() - 1 {
            let (orig_val_curr, poker_val_curr, suit_curr) = *arr.at(i);
            let (orig_val_next, poker_val_next, suit_next) = *arr.at(i + 1);

            if poker_val_curr < poker_val_next {
                arr = set_array_element(arr.clone(), i, (orig_val_next, poker_val_next, suit_next));
                arr = set_array_element(arr, i + 1, (orig_val_curr, poker_val_curr, suit_curr));
                swapped = true;
            };
            i += 1;
        };
    };
    arr
}

/// @pope-h
/// Performs bubble sort on an array of u8 values
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
/// Immutably sets an element in an array
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