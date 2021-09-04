import pytest

from test_utils import *


def test_deposit(strat_sushiswap, vault_chef, sushi_chef, weth, lp_token, reward_token):
    # First setup the vault chef with the strat
    vault_chef.addPool(strat_sushiswap, {'from': accounts[0]})
    assert vault_chef.poolInfo(0) == (lp_token.address, strat_sushiswap.address)

    # The vault shouldn't have any lp coins in the masterchef
    # And acc 2 shoudln't have any lp coins in the vault
    assert sushi_chef.userInfo(0, vault_chef)[0] == 0
    assert sushi_chef.userInfo(0, strat_sushiswap)[0] == 0
    assert vault_chef.userInfo(0, accounts[2]) == 0
    lp_token.safeApprove(vault_chef, 1e55, {'from': accounts[2]})
    vault_chef.deposit(0, 10000, {'from': accounts[2]})

    # The strat should now have 5 in the farm and
    # the user should have 5 in the vault
    assert sushi_chef.userInfo(0, vault_chef)[0] == 0
    assert sushi_chef.userInfo(0, strat_sushiswap)[0] == 10000
    assert vault_chef.userInfo(0, accounts[2]) == 10000

    # Now compound and check the user balance


    assert sushi_chef.address == ''
