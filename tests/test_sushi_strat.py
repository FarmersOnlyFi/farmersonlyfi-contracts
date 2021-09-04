import pytest

from brownie import accounts, reverts, ZERO_ADDRESS

_sushiYieldAddress = "0x67dA5f2FfaDDfF067AB9d5F025F8810634d84287"
_uniRouterAddress = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506"
_devAddress = "0xB989B490F9899a5AD56a4255A3C84457040B59dc"
_feeAddress = "0x54EfdaE67807cf4394020e48c7262bdbbdEbd9F2"


@pytest.fixture
def weth(WETH):
    return accounts[0].deploy(WETH)


@pytest.fixture
def token1(Token):
    return accounts[0].deploy(Token, "Token1", "TST1", 18, 1000)


@pytest.fixture
def token2(Token):
    return accounts[0].deploy(Token, "Token2", "TST2", 18, 1000)


@pytest.fixture
def reward_token(Token):
    return accounts[0].deploy(Token, "RewardToken", "REW", 18, 1000)


@pytest.fixture
def lp_token(MockLPToken, token1, token2):
    lp_token = accounts[0].deploy(MockLPToken, "LP Token", "LP", 18, 1000, token1.address, token2.address)
    lp_token.transfer(accounts[2], 100, {'from': accounts[0]})
    return lp_token


@pytest.fixture
def vault_chef(VaultChef):
    return VaultChef.deploy({'from': accounts[0]})


@pytest.fixture
def strat_sushiswap(StrategySushiSwap, vault_chef, lp_token, reward_token, weth):
    _vaultChefAddress = vault_chef.address
    _pid = 1
    _wantAddress = lp_token.address
    _earnedAddress = reward_token.address
    _earnedToWonePath = []
    _earnedToToken0Path = []
    _earnedToToken1Path = []
    _woneToToken0Path = []
    _woneToToken1Path = []
    _token0ToEarnedPath = []
    _token1ToEarnedPath = []
    return StrategySushiSwap.deploy(
        _vaultChefAddress, _pid, _wantAddress, _earnedAddress, weth.address,
        _earnedToWonePath, _earnedToToken0Path, _earnedToToken1Path,
        _woneToToken0Path, _woneToToken1Path, _token0ToEarnedPath, _token1ToEarnedPath,
        {'from': accounts[0]}
    )


def test_sushi_strat_masterchef_setup(strat_sushiswap):
    strat = strat_sushiswap

    assert strat.pid() == 1
    assert strat.sushiYieldAddress() == _sushiYieldAddress
    assert strat.uniRouterAddress() == _uniRouterAddress
    assert strat.devAddress() == _devAddress
    assert strat.feeAddress() == _feeAddress
    assert strat.controllerFee() == 50
    assert strat.rewardFee() == 500


def test_add_strat_to_masterchef(strat_sushiswap, vault_chef):

    assert vault_chef.poolLength() == 0
    vault_chef.addPool(strat_sushiswap.address, {'from': accounts[0]})
    assert vault_chef.poolLength() == 1, "Failed to add strategy to vault chef"
    assert vault_chef.poolInfo(0) == (strat_sushiswap.wantAddress(), strat_sushiswap.address)

