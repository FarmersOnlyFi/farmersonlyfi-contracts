# FarmersOnly Vaults

https://farmersonly.fi. Feel free to read the code. More details coming soon.

## Setup

Setup a venv and install brownie
```properties
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Install Zepplin dependencies

```properties
brownie pm install OpenZeppelin/openzeppelin-contracts@3.1.0
```

Add the Harmony networks to brownie
```properties
brownie networks add Harmony one-test host=https://api.s0.b.hmny.io chainid=1666700000 explorer=https://explorer.pops.one/
brownie networks add Harmony one-main host=https://api.harmony.one chainid=1666600000 explorer=https://explorer.harmony.one/
```

Run tests with `brownie test`


## Deployed Contracts

- VaultChef: 


## Contracts

### Testnet

SushiswapRouter = 0x1b02da8cb0d097eb8d57a175b88c7d8b47997506
WONEAddress = 0x7a2afac38517d512e55c0bce3b6805c10a04d60f

## MainNet


