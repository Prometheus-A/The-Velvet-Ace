use starknet::ContractAddress;
use super::card::Card;
use poker::traits::handtrait::HandTrait;

/// Created once and for all for every available player.
#[derive(Serde, Drop, Clone, Debug, PartialEq)]
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
/// UNDEFINED: No card is present.
#[derive(Drop, Copy, Serde, PartialEq)]
pub enum HandRank {
    ROYAL_FLUSH,
    STRAIGHT_FLUSH,
    FOUR_OF_A_KIND,
    FULL_HOUSE,
    FLUSH,
    STRAIGHT,
    THREE_OF_A_KIND,
    TWO_PAIR,
    ONE_PAIR,
    HIGH_CARD,
    UNDEFINED,
}

impl HandRankU16 of Into<HandRank, u16> {
    #[inline(always)]
    fn into(self: HandRank) -> u16 {
        match self {
            HandRank::UNDEFINED => 0,
            HandRank::HIGH_CARD => 1,
            HandRank::ONE_PAIR => 2,
            HandRank::TWO_PAIR => 3,
            HandRank::THREE_OF_A_KIND => 4,
            HandRank::STRAIGHT => 5,
            HandRank::FLUSH => 6,
            HandRank::FULL_HOUSE => 7,
            HandRank::FOUR_OF_A_KIND => 8,
            HandRank::STRAIGHT_FLUSH => 9,
            HandRank::ROYAL_FLUSH => 10,
        }
    }
}

impl HandRankByteArray of Into<HandRank, ByteArray> {
    #[inline(always)]
    fn into(self: HandRank) -> ByteArray {
        match self {
            HandRank::UNDEFINED => "UNDEFINED",
            HandRank::HIGH_CARD => "HIGH CARD",
            HandRank::ONE_PAIR => "ONE PAIR",
            HandRank::TWO_PAIR => "TWO PAIR",
            HandRank::THREE_OF_A_KIND => "THREE OF A KIND",
            HandRank::STRAIGHT => "STRAIGHT",
            HandRank::FLUSH => "FLUSH",
            HandRank::FULL_HOUSE => "FULL HOUSE",
            HandRank::FOUR_OF_A_KIND => "FOUR OF A KIND",
            HandRank::STRAIGHT_FLUSH => "STRAIGHT FLUSH",
            HandRank::ROYAL_FLUSH => "ROYAL FLUSH",
        }
    }
}

