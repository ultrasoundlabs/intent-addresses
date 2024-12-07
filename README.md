# Intent Addresses
ERC-4337-centric implementation of Intent Addresses by Ultrasound Labs. Details below

## What is it?

Intent Addresses are deterministic smart contract addresses generated using CREATE2 that enable single-use, self-destructing contracts with predefined functionality across all Ethereum-compatible networks. These contracts are designed to execute a specific action when deployed, such as token swaps or cross-chain transfers, using funds previously sent to their address. After completing their predetermined task, reimbursing gas costs, and sending assets to the beneficiary, these contracts self-destruct, making them a reliable mechanism for executing arbitrary operations across different EVM networks through a simple token transfer.

TODO: pic

Intent Addresses were first presented at [Devcon 7 SEA by Daimo team](https://www.youtube.com/watch?v=ioCdBWLmuI8). As the talk outlines the general concept without technical specifications, Ultrasound Labs utilizes this concept in its custom, universal implementation of Intent Addresses. The implementation is referred to as **ULIA** ("Yulia"; Ultrasound Labs' Intent Addresses) in this document.

## Overview

TODO
