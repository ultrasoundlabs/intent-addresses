"""
@title Intent Signal
@notice Contract for broadcasting intent fill signals
@dev This contract enables cross-chain intent coordination by broadcasting intent creation events.
     Projects can integrate with this system by implementing a signal gateway contract that 
     notifies this contract whenever new intents are created in their application.
     Relayers who have whitelisted the gateway contract can then monitor these signals
     and execute the corresponding intents on other chains.
     All intent relayers actively monitor this contract for new intent signals.
"""

event Signal:
    # The address that initiated the signal.
    # This address SHOULD be the gateway contract of an app
    # that integrates intent addresses and passes their intents
    # to this contract through their gateway contract.
    # Relayers then may add their gateway contract to their whitelists
    # to receive intent signals initiated by them, if they trust the app.
    caller: indexed(address)
    # The chain ID of the destination chain.
    # Relayers may use this indexed parameter to filter intents by destination chain
    # where they have enough liquidity to fill the intent.
    # For example, the relayer may choose to only fill intents with Base as destination.
    destinationChainId: indexed(uint256)
    # The token being used (or zero address for ETH)
    # This is indexed to allow filtering by token in off-chain relayers.
    # For example, the relayer may choose to only fill intents with USDC as token,
    # because they only have USDC as liquidity.
    token: indexed(address)
    # Amount of token/ETH per fill.
    # This is not indexed because it's relayer's job
    # to determine whether they have enough liquidity to fill the intent.
    amount: uint256
    # The contract to be called during fill
    callee: address
    # The calldata to be passed to the callee
    data: Bytes[4096]

@external
def broadcastSignal(
    destinationChainId: uint256,
    token: address,
    amount: uint256,
    callee: address,
    data: Bytes[4096]
):
    """
    @notice Broadcasts a cross-chain intent signal
    @dev Off-chain relayers can watch for the `SignalBroadcast` event and execute the corresponding 
         intent on other chains.
    @param destinationChainId The chain ID of the destination chain
    @param token The ERC20 token address (or empty for ETH)
    @param amount The amount of token/ETH to be used in each fill
    @param callee The contract to be called during fill
    @param data The calldata to be passed to the callee
    """
    log Signal(msg.sender, destinationChainId, token, amount, callee, data)