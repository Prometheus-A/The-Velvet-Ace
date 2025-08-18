#[cfg(test)]
mod tests {
    use crate::models::game::GameParams;
    use poker::traits::game::get_default_game_params;
    use poker::systems::interface::{IActionsDispatcher, IActionsDispatcherTrait};
    use poker::tests::setup::setup::{CoreContract, Systems, deploy_contracts};

    fn setup() -> (Systems, GameParams) {
        let contracts = array![CoreContract::Actions];
        let (_, systems) = deploy_contracts(contracts);
        let params: GameParams = get_default_game_params();
        return (systems, params);
    }

    #[test]
    fn test_initialize_game_works() {
        let (systems, mut params) = setup();

        let new_game_id: u64 = systems.actions.initialize_game(Option::Some(params));
        assert_eq!(new_game_id, 1, "Should have been first game");
    }

    #[test]
    #[should_panic(expected: ('PLAYER ALREADY LOCKED', 'ENTRYPOINT_FAILED'))]
    fn test_player_starts_twice() {
        let (systems, mut params) = setup();

        systems.actions.initialize_game(Option::Some(params));
        systems.actions.initialize_game(Option::Some(params));
    }

    #[test]
    #[should_panic(expected: ('INVALID GAME PARAMS', 'ENTRYPOINT_FAILED'))]
    fn test_player_overflow() {
        let (systems, mut params) = setup();
        params.max_no_of_players = 11;

        systems.actions.initialize_game(Option::Some(params));
    }

    #[test]
    #[should_panic(expected: ('MIN 2 PLAYERS REQUIRED', 'ENTRYPOINT_FAILED'))]
    fn test_player_underflow() {
        let (systems, mut params) = setup();
        params.max_no_of_players = 1;

        systems.actions.initialize_game(Option::Some(params));
    }

    #[test]
    #[should_panic(expected: ('INVALID GAME PARAMS', 'ENTRYPOINT_FAILED'))]
    fn test_small_blind_underflow() {
        let (systems, mut params) = setup();
        params.small_blind = 0;

        systems.actions.initialize_game(Option::Some(params));
    }

    #[test]
    #[should_panic(expected: ('INVALID GAME PARAMS', 'ENTRYPOINT_FAILED'))]
    fn test_big_blind_underflow() {
        let (systems, mut params) = setup();
        params.big_blind = 1;

        systems.actions.initialize_game(Option::Some(params));
    }

    #[test]
    #[should_panic(expected: ('INVALID BLIND VALUES', 'ENTRYPOINT_FAILED'))]
    fn test_big_blind_smaller_than_small_blind() {
        let (systems, mut params) = setup();
        params.small_blind = 10;
        params.big_blind = 5;

        systems.actions.initialize_game(Option::Some(params));
    }

    #[test]
    #[should_panic(expected: ('INVALID GAME PARAMS', 'ENTRYPOINT_FAILED'))]
    fn test_deck_underflow() {
        let (systems, mut params) = setup();
        params.no_of_decks = 0;

        systems.actions.initialize_game(Option::Some(params));
    }

    #[test]
    #[should_panic(expected: ('INVALID GAME PARAMS', 'ENTRYPOINT_FAILED'))]
    fn test_chips_underflow() {
        let (systems, mut params) = setup();
        params.min_amount_of_chips = 5;

        systems.actions.initialize_game(Option::Some(params));
    }

    #[test]
    #[should_panic(expected: ('INVALID GAME PARAMS', 'ENTRYPOINT_FAILED'))]
    fn test_blind_spacing_underflow() {
        let (systems, mut params) = setup();
        params.blind_spacing = 0;

        systems.actions.initialize_game(Option::Some(params));
    }
}
