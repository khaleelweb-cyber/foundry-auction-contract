# BasicAuction — Foundry Smart Contract

A simple English auction contract built with Foundry.

## What it does
- Anyone can place a bid during the 1 hour auction window
- Outbid bidders can withdraw their ETH at any time
- When the auction ends, the highest bid is sent to the beneficiary

## Project Structure
- `src/BasicAuction.sol` — main contract
- `script/DeployBasicAuction.s.sol` — deploy script
- `test/BasicAuction.t.sol` — full test suite

## Usage

### Install dependencies
forge install

### Build
forge build

### Test
forge test -v

### Deploy locally
anvil
make deploy

### Deploy to Sepolia
make deploy-sepolia

## Author
IBRAHIM KHALEEL
## Deployed Contract
Sepolia: https://sepolia.etherscan.io/address/0x42b898c3f62dfDD929f15a8014D4085044e634d7