impl U16HandRank of Into<u16, HandRank> {
    #[inline(always)]
    fn into(self: u16) -> HandRank {
        match self {
            0 => HandRank::UNDEFINED,
            1 => HandRank::HIGH_CARD,
            2 => HandRank::ONE_PAIR,
            3 => HandRank::TWO_PAIR,
            4 => HandRank::THREE_OF_A_KIND,
            5 => HandRank::STRAIGHT,
            6 => HandRank::FLUSH,
            7 => HandRank::FULL_HOUSE,
            8 => HandRank::FOUR_OF_A_KIND,
            9 => HandRank::STRAIGHT_FLUSH,
            10 => HandRank::ROYAL_FLUSH,
            _ => HandRank::UNDEFINED,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{Card, Hand, HandTrait, HandRank};
    use crate::models::card::{Suits, Royals};
    use starknet::{contract_address_const, ContractAddress};
    use core::num::traits::Zero;

    /// For check.
    #[test]
    fn test_rank_straight_low() {
        let player_cards: Array<Card> = array![
            Card { suit: Suits::CLUBS, value: 2 }, Card { suit: Suits::SPADES, value: 4 },
        ];

        let player: ContractAddress = contract_address_const::<'PLAYER'>();
        let player_hand: Hand = Hand { player, cards: player_cards };

        let community_cards = array![
            Card { suit: Suits::HEARTS, value: 10 },
            Card { suit: Suits::SPADES, value: Royals::ACE },
            Card { suit: Suits::SPADES, value: 5 },
            Card { suit: Suits::CLUBS, value: 3 },
            Card { suit: Suits::DIAMONDS, value: Royals::KING },
        ];

        let (hand, hand_rank): (Hand, HandRank) = player_hand.rank(community_cards.clone());
        let rank: ByteArray = hand_rank.into();
        println!("Player1 Hand rank is: {}", rank);
        assert(hand_rank == HandRank::STRAIGHT, 'NOT A STRAIGHT');
        println!("Player1 new Hand to byte array is:\n{}", hand.to_bytearray());

        // feign a one pair
        let player2: ContractAddress = contract_address_const::<'PLAYER2'>();
        let player2_cards: Array<Card> = array![
            Card { suit: Suits::CLUBS, value: 5 }, Card { suit: Suits::SPADES, value: 6 },
        ];

        let player2_hand: Hand = Hand { player: player2, cards: player2_cards };

        let (hand, hand_rank): (Hand, HandRank) = player2_hand.rank(community_cards.clone());
        let rank: ByteArray = hand_rank.into();
        println!("Player2 Hand rank is: {}", rank);
        assert(hand_rank == HandRank::ONE_PAIR, 'NOT A TWO PAIR');
        println!("Player2 new Hand to byte array is:\n{}", hand.to_bytearray());

        // NOTE: THIS IS WHEN THE VALUE OF KICKER_SPLIT IS FALSE.
        let (hands, hand_rank, kickers): (Span<Hand>, HandRank, Span<Card>) =
            HandTrait::compare_hands(
            array![player2_hand, player_hand], community_cards, Default::default(),
        );

        assert(kickers.len() == 0, 'KICKERS FOUND');
        assert(hands.len() == 1, 'INVALID HAND COUNT');
        assert(hand_rank == HandRank::STRAIGHT, 'INVALID RANK');

        let rank: ByteArray = hand_rank.into();
        println!("Hand rank to bytearray: {}", rank);

        let winning_hand: @Hand = hands.at(0);
        assert(*winning_hand.player == player, 'INCORRECT WINNER');
    }

    #[test]
    fn test_rank_high_card() {
        // for testing if the ranking works dynamically
        let player_cards: Array<Card> = array![
            Card { suit: Suits::CLUBS, value: 2 }, Card { suit: Suits::SPADES, value: 4 },
        ];

        let player: ContractAddress = contract_address_const::<'PLAYER'>();
        let player_hand: Hand = Hand { player, cards: player_cards };
        let (hand, hand_rank): (Hand, HandRank) = player_hand
            .rank(array![Card { suit: Suits::DIAMONDS, value: 13 }]);

        let rank: ByteArray = hand_rank.into();
        println!("Rank of High Card Test: {}", rank);
        println!("High Card test new Hand:\n{}", hand.to_bytearray());
        assert(hand_rank == HandRank::HIGH_CARD, 'RANKING FAILED ON HC');
    }

    #[test]
    fn test_rank_flush() {
        let player_cards: Array<Card> = array![
            Card { suit: Suits::CLUBS, value: 2 }, Card { suit: Suits::SPADES, value: 4 },
        ];

        let player: ContractAddress = contract_address_const::<'PLAYER'>();
        let player_hand: Hand = Hand { player, cards: player_cards };

        let community_cards = array![
            Card { suit: Suits::HEARTS, value: 5 },
            Card { suit: Suits::SPADES, value: 3 },
            Card { suit: Suits::SPADES, value: Royals::QUEEN },
            Card { suit: Suits::SPADES, value: 6 },
            Card { suit: Suits::SPADES, value: Royals::KING },
        ];

        let (hand, hand_rank): (Hand, HandRank) = player_hand.rank(community_cards.clone());
        let rank: ByteArray = hand_rank.into();

        println!("Rank of Test Flush is: {}", rank);
        println!("Flush Card test new Hand:\n{}", hand.to_bytearray());
        assert(hand_rank == HandRank::FLUSH, 'FLUSH RANKING FAILED');
    }

    /// TODO: WRITE A FUNCTION THAT PRODUCES FLUSH CARDS, TAKING A PARAMETER OF THE SUIT, AND IT'LL
    /// ITERATE THROUGH ONE TO THIRTEEN, MAKING THE SUIT APPEAR FIVE TIMES FOR EACH TOTAL HAND,
    /// RANDOMIZING OTHER CARDS.

    #[test]
    fn test_rank_three_of_a_kind() {
        let player_cards: Array<Card> = array![
            Card { suit: Suits::CLUBS, value: 2 }, Card { suit: Suits::SPADES, value: 4 },
        ];

        let player: ContractAddress = contract_address_const::<'PLAYER'>();
        let player_hand: Hand = Hand { player, cards: player_cards };

        let community_cards = array![
            Card { suit: Suits::HEARTS, value: 5 },
            Card { suit: Suits::SPADES, value: 3 },
            Card { suit: Suits::SPADES, value: Royals::QUEEN },
            Card { suit: Suits::SPADES, value: 2 },
            Card { suit: Suits::HEARTS, value: 2 },
        ];

        let (hand, hand_rank): (Hand, HandRank) = player_hand.rank(community_cards.clone());
        let rank: ByteArray = hand_rank.into();

        println!("Rank of Test Three Of a Kind is: {}", rank);
        println!("Three of a kind Card test new Hand:\n{}", hand.to_bytearray());
        assert(hand_rank == HandRank::THREE_OF_A_KIND, '3OFAKIND RANKING FAILED');
    }

    #[test]
    fn test_one_pair_with_zero_community_cards() {
        let player_cards: Array<Card> = array![
            Card { suit: Suits::CLUBS, value: 2 }, Card { suit: Suits::SPADES, value: 2 },
        ];

        let player: ContractAddress = contract_address_const::<'PLAYER'>();
        let player_hand: Hand = Hand { player, cards: player_cards };

        let (hand, hand_rank): (Hand, HandRank) = player_hand.rank(array![]);
        let rank: ByteArray = hand_rank.into();

        println!("Rank of One Pair (Zero) is: {}", rank);
        println!("One Pair test new Hand:\n{}", hand.to_bytearray());
        assert(hand_rank == HandRank::ONE_PAIR, 'ONE PAIR RANKING FAILED');
    }

    #[test]
    fn test_rank_undefined() {
        let player_hand: Hand = Hand { player: Zero::zero(), cards: array![] };
        let (hand, hand_rank): (Hand, HandRank) = player_hand.rank(array![]);

        assert(hand == player_hand, 'HAND ERR');
        assert(hand_rank == HandRank::UNDEFINED, 'HAND NOT UNDEFINED.');
    }
    /// TODO: CHECK VALUES FOR KICKER_SPLIT EQUALS FALSE, ONLY WHEN `extract_kicker` HAS BEEN
/// IMPLEMENTED FOR KICKER_SPLIT EQUALS FALSE, winning_hands.len() == 1. USE TWO HANDS OF THE
/// SAME RANK
///
/// TODO: TEST COMPARE HANDS OF VARIOUS NUMBER OF HANDS.
/// // for the test
// assert that the array of kicking cards are present in the winning hands
// .. or make
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