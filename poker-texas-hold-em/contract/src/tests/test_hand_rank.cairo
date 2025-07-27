#[cfg(test)]
mod tests {
    use core::num::traits::Zero;
    use starknet::{ContractAddress, contract_address_const};
    use crate::models::card::{Card, Royals, Suits};
    use crate::models::hand::{Hand, HandRank, HandTrait};

    #[test]
    fn test_rank_straight_low_and_compare_hands() {
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

    #[test]
    fn test_rank_straight_high() {
        let player_cards: Array<Card> = array![
            Card { suit: Suits::CLUBS, value: 2 }, Card { suit: Suits::SPADES, value: 10 },
        ];

        let player: ContractAddress = contract_address_const::<'PLAYER'>();
        let player_hand: Hand = Hand { player, cards: player_cards };

        let community_cards = array![
            Card { suit: Suits::HEARTS, value: 5 },
            Card { suit: Suits::SPADES, value: Royals::JACK },
            Card { suit: Suits::SPADES, value: Royals::QUEEN },
            Card { suit: Suits::SPADES, value: Royals::KING },
            Card { suit: Suits::HEARTS, value: Royals::ACE },
        ];

        let (hand, hand_rank): (Hand, HandRank) = player_hand.rank(community_cards);
        let rank: ByteArray = hand_rank.into();
        println!("Rank of Straight High is: {}", rank);
        println!("Straight High Test new Hand:\n{}", hand.to_bytearray());
        assert(hand_rank == HandRank::STRAIGHT, 'HAND NOT STRAIGHT HIGH');
    }

    #[test]
    fn test_rank_royal_flush() {
        let player_cards: Array<Card> = array![
            Card { suit: Suits::HEARTS, value: 2 }, Card { suit: Suits::SPADES, value: 10 },
        ];

        let player: ContractAddress = contract_address_const::<'PLAYER'>();
        let player_hand: Hand = Hand { player, cards: player_cards };

        let community_cards = array![
            Card { suit: Suits::HEARTS, value: 5 },
            Card { suit: Suits::SPADES, value: Royals::JACK },
            Card { suit: Suits::SPADES, value: Royals::QUEEN },
            Card { suit: Suits::SPADES, value: Royals::KING },
            Card { suit: Suits::SPADES, value: Royals::ACE },
        ];

        let (hand, hand_rank): (Hand, HandRank) = player_hand.rank(community_cards);
        let rank: ByteArray = hand_rank.into();
        println!("Rank of Royal Flush is: {}", rank);
        println!("Royal Flush Test new Hand:\n{}", hand.to_bytearray());
        assert(hand_rank == HandRank::ROYAL_FLUSH, 'HAND NOT ROYAL FLUSH');
    }

    #[test]
    fn test_rank_straight_flush() {
        let player_cards: Array<Card> = array![
            Card { suit: Suits::HEARTS, value: 2 }, Card { suit: Suits::HEARTS, value: 5 },
        ];

        let player: ContractAddress = contract_address_const::<'PLAYER'>();
        let player_hand: Hand = Hand { player, cards: player_cards };

        let community_cards = array![
            Card { suit: Suits::HEARTS, value: 3 },
            Card { suit: Suits::HEARTS, value: 6 },
            Card { suit: Suits::HEARTS, value: 4 },
            Card { suit: Suits::SPADES, value: Royals::ACE },
        ];

        let (hand, hand_rank): (Hand, HandRank) = player_hand.rank(community_cards);
        let rank: ByteArray = hand_rank.into();
        println!("Rank of Straight Flush is: {}", rank);
        println!("Straight Flush Test new Hand:\n{}", hand.to_bytearray());
        assert(hand_rank == HandRank::STRAIGHT_FLUSH, 'HAND NOT STRAIGHT FLUSH');
    }

    #[test]
    fn test_rank_four_of_a_kind() {
        let player_cards: Array<Card> = array![
            Card { suit: Suits::CLUBS, value: Royals::JACK },
            Card { suit: Suits::HEARTS, value: Royals::JACK },
        ];

        let player: ContractAddress = contract_address_const::<'PLAYER'>();
        let player_hand: Hand = Hand { player, cards: player_cards };

        let community_cards = array![
            Card { suit: Suits::HEARTS, value: 5 },
            Card { suit: Suits::DIAMONDS, value: Royals::JACK },
            Card { suit: Suits::SPADES, value: Royals::JACK },
        ];

        let (hand, hand_rank): (Hand, HandRank) = player_hand.rank(community_cards);
        let rank: ByteArray = hand_rank.into();
        println!("Rank of Four of a kind is: {}", rank);
        println!("Four of a kind Test new Hand:\n{}", hand.to_bytearray());
        assert(hand_rank == HandRank::FOUR_OF_A_KIND, 'HAND NOT FOUR OF A KIND');
    }

    #[test]
    fn test_rank_full_house() {
        let player_cards: Array<Card> = array![
            Card { suit: Suits::HEARTS, value: 2 }, Card { suit: Suits::SPADES, value: 10 },
        ];

        let player: ContractAddress = contract_address_const::<'PLAYER'>();
        let player_hand: Hand = Hand { player, cards: player_cards };

        let community_cards = array![
            Card { suit: Suits::HEARTS, value: 10 },
            Card { suit: Suits::SPADES, value: Royals::JACK },
            Card { suit: Suits::SPADES, value: 2 },
            Card { suit: Suits::DIAMONDS, value: 2 },
            Card { suit: Suits::SPADES, value: Royals::ACE },
        ];

        let (hand, hand_rank): (Hand, HandRank) = player_hand.rank(community_cards);
        let rank: ByteArray = hand_rank.into();
        println!("Rank of Full House is: {}", rank);
        println!("Full House Test new Hand:\n{}", hand.to_bytearray());
        assert(hand_rank == HandRank::FULL_HOUSE, 'HAND NOT FULL HOUSE');
    }

    #[test]
    fn test_rank_two_pair() {
        let player_cards: Array<Card> = array![
            Card { suit: Suits::HEARTS, value: 10 }, Card { suit: Suits::SPADES, value: 10 },
        ];

        let player: ContractAddress = contract_address_const::<'PLAYER'>();
        let player_hand: Hand = Hand { player, cards: player_cards };

        let community_cards = array![
            Card { suit: Suits::HEARTS, value: 2 },
            Card { suit: Suits::SPADES, value: 2 },
            Card { suit: Suits::DIAMONDS, value: 5 },
        ];

        let (hand, hand_rank): (Hand, HandRank) = player_hand.rank(community_cards);
        let rank: ByteArray = hand_rank.into();
        println!("Rank of Two pair is: {}", rank);
        println!("Two pair Test new Hand:\n{}", hand.to_bytearray());
        assert(hand_rank == HandRank::TWO_PAIR, 'HAND NOT TWO PAIR');
    }
}
