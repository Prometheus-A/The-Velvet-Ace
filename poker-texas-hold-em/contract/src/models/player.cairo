use starknet::ContractAddress;
use core::num::traits::Zero;
use super::base::GameErrors;
use super::game::{Game, GameTrait, GameMode};
use poker::traits::player::PlayerTrait;

// the locked variable takes in a tuple of (is_locked, game_id) if the player is already
// locked to a session.
// Hand should be a reference.

// FOR NOW, NO PLAYER CAN HAVE MORE THAN ONE HAND.
// Go to all functions that use player as a parameter, and remove the snapshot
#[derive(Copy, Drop, Serde, Debug, Default, PartialEq, Hash)]
#[dojo::model]
pub struct Player {
    #[key]
    id: ContractAddress,
    alias: felt252,
    chips: u256,
    current_bet: u256,
    total_rounds: u64,
    locked: (bool, u64),
    is_dealer: bool,
    in_round: bool,
    out: (u64, u64),
    pub_key: felt252,
    locked_chips: u256,
    is_blacklisted: bool, // TODO: should be integrated in the future.
    eligible_pots: u8,
}
/// Write struct for player stats
/// Include an alias, if necessary, and add it as key.
#[derive(Copy, Drop, Serde, Debug, PartialEq, Hash)]
#[dojo::model]
pub struct PlayerStats {
    #[key]
    alias: felt252,
    games_played: u64,
    games_won: u64,
    hands_played: u64,
    hands_won: u64,
    total_chips_won: u256,
    total_chips_lost: u256,
    biggest_win: u256,
}

impl ContractAddressDefault of Default<ContractAddress> {
    #[inline(always)]
    fn default() -> ContractAddress {
        Zero::zero()
    }
}

