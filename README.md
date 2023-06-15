# L2 Flexible voting


- [About](#about)
- [Development](#development)
  - [Instructions](#instructions)
- [License](#license)

## About 

L2 flexible voting allows Daos to bridge governance tokens and vote with those tokens on a layer 2.


## Testing

To currently test the bridge add a wallet private key that has some native tokens on avalanche fuji
and polygon mumbai. Then run the below docker commands to setup the spy and local redis node.

```
docker run --rm -p6379:6379 --name redis-docker -d redis 


docker run \
    --platform=linux/amd64 \
    -p 7073:7073 \
    --entrypoint /guardiand \
    ghcr.io/wormhole-foundation/guardiand:latest \
spy --nodeKey /node.key --spyRPC "[::]:7073" --network /wormhole/testnet/2/1 --bootstrap
 /dns4/wormhole-testnet-v2-bootstrap.certus.one/udp/8999/quic/p2p/12D3KooWAkB9ynDur1Jtoa
97LBUp8RXdhzS5uHgAfdTquJbrbN7i

```


Once those are running you will need to setup the L2 relayer. Follow the instructions 
[here](https://github.com/ScopeLift/l2-wormhole-relayer-engine). Now, you should be able to run 
the `MintOnL2` script demonstrating passing a  message cross-chain.
