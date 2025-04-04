use starknet::ContractAddress;
use super::card::Card;
use poker::traits::hand::HandTrait;

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







/// Place holder tests
#[cfg(test)]
mod tests {
    use super::*;
    use starknet::ContractAddress;
    use poker::models::card::{Card, Royals, Suit};
    use poker::models::game::GameParams;
    use core::num::traits::Zero;

    #[test]
    fn test_compare_hands_basic() {
        // Test basic hand comparison (one clear winner)
        let player1 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Hearts, value: Royals::ACE },
                Card { suit: Suit::Diamonds, value: Royals::ACE }
            ]
        };

        let player2 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Clubs, value: 10 },
                Card { suit: Suit::Spades, value: 10 }
            ]
        };

        let community_cards = array![
            Card { suit: Suit::Hearts, value: 8 },
            Card { suit: Suit::Diamonds, value: 8 },
            Card { suit: Suit::Clubs, value: 2 },
            Card { suit: Suit::Spades, value: 3 },
            Card { suit: Suit::Hearts, value: 5 }
        ];

        let game_params = GameParams { kicker_split: false };
        let hands = array![player1, player2];
        let winners = HandTrait::compare_hands(hands, community_cards, game_params);

        assert(winners.len() == 1, "Should have one winner");
        // Add more specific assertions about the winning hand
    }

    #[test]
    fn test_compare_hands_tie_with_kicker() {
        // Test tie scenario where kicker determines winner
        let player1 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Hearts, value: Royals::KING },
                Card { suit: Suit::Diamonds, value: Royals::QUEEN }
            ]
        };

        let player2 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Clubs, value: Royals::KING },
                Card { suit: Suit::Spades, value: Royals::JACK }
            ]
        };

        let community_cards = array![
            Card { suit: Suit::Hearts, value: Royals::KING },
            Card { suit: Suit::Diamonds, value: 8 },
            Card { suit: Suit::Clubs, value: 2 },
            Card { suit: Suit::Spades, value: 3 },
            Card { suit: Suit::Hearts, value: 5 }
        ];

        let game_params = GameParams { kicker_split: false };
        let hands = array![player1, player2];
        let winners = HandTrait::compare_hands(hands, community_cards, game_params);

        assert(winners.len() == 1, "Should have one winner based on kicker");
        // Add assertions about the winning hand having the queen kicker
    }

    #[test]
    fn test_compare_hands_split_pot() {
        // Test scenario where pot should be split
        let player1 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Hearts, value: Royals::KING },
                Card { suit: Suit::Diamonds, value: Royals::QUEEN }
            ]
        };

        let player2 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Clubs, value: Royals::KING },
                Card { suit: Suit::Spades, value: Royals::QUEEN }
            ]
        };

        let community_cards = array![
            Card { suit: Suit::Hearts, value: Royals::KING },
            Card { suit: Suit::Diamonds, value: 8 },
            Card { suit: Suit::Clubs, value: 2 },
            Card { suit: Suit::Spades, value: 3 },
            Card { suit: Suit::Hearts, value: 5 }
        ];

        let game_params = GameParams { kicker_split: true };
        let hands = array![player1, player2];
        let winners = HandTrait::compare_hands(hands, community_cards, game_params);

        assert(winners.len() == 2, "Should split pot between two equal hands");
    }

    #[test]
    fn test_compare_hands_straight_flush_vs_four_of_a_kind() {
        // Test high-ranking hand comparison
        let player1 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Hearts, value: 10 },
                Card { suit: Suit::Hearts, value: 9 }
            ]
        };

        let player2 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Clubs, value: Royals::ACE },
                Card { suit: Suit::Diamonds, value: Royals::ACE }
            ]
        };

        let community_cards = array![
            Card { suit: Suit::Hearts, value: 8 },
            Card { suit: Suit::Hearts, value: 7 },
            Card { suit: Suit::Hearts, value: 6 },
            Card { suit: Suit::Clubs, value: Royals::ACE },
            Card { suit: Suit::Spades, value: Royals::ACE }
        ];

        let game_params = GameParams { kicker_split: false };
        let hands = array![player1, player2];
        let winners = HandTrait::compare_hands(hands, community_cards, game_params);

        assert(winners.len() == 1, "Should have one winner");
        // Add assertion that straight flush beats four of a kind
    }

    #[test]
    fn test_compare_hands_high_card_tiebreaker() {
        // Test high card scenario with tiebreakers
        let player1 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Hearts, value: Royals::ACE },
                Card { suit: Suit::Diamonds, value: 7 }
            ]
        };

        let player2 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Clubs, value: Royals::ACE },
                Card { suit: Suit::Spades, value: 6 }
            ]
        };

        let community_cards = array![
            Card { suit: Suit::Hearts, value: 10 },
            Card { suit: Suit::Diamonds, value: 9 },
            Card { suit: Suit::Clubs, value: 4 },
            Card { suit: Suit::Spades, value: 3 },
            Card { suit: Suit::Hearts, value: 2 }
        ];

        let game_params = GameParams { kicker_split: false };
        let hands = array![player1, player2];
        let winners = HandTrait::compare_hands(hands, community_cards, game_params);

        assert(winners.len() == 1, "Should have one winner based on second highest card");
        // Add assertion about the winning hand having higher kicker
    }

    #[test]
    fn test_compare_hands_multiple_players() {
        // Test with multiple players (3+)
        let player1 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Hearts, value: Royals::ACE },
                Card { suit: Suit::Diamonds, value: Royals::ACE }
            ]
        };

        let player2 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Clubs, value: Royals::KING },
                Card { suit: Suit::Spades, value: Royals::KING }
            ]
        };

        let player3 = Hand {
            player: ContractAddress::default(),
            cards: array![
                Card { suit: Suit::Hearts, value: Royals::QUEEN },
                Card { suit: Suit::Diamonds, value: Royals::QUEEN }
            ]
        };

        let community_cards = array![
            Card { suit: Suit::Hearts, value: 10 },
            Card { suit: Suit::Diamonds, value: 9 },
            Card { suit: Suit::Clubs, value: 8 },
            Card { suit: Suit::Spades, value: 7 },
            Card { suit: Suit::Hearts, value: 6 }
        ];

        let game_params = GameParams { kicker_split: false };
        let hands = array![player1, player2, player3];
        let winners = HandTrait::compare_hands(hands, community_cards, game_params);

        assert(winners.len() == 1, "Should have one winner among three players");
        // Add assertion about the winning hand being the pair of aces
    }
}