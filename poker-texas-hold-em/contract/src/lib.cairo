mod systems {
    mod actions;
    mod interface;
}

mod models {
    mod deck;
    mod game;
    mod hand;
    mod player;
    mod card;
    mod base;
}

mod traits {
    mod handtrait;
    mod game;
    mod handimpl;
    mod deck;
    mod player;
}

mod utils {
    mod hand;
    mod game;
    mod deck;
}

#[cfg(test)]
mod tests {
    mod erc20;
    mod setup;
    mod test_actions;
    mod test_hand_compare;
    mod test_hand_rank;
    mod test_world;
    mod test_resolve_round;
    mod test_game_init;
}
