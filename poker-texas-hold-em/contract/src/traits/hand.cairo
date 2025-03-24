use starknet::ContractAddress;
use poker::models::hand::{Hand, HandRank};
use poker::models::card::{Card, DEFAULT_NO_OF_CARDS, Royals};
use poker::models::game::GameParams;
use core::num::traits::Zero;
use core::dict::Felt252DictTrait;

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

        /// We need to find the best 5-card hand from all available cards
        /// First, analyze the cards to gather statistics
        
        // Count occurrences of each value (1 to 14)
        let mut value_counts: Felt252Dict<u8> = Default::default();
        let mut k = 1_u16;
        while k <= 14 {
            value_counts.insert(k.into(), 0);
            k += 1;
        };

        // Count cards by suit (0 to 3)
        let mut suit_counts: Felt252Dict<u8> = Default::default();
        let mut s = 0_u8;
        while s < 4 {
            suit_counts.insert(s.into(), 0);
            s += 1;
        };

        // Fill the value and suit counts
        let mut c = 0;
        while c < all_cards.len() {
            let card = *all_cards.at(c);
            // Update value count
            let value = card.value; // u16
            let count = value_counts.get(value.into()); // Convert u16 to felt252
            value_counts.insert(value.into(), count + 1);

            // Update suit count
            let suit = card.suit; // u8
            let count = suit_counts.get(suit.into()); // Convert u8 to felt252
            suit_counts.insert(suit.into(), count + 1);

            c += 1;
        };

        // this function can be called externally in the future.
        (Self::default(), 0) // Temporary return value
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