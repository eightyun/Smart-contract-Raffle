# Proveably Random Raffle Contracts

## About

This code is to create a proveably random smart contract lottery.

## What we want it to do?

1. User can enter by paying for a ticket
   1. The ticket fees are going to go to the winner during the draw
2. After X period of time, the lottery will automatically draw a winner
   1. And this will be done programatically
3. Using Chainlink VRF & Chainlink Automation
   1. Chainlink VRF -> Randomness
   2. Chainlink Automation -> Time based trigger

## Test

1. Write some deploy scripts
2. write out tests
   1. Work on a local chain
   2. Forked Testnet
   3. Forkde Mainnet