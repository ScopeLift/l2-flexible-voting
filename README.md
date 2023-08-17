# L2 Flexible Voting

**This codebase contains smart contracts that enable governance voting from Layer 2 rollups using bridged tokens. The current implementation is an MVP. These contracts have not yet been audited or deployed in production. Use at your own risk.**

- [About](#about)
- [Architecture](#architecture)
- [Testing](#testing)
- [License](#license)


## About

[Flexible Voting](https://www.scopelift.co/blog/introducing-flexible-voting) is a Governor extension that enables arbitrary voting contracts to be developed, allowing token holders to maintain their voting rights even when they deposit tokens in DeFi or any other contract.

This codebase contains smart contracts that enable governance voting from Layer 2 rollups using bridged tokens. Today, when a user deposits their governance token into a bridge, they lose access to the voting rights of that token. These contracts allow holders of bridged governance tokens to vote on Layer 2—paying the lower gas fees these networks offer—then see their votes reflected on Layer 1 in a trust minimized fashion.

The current implementation was built with a grant from the Ethereum Foundation. It is a minimum viable product, demonstrating the feasibility of such a system with a set of contracts that *could* be deployed in production. Please note these contracts have not yet been audited, and should be used only with caution in their current state.


## Architecture

Our initial architecture is shown in the diagram below. This provides a high level overview of what we plan to build and is subject to change.

<div align="center">
  <img width="900" src="./img/l2_flexible_voting_diagram.png" alt="Initial L2 Diagram">
</div>


## Development

### Foundry

This project uses [Foundry](https://github.com/foundry-rs/foundry). Follow [these instructions](https://github.com/foundry-rs/foundry#installation) to install it.


#### Getting started

Clone the repo

```bash
git clone git@github.com:ScopeLift/l2-flexible-voting.git
cd l2-flexible-voting
```

Copy the `.env.template` file and populate it with values

```bash
cp sample .env
# Open the .env file and add your values
```

```bash
forge install
forge build
forge test
```

### Formatting

Formatting is done via [scopelint](https://github.com/ScopeLift/scopelint). To install scopelint, run:

```bash
cargo install scopelint
```

#### Apply formatting

```bash
scopelint fmt
```

#### Check formatting

```bash
scopelint check
```

## Scripts

This repository contains a series of Foundry scripts which can be used to deploy and exercise the contracts on testnets or real networks.

These scripts are meant for end-to-end testing on real networks. They should not be used as-is for production deployments.

## License

This project is available under the [MIT](LICENSE.txt) license.

Copyright (c) 2023 ScopeLift
