## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Install Foundry

```shell
curl -L https://foundry.paradigm.xyz | bash
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

### Install OpenZepplin's upgraddeable contracts

```shell
$ forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
```

### Install OpenZepplin's contracts

```shell
$ forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

The --no-commit flag prevents the following error:

```shell
Error:
The target directory is a part of or on its own an already initialized git repository,
and it requires clean working and staging areas, including no untracked files.

Check the current git repository's status with `git status`.
Then, you can track files with `git add ...` and then commit them with `git commit`,
ignore them in the `.gitignore` file, or run this command again with the `--no-commit` flag.

If none of the previous steps worked, please open an issue at:
https://github.com/foundry-rs/foundry/issues/new/choose
```

### Remappings

```shell
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/
```

### Code formatting

```shell
"solidity.formatter": "prettier",
  "workbench.sideBar.location": "right",
#   "solidity.compileUsingRemoteVersion": "v0.8.20+commit.a1b79de6",
  "[solidity]": {
    "editor.defaultFormatter": "JuanBlanco.solidity",
    "editor.formatOnSave": true
  }
```

### Address of contract on the Sepolia testnet:

```shell
0xdAfAE67401db66dbe591d2A400e987416133Df6F
```

### Deploying

```shell
$ forge script script/DeployNFTMarketplace.s.sol:DeployNFTMarketplace --rpc-url sepolia --broadcast
```
