use super::card::Card;
use poker::traits::deck::DeckTrait;
#[derive(Serde, Drop, Clone, Default, PartialEq)]
#[dojo::model]
pub struct Deck {
    #[key]
    id: u64,
    cards: Array<Card>,
}
