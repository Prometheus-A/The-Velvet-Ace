// Check the Suits struct
#[derive(Copy, Drop, Serde, Default, Debug, Introspect, PartialEq)]
pub struct Card {
    suit: u8,
    value: u16,
}

pub const DEFAULT_NO_OF_CARDS: u8 = 52;

pub mod Royals {
    pub const ACE: u16 = 1;
    pub const JACK: u16 = 11;
    pub const QUEEN: u16 = 12;
    pub const KING: u16 = 13;
}
// IMPLEMENT A CARD TRAIT HERE, REMOVES A CARD BY SETTING THE SUIT AND VALUE TO ZERO OR SOMETHING

