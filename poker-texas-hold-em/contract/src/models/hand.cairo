use starknet::ContractAddress;
use super::card::Card;
use poker::traits::handtrait::HandTrait;

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
    use crate::models::card::Suits;
    use starknet::{contract_address_const, ContractAddress};

    /// For check.
    #[test]
    fn test_rank_straight() {
        let player_cards: Array<Card> = array![
            Card { suit: Suits::CLUBS, value: 2 }, Card { suit: Suits::SPADES, value: 4 },
        ];

        let player: ContractAddress = contract_address_const::<'PLAYER'>();
        let player_hand: Hand = Hand { player, cards: player_cards };

        let community_cards = array![
            Card { suit: Suits::HEARTS, value: 5 },
            Card { suit: Suits::SPADES, value: 3 },
            Card { suit: Suits::SPADES, value: 12 },
            Card { suit: Suits::CLUBS, value: 6 },
            Card { suit: Suits::DIAMONDS, value: 13 },
        ];

        let (hand, hand_rank): (Hand, HandRank) = player_hand.rank(community_cards.clone());
        let rank: ByteArray = hand_rank.into();
        println!("Player1 Hand rank is: {}", rank);
        assert(hand_rank == HandRank::STRAIGHT, 'NOT A STRAIGHT');
        println!("Player1 new Hand to byte array is:\n{}", hand.to_bytearray());

        // feign a two pair
        let player2: ContractAddress = contract_address_const::<'PLAYER2'>();
        let player2_cards: Array<Card> = array![
            Card { suit: Suits::CLUBS, value: 5 }, Card { suit: Suits::SPADES, value: 6 },
        ];

        let player2_hand: Hand = Hand { player: player2, cards: player2_cards };

        let (hand, hand_rank): (Hand, HandRank) = player2_hand.rank(community_cards.clone());
        let rank: ByteArray = hand_rank.into();
        println!("Player2 Hand rank is: {}", rank);
        assert(hand_rank == HandRank::TWO_PAIR, 'NOT A TWO PAIR');
        println!("Player2 new Hand to byte array is:\n{}", hand.to_bytearray());

        // NOTE: THIS IS WHEN THE VALUE OF KICKER_SPLIT IS FALSE.
        let (hands, hand_rank, kickers): (Span<Hand>, HandRank, Span<Card>) =
            HandTrait::compare_hands(
            array![player2_hand, player_hand], community_cards, Default::default(),
        );

        assert(kickers.len() == 0, 'KICKERS FOUND');
        assert(hands.len() == 1, 'INVALID HAND COUNT');
        assert(hand_rank == HandRank::STRAIGHT.into(), 'INVALID RANK');

        let rank: ByteArray = hand_rank.into();
        println!("Hand rank to bytearray: {}", rank);

        let winning_hand: @Hand = hands.at(0);
        assert(*winning_hand.player == player, 'INCORRECT WINNER');
    }
}
