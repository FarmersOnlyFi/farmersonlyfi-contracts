import pytest

from brownie import accounts, reverts

sushiYieldAddress = "0x67dA5f2FfaDDfF067AB9d5F025F8810634d84287"
uniRouterAddress = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506"
devAddress = "0xB989B490F9899a5AD56a4255A3C84457040B59dc"
feeAddress = "0x54EfdaE67807cf4394020e48c7262bdbbdEbd9F2"

DEFAULT_TOKEN_MINT_AMOUNT = 1e25

@pytest.fixture
def weth(WETH):
    return accounts[0].deploy(WETH)


@pytest.fixture
def token1(Token):
    return accounts[0].deploy(Token, "Token1", "TST1", 18, DEFAULT_TOKEN_MINT_AMOUNT)


@pytest.fixture
def token2(Token):
    return accounts[0].deploy(Token, "Token2", "TST2", 18, DEFAULT_TOKEN_MINT_AMOUNT)


@pytest.fixture
def reward_token(Token):
    return accounts[0].deploy(Token, "RewardToken", "REW", 18, DEFAULT_TOKEN_MINT_AMOUNT)


@pytest.fixture
def lp_token(MockLPToken, token1, token2):
    lp_token = accounts[0].deploy(MockLPToken, "LP Token", "LP", 18, DEFAULT_TOKEN_MINT_AMOUNT, token1.address, token2.address)
    lp_token.transfer(accounts[2], 1e18, {'from': accounts[0]})
    return lp_token


@pytest.fixture
def lp_token_weth(MockLPToken, weth, token2):
    lp_token = accounts[0].deploy(MockLPToken, "WETH/Token2 LP", "WETH LP", 18, DEFAULT_TOKEN_MINT_AMOUNT, weth.address, token2.address)
    lp_token.transfer(accounts[2], 1e18, {'from': accounts[0]})
    return lp_token


@pytest.fixture
def vault_chef(VaultChef):
    return VaultChef.deploy({'from': accounts[0]})


@pytest.fixture
def uniswap_router(MockUniRouter02, token1, token2, reward_token, lp_token):
    """Setup the router up with coins and ETH so it can trade"""
    router = MockUniRouter02.deploy(lp_token.address, {'from': accounts[0]})
    accounts[0].transfer(router, 1e18)
    lp_token.transfer(router, 1e18, {'from': accounts[0]})
    token1.transfer(router, 1e18, {'from': accounts[0]})
    token2.transfer(router, 1e18, {'from': accounts[0]})
    reward_token.transfer(router, 1e18, {'from': accounts[0]})
    return router


@pytest.fixture
def sushi_chef(MockSushiChef, reward_token, weth, lp_token):
    _chef = MockSushiChef.deploy(reward_token, weth, {'from': accounts[0]})
    # Initialize with some reward coins
    reward_token.transfer(_chef, 1e18, {'from': accounts[0]})
    weth.deposit({'from': accounts[0], "value": 1e18})
    weth.transfer(_chef, 1e18, {'from': accounts[0]})
    # Setup a pool
    _chef.add(100, lp_token, {'from': accounts[0]})

    return _chef


@pytest.fixture
def strat_sushiswap(StrategySushiSwap, sushi_chef, vault_chef, lp_token, reward_token, weth, uniswap_router):
    _earnedToWonePath = []
    _earnedToToken0Path = []
    _earnedToToken1Path = []
    _woneToToken0Path = []
    _woneToToken1Path = []
    _token0ToEarnedPath = []
    _token1ToEarnedPath = []
    return StrategySushiSwap.deploy(
        vault_chef.address,
        0,
        lp_token.address,
        reward_token.address,
        weth.address,
        sushi_chef.address,
        uniswap_router.address,
        _earnedToWonePath,
        _earnedToToken0Path,
        _earnedToToken1Path,
        _woneToToken0Path,
        _woneToToken1Path,
        _token0ToEarnedPath,
        _token1ToEarnedPath,
        {'from': accounts[0]}
    )


@pytest.fixture
def vault_chef_with_pool(strat_sushiswap, vault_chef, ):
    vault_chef.addPool(strat_sushiswap, {'from': accounts[0]})
    return vault_chef
