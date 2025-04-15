use starknet::ContractAddress;
use poker::models::hand::{Hand, HandRank};
use poker::models::card::{Card, DEFAULT_NO_OF_CARDS, Royals, CardTrait};
use poker::models::game::GameParams;
use poker::utils::hand::{evaluate_cards, generate_combinations, min_u32, extract_kicker};
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

    /// @pope-h, @Birdmannn
    fn rank(self: @Hand, community_cards: Array<Card>) -> (Hand, HandRank) {
        // Combine player's hand cards with community cards
        let mut all_cards: Array<Card> = array![];
        if self.cards.len() == 0 && community_cards.len() == 0 {
            let mut hand: Hand = Self::default();
            hand.player = *self.player;
            return (hand, HandRank::UNDEFINED);
        }

        for i in 0..self.cards.len() {
            all_cards.append(*self.cards[i]);
        };

        for i in 0..community_cards.len() {
            all_cards.append(*community_cards[i]);
        };

        // Generate all max 5-card combinations (C(7,k)), where  0 <= k <= 5
        let k = min_u32(all_cards.len(), 5);
        let combinations = generate_combinations(all_cards.clone(), k);

        // Evaluate each combination to find the best hand
        let mut best_rank: u16 = HandRank::UNDEFINED.into();
        let mut best_hands: Array<Hand> = array![];

        for combo in combinations {
            let (hand_cards, rank) = evaluate_cards(combo.clone());
            let rank_u16: u16 = rank.into();
            if rank_u16 > best_rank {
                // New highest rank found; reset the collection
                best_rank = rank_u16;
                let hand = Hand { player: *self.player, cards: hand_cards.clone() };
                best_hands = array![hand];
            } else if rank_u16 == best_rank {
                // Equal rank; add to collection for tie-breaking
                let hand = Hand { player: *self.player, cards: hand_cards.clone() };
                best_hands.append(hand);
            }
        };

        // let best_hand: Hand = Self::default();

        // If only one hand has the best rank, return it directly
        if best_hands.len() == 1 {
            // let best_hand = Hand {
            //     player: *self.player, cards: best_hands.pop_front().unwrap().cards,
            // };
            return (best_hands.pop_front().unwrap(), best_rank.into());
        }

        // Multiple hands with the same rank; use extract_kicker to determine the best
        let (mut winning_hands, _) = extract_kicker(best_hands.clone(), best_rank);
        if winning_hands.len() == 0 {
            // Fallback to the first best hand if extract_kicker fails to return a hand
            let best_hand = Hand {
                player: *self.player, cards: best_hands.pop_front().unwrap().cards,
            };
            return (best_hand, best_rank.into());
        }
        let best_hand = Hand {
            player: *self.player, cards: winning_hands.pop_front().unwrap().cards,
        };

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
