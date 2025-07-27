mod systems {
    mod actions;
    mod interface;
}

mod models {
    mod base;
    mod card;
    mod deck;
    mod game;
    mod hand;
    mod player;
}

mod traits {
    mod deck;
    mod game;
    mod handimpl;
    mod handtrait;
    mod player;
}

mod utils {
    mod deck;
    mod game;
    mod hand;
}

#[cfg(test)]
mod tests {
    mod erc20;
    mod setup;
    mod test_actions;
    mod test_hand_compare;
    mod test_hand_rank;
    mod test_resolve_round;
    mod test_world;
}
