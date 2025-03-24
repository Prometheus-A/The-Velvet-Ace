use starknet::ContractAddress;
use poker::models::hand::{Hand, HandRank};
use poker::models::card::{Card, DEFAULT_NO_OF_CARDS, Royals};
use poker::models::game::GameParams;
use core::num::traits::Zero;

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
    /// This function will return the hand rank of the player's hand
    /// this will compare the cards on the player's hand with the community cards
    /// returns a new hand of the HandRank, to or to not be used.
    fn rank(self: @Hand, community_cards: Array<Card>) -> (Hand, u16) {
        // use HandRank to get the rank for a hand of one player
        // return using the HandRank::<the const>, and not the raw u16 value
        // compute the hand that makes up this rank you have computed
        // set the player value (a CA) to the player's CA with the particular hand
        // return both values in a tuple
        // document the function.

        // this function can be called externally in the future.
        // (Self::default(), 0)

        // Extract player and private cards
        let player = *self.player;
        let private_cards = *self.cards;

        // Combine private and community cards into a single array
        let mut all_cards = ArrayTrait::new();
        for card in private_cards {
            all_cards.append(*card);
        }
        for card in community_cards {
            all_cards.append(*card);
        }

        // Ensure exactly 7 cards (2 private + 5 community)
        assert(all_cards.len() == 7, 'Invalid card count');

        // Generate all possible 5-card combinations
        let combinations = generate_combinations(all_cards, 5);

        // Evaluate all combinations to find the best hand
        let mut best_rank: u16 = HandRank::HIGH_CARD; // Lowest rank as default
        let mut best_hand_cards: Array<Card> = array![];

        let mut i = 0;
        while i < combinations.len() {
            let combo = *combinations.at(i);
            let rank = evaluate_five_cards(combo);
            if rank > best_rank {
                best_rank = rank;
                best_hand_cards = combo;
            }
            i += 1;
        }

        // Create the best hand with the original player
        let best_hand = Hand { player, cards: best_hand_cards };

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

// Helper function to generate all k-card combinations from an array of cards
fn generate_combinations(cards: Array<Card>, k: u32) -> Array<Array<Card>> {
    let n = cards.len();
    let mut combinations = ArrayTrait::new();
    let total = 1_u32 << n; // 2^n possible subsets
    let mut i = 0;

    while i < total {
        let mut subset = ArrayTrait::new();
        let mut j = 0;
        while j < n {
            if (i & (1 << j)) != 0 {
                subset.append(*cards.at(j));
            }
            j += 1;
        }
        if subset.len() == k {
            combinations.append(subset);
        }
        i += 1;
    }
    combinations
}

// Helper function to evaluate a 5-card hand and return its rank
fn evaluate_five_cards(cards: Array<Card>) -> u16 {
    assert(cards.len() == 5, 'Must have 5 cards');

    // Map cards to (original_value, poker_value, suit) where Ace (1) becomes 14 for high
    let mut card_data = ArrayTrait::new();
    let mut i = 0;
    while i < cards.len() {
        let card = *cards.at(i);
        let poker_value = if card.value == Royals::ACE { 14_u16 } else { card.value };
        card_data.append((card.value, poker_value, card.suit));
        i += 1;
    }

    // Sort by poker_value descending (bubble sort)
    let mut sorted = card_data.clone();
    let mut swapped = true;
    while swapped {
        swapped = false;
        let mut j = 0;
        while j < sorted.len() - 1 {
            if *sorted.at(j).1 < *sorted.at(j + 1).1 {
                let temp = *sorted.at(j);
                sorted[j] = *sorted.at(j + 1);
                sorted[j + 1] = temp;
                swapped = true;
            }
            j += 1;
        }
    }

    // Check for flush (all suits identical)
    let is_flush = *sorted.at(0).2 == *sorted.at(1).2 
        && *sorted.at(1).2 == *sorted.at(2).2 
        && *sorted.at(2).2 == *sorted.at(3).2 
        && *sorted.at(3).2 == *sorted.at(4).2;

    // Check for straight
    let is_straight_high = *sorted.at(0).1 == *sorted.at(1).1 + 1 
        && *sorted.at(1).1 == *sorted.at(2).1 + 1 
        && *sorted.at(2).1 == *sorted.at(3).1 + 1 
        && *sorted.at(3).1 == *sorted.at(4).1 + 1;
    let is_straight_low = *sorted.at(0).0 == Royals::ACE 
        && *sorted.at(1).0 == 2 
        && *sorted.at(2).0 == 3 
        && *sorted.at(3).0 == 4 
        && *sorted.at(4).0 == 5;
    let is_straight = is_straight_high || is_straight_low;

    // Royal Flush and Straight Flush
    if is_flush && is_straight {
        if *sorted.at(0).1 == 14 { // Ace-high straight flush
            return HandRank::ROYAL_FLUSH;
        }
        return HandRank::STRAIGHT_FLUSH;
    }

    // Count occurrences of each value for pairs, three of a kind, etc.
    let mut value_counts: Felt252Dict<u8> = Default::default();
    i = 0;
    while i < sorted.len() {
        let count = value_counts.get((*sorted.at(i).0).into());
        value_counts.insert((*sorted.at(i).0).into(), count + 1);
        i += 1;
    }

    // Extract counts and sort them descending
    let mut counts = ArrayTrait::new();
    let mut entries = value_counts.entries();
    while let Option::Some(entry) = entries.pop_front() {
        counts.append(entry.value);
    }

    let mut sorted_counts = counts.clone();
    swapped = true;
    while swapped {
        swapped = false;
        let mut j = 0;
        while j < sorted_counts.len() - 1 {
            if *sorted_counts.at(j) < *sorted_counts.at(j + 1) {
                let temp = *sorted_counts.at(j);
                sorted_counts[j] = *sorted_counts.at(j + 1);
                sorted_counts[j + 1] = temp;
                swapped = true;
            }
            j += 1;
        }
    }

    // Four of a Kind
    if *sorted_counts.at(0) == 4 {
        return HandRank::FOUR_OF_A_KIND;
    }

    // Full House
    if *sorted_counts.at(0) == 3 && *sorted_counts.at(1) == 2 {
        return HandRank::FULL_HOUSE;
    }

    // Flush
    if is_flush {
        return HandRank::FLUSH;
    }

    // Straight
    if is_straight {
        return HandRank::STRAIGHT;
    }

    // Three of a Kind
    if *sorted_counts.at(0) == 3 {
        return HandRank::THREE_OF_A_KIND;
    }

    // Two Pair
    if *sorted_counts.at(0) == 2 && *sorted_counts.at(1) == 2 {
        return HandRank::TWO_PAIR;
    }

    // One Pair
    if *sorted_counts.at(0) == 2 {
        return HandRank::ONE_PAIR;
    }

    // High Card
    HandRank::HIGH_CARD
}