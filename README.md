# L2 Flexible Voting

⚠️ **This codebase is a work in progress and not meant to be used in a production setting.**

- [About](#about)
- [Architecture](#architecture)
- [License](#license)


## About

[Flexible voting](https://www.scopelift.co/blog/introducing-flexible-voting) is a Governor extension that allows arbitrary delegate contracts to be developed. Allowing token holders to maintain their voting rights even when they choose to use their tokens in Defi or any other contract that supports flexible voting.

In this repo, we are building a production ready proof of concept for Layer 2 flexible voting. When a user deposits their governance token into a bridge they lose access to the voting rights of that token. We hope to solve this problem and allow for token holders to take advantage of the gas fees on Layer 2.


## Architecture

Our initial architecture is shown in the diagram below. This provides a high level overview of what we plan to build and is subject to change.

<div align="center">
  <img width="900" src="./img/l2_flexible_voting_diagram.png" alt="Initial L2 Diagram">
</div>

## License

This project is available under the [MIT](LICENSE.txt) license.

Copyright (c) 2023 ScopeLift

