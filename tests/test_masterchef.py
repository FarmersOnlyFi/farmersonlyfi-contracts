import pytest

from brownie import accounts, reverts


@pytest.fixture
def token1(Token):
    return accounts[0].deploy(Token, "Token1", "TST1", 18, 1000)


@pytest.fixture
def vault_chef(VaultChef):
    return VaultChef.deploy({'from': accounts[0]})


def test_transfer(token1):
    token1.transfer(accounts[1], 100, {'from': accounts[0]})
    assert token1.balanceOf(accounts[0]) == 900


def test_vaultchef_add_operators_as_owner(vault_chef):
    assert vault_chef.poolLength() == 0
    assert vault_chef.operators(accounts[0]) == False
    assert vault_chef.operators(accounts[1]) == False

    # Add an account as the operator
    txn = vault_chef.updateOperator(accounts[1], True, {'from': accounts[0]})
    assert txn.status == 1
    assert vault_chef.operators(accounts[0]) == False
    assert vault_chef.operators(accounts[1]) == True
    assert vault_chef.operators(accounts[2]) == False

    # Add an account as the operator
    txn = vault_chef.updateOperator(accounts[0], True, {'from': accounts[0]})
    assert txn.status == 1
    assert vault_chef.operators(accounts[0]) == True
    assert vault_chef.operators(accounts[1]) == True
    assert vault_chef.operators(accounts[2]) == False


def test_vaultchef_add_operators_as_rando(vault_chef):
    # Rando shouldn't be able to add operators
    with reverts('Ownable: caller is not the owner'):
        txn = vault_chef.updateOperator(accounts[2], True, {'from': accounts[3]})
        assert txn.status == 0
    assert vault_chef.operators(accounts[0]) == False
    assert vault_chef.operators(accounts[1]) == False
    assert vault_chef.operators(accounts[2]) == False

    # The operator shouldn't be able to add other operators
    txn = vault_chef.updateOperator(accounts[1], True, {'from': accounts[0]})
    assert txn.status == 1
    with reverts('Ownable: caller is not the owner'):
        txn = vault_chef.updateOperator(accounts[2], True, {'from': accounts[1]})
        assert txn.status == 0
    assert vault_chef.operators(accounts[0]) == False
    assert vault_chef.operators(accounts[1]) == True
    assert vault_chef.operators(accounts[2]) == False