/// TESTS ON PLAYER MODEL
#[cfg(test)]
mod tests {
    use dojo::event::EventStorageTest;
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
    use dojo::world::{WorldStorage, WorldStorageTrait};
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };
    use poker::models::game::{Game, GameTrait, ShowdownType};
    use poker::models::player::{Player, PlayerTrait};
    use poker::tests::setup::setup::{CoreContract, deploy_contracts};
    use poker::models::base::GameErrors;
    use poker::traits::game::get_default_game_params;
    use starknet::ContractAddress;
    use starknet::testing::{set_account_contract_address, set_contract_address};

    use crate::tests::test_actions::tests::{
        PLAYER_1, PLAYER_2, PLAYER_3, PLAYER_4, mock_poker_game, mock_player, mock_poker_game_flex,
    };

    fn mock_allowable_game(ref world: WorldStorage) {
        let player_1 = mock_player(
            PLAYER_1(), 'dub_zn', 2000, 0, 1, (true, 1), false, true, (0, 0),
        );
        let player_2 = mock_player(
            PLAYER_2(), 'Birdmannn', 5000, 0, 1, (true, 2), false, true, (0, 0),
        );
        let player_3 = mock_player(
            PLAYER_3(), 'chiscookeke11', 5000, 0, 1, (false, 1), false, true, (0, 0),
        );
        mock_poker_game_flex(
            ref world,
            true,
            false,
            1,
            false,
            2,
            array![PLAYER_1(), PLAYER_2(), PLAYER_3()],
            Option::Some(PLAYER_1()),
            array![],
            0,
            array![player_1, player_2, player_3],
        );
    }


    #[test]
    fn test_exit_with_out_true_succeeds() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_poker_game(ref world);
        let mut game = world.read_model(1);
        let mut player = world.read_model(PLAYER_1());
        player.exit(ref game, true);
        assert_eq!(
            player.out,
            (game.id, game.reshuffled),
            "Player out should be set to game id and reshuffled",
        );
        assert_eq!(player.current_bet, 0, "Player current bet should be reset to 0");
        assert_eq!(player.is_dealer, false, "Player should not be dealer after exit");
        assert_eq!(player.in_round, false, "Player should not be in round after exit");
        assert_eq!(player.locked, (false, 0), "Player should be unlocked after exit");
        assert_eq!(game.current_player_count, 1, "Game player count should decrease by 1");
    }

    #[test]
    fn test_exit_with_out_false_succeeds_and_updates_out() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_poker_game(ref world);
        let mut game = world.read_model(1);
        let mut player = world.read_model(PLAYER_1());
        player.exit(ref game, false);
        assert_eq!(player.out, (0, 0), "Player out should be set to game id and reshuffled");
        assert_eq!(player.current_bet, 0, "Player current bet should be reset to 0");
        assert_eq!(player.is_dealer, false, "Player should not be dealer after exit");
        assert_eq!(player.in_round, false, "Player should not be in round after exit");
        assert_eq!(player.locked, (false, 0), "Player should be unlocked after exit");
        assert_eq!(game.current_player_count, 1, "Game player count should decrease by 1");
    }

    #[test]
    #[should_panic(expected: 'CANNOT EXIT, PLAYER NOT LOCKED')]
    fn test_exit_without_lock_fails() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_poker_game(ref world);
        let mut game = world.read_model(1);
        let mut player: Player = world.read_model(PLAYER_3());
        player.locked = (false, 0);
        player.exit(ref game, true);
    }

    #[test]
    fn test_exit_with_splitted_showdown_returns_locked_chips() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_poker_game(ref world);
        let mut game: Game = world.read_model(1);
        let mut player: Player = world.read_model(PLAYER_1());
        let stake = 1000;
        game.params.showdown_type = ShowdownType::Splitted(stake);
        player.chips = 2000;
        player.locked_chips = stake;
        player.exit(ref game, true);
        assert_eq!(player.chips, 3000, "Player should get locked chips back");
        assert_eq!(player.locked_chips, 0, "Locked chips should be reset to 0");
    }

    #[test]
    #[should_panic(expected: 'GAME PLAYER COUNT SUB')]
    fn test_exit_with_zero_player_count_fails() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_poker_game(ref world);
        let mut game: Game = world.read_model(1);
        let mut player: Player = world.read_model(PLAYER_1());
        game.current_player_count = 0;
        player.exit(ref game, true);
    }

    #[test]
    #[should_panic(expected: 'BAD REQUEST')]
    fn test_exit_with_invalid_player_fails() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_poker_game(ref world);
        let mut game: Game = world.read_model(1);
        let mut player: Player = world.read_model(PLAYER_2());
        player.locked = (true, 999);
        player.exit(ref game, true);
    }

    #[test]
    fn test_enter_succeeds_new_player() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_allowable_game(ref world);
        let mut game: Game = world.read_model(1);
        let mut player: Player = mock_player(
            PLAYER_4(), 'Nobody', 5000, 0, 1, (false, 1), false, true, (0, 0),
        );
        let is_full = player.enter(ref game);
        assert_eq!(player.locked, (true, game.id), "Player should be locked to game");
        assert_eq!(player.in_round, true, "Player should be in round");
        assert_eq!(game.current_player_count, 3, "Game player count should increase");
        assert_eq!(is_full, false, "Game should not be full");
        assert_eq!(game.players.len(), 4, "Player should be added to game players");
        assert_eq!(*game.players.at(3), PLAYER_4(), "Last player should be PLAYER_4");
    }

    #[test]
    fn test_is_full_returns_true_when_game_full() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_allowable_game(ref world);
        let mut game: Game = world.read_model(1);
        game.current_player_count = 2;
        game.params.max_no_of_players = 3;
        let mut player: Player = mock_player(
            PLAYER_4(), 'Nobody', 5000, 0, 1, (false, 1), false, true, (0, 0),
        );
        let is_full = player.enter(ref game);
        assert_eq!(is_full, true, "Game should be full after player enters");
        assert_eq!(game.current_player_count, 3, "Game should have max players");
    }

    #[test]
    #[should_panic(expected: 'PLAYER ALREADY LOCKED')]
    fn test_enter_fails_when_player_already_locked() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_allowable_game(ref world);
        let mut game: Game = world.read_model(1);
        let mut player: Player = world.read_model(PLAYER_1());
        player.locked = (true, game.id);
        player.enter(ref game);
    }

    #[test]
    #[should_panic(expected: 'GAME NOT INITIALIZED')]
    fn test_enter_fails_when_game_not_initialized() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_poker_game_flex(
            ref world, false, false, 0, false, 0, array![], Option::None, array![], 0, array![],
        );
        let mut game: Game = world.read_model(1);
        let mut player: Player = mock_player(
            PLAYER_4(), 'Nobody', 5000, 0, 1, (false, 1), false, true, (0, 0),
        );
        player.enter(ref game);
    }

    #[test]
    #[should_panic(expected: 'GAME ALREADY ENDED')]
    fn test_enter_fails_when_game_ended() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_poker_game_flex(
            ref world,
            false,
            true,
            0,
            false,
            0,
            array![PLAYER_1()],
            Option::None,
            array![],
            0,
            array![],
        );
        let mut game: Game = world.read_model(1);
        let mut player: Player = mock_player(
            PLAYER_4(), 'Nobody', 5000, 0, 1, (false, 1), false, true, (0, 0),
        );
        player.enter(ref game);
    }

    #[test]
    #[should_panic(expected: 'INSUFFICIENT CHIPS')]
    fn test_enter_fails_when_insufficient_chips() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_allowable_game(ref world);
        let mut game: Game = world.read_model(1);
        let stake = 1000;
        game.params.showdown_type = ShowdownType::Splitted(stake);
        let mut player: Player = mock_player(
            PLAYER_4(), 'Nobody', 5000, 0, 1, (false, 1), false, true, (0, 0),
        );
        player.chips = 0;
        player.enter(ref game);
    }

    #[test]
    fn test_refresh_stake_succeeds_with_splitted_showdown() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_allowable_game(ref world);
        let mut game: Game = world.read_model(1);
        let stake = 1000;
        game.params.showdown_type = ShowdownType::Splitted(stake);
        let mut player: Player = mock_player(
            PLAYER_4(), 'Nobody', 5000, 0, 1, (false, 1), false, true, (0, 0),
        );
        player.chips = 2000;
        let result = player.refresh_stake(ref game);
        assert_eq!(result, true, "Refresh stake should succeed");
        assert_eq!(player.chips, 1000, "Player chips should be reduced by stake");
        assert_eq!(player.locked_chips, 1000, "Locked chips should equal stake");
    }

    #[test]
    fn test_refresh_stake_fails_with_insufficient_chips() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_allowable_game(ref world);
        let mut game: Game = world.read_model(1);
        let stake = 1000;
        game.params.showdown_type = ShowdownType::Splitted(stake);
        let mut player: Player = mock_player(
            PLAYER_4(), 'Nobody', 5000, 0, 1, (false, 1), false, true, (0, 0),
        );
        player.chips = 500;
        let result = player.refresh_stake(ref game);
        assert_eq!(result, false, "Refresh stake should fail");
    }

    #[test]
    fn test_is_maxed_returns_true_when_player_maxed() {
        let (mut world, _) = deploy_contracts(array![CoreContract::Actions]);
        mock_poker_game(ref world);
        let mut game: Game = world.read_model(1);
        let mut player: Player = world.read_model(PLAYER_1());
        player.chips = 0;
        player.current_bet = 0;
        player.eligible_pots = 0;
        let result = player.is_maxed(@game);
        assert_eq!(result, true, "Player should be maxed");
    }
}
