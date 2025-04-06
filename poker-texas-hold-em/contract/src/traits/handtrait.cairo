use poker::models::hand::{Hand, HandRank};
use poker::models::card::Card;
use poker::models::game::GameParams;
use super::handimpl::HandImpl;

pub trait HandTrait {
    /// Returns a default empty hand with a zero player address
    fn default() -> Hand;

    /// Reinitializes the target hand.
    ///
    /// This function reinitializes the target hand with it's existing player address, but with
    /// an empty array of cards.
    fn new_hand(ref self: Hand);

    /// @pope-h
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
    /// 2. The rank of the hand as HandRank
    ///
    /// # Panics
    /// Panics if the total number of cards is not exactly 7
    fn rank(self: @Hand, community_cards: Array<Card>) -> (Hand, HandRank);

    /// @Birdmannn
    /// Compares all hands combined with the community cards in the game to evaluate the highest of
    /// them all
    ///
    /// This function determines the highest card combo in all cards passed into it, combined with
    /// the community cards.
    ///
    /// # Arguments
    /// * `hands` - An array of hands to be compared.
    /// * `community_cards` - And array of the community cards to be used for the coombination per
    /// hand * `game_params` - The game params for checks to determine the right return values. It
    /// checks the `kicker_split` value and the return value is based on that value
    ///
    /// # Returns
    /// A tuple containing
    /// 1. A Span of Winning Hands that comes out alive from the Array inputted in the params
    /// 2. The `HandRank` value of the corresponding Hands... All Hands returned are always equal in
    /// rank
    /// 3. The Span of cards that did the kicking. This will be used by the splitting logic to
    /// split the pot based on the ratio extracted from the returned kicker cards.
    /// The len > 0 only if game_params.kicker_split is true.
    fn compare_hands(
        hands: Array<Hand>, community_cards: Array<Card>, game_params: GameParams,
    ) -> (Span<Hand>, HandRank, Span<Card>);
    fn remove_card(ref self: Hand, pos: usize) -> Card;
    fn reveal(self: @Hand) -> Span<Card>;
    fn add_card(ref self: Hand, card: Card);
    fn to_bytearray(self: @Hand) -> ByteArray;
}
