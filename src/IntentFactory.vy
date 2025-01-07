# SPDX-License-Identifier: MIT

"""
@title Intent Factory
@notice Factory contract for deploying Intent proxies using ERC-1167 minimal proxy pattern
@dev This factory creates minimal proxy contracts that point to a single implementation
     contract, allowing for gas-efficient deployment of many intent contracts with the
     same logic but different parameters. It uses CREATE2 for deterministic addresses.
@author Ultrasound Labs
@custom:security contact@ultrasoundlabs.org
"""

from snekmate.utils import create2_address

# Interface defining the required functions that must be implemented by the Intent contract
# This ensures type safety when interacting with deployed intent proxies
interface IIntent:
    def initialize(filler: address, token: address, amount: uint256, callee: address, calldata: Bytes[4096]): payable
    def fill(nonce: uint256): payable
    def reclaim(): payable

# The address of the implementation contract that all proxies will delegate to
# This is immutable and set once during factory deployment to prevent tampering
implementation: public(immutable(address))

# Events emitted when new intents are created
# Indexed parameters allow efficient filtering in event logs
event IntentCreated:
    proxy: indexed(address)    # The address of the newly created proxy contract
    filler: indexed(address)   # The address authorized to fill this intent
    token: address            # The token being used (or empty for ETH)
    amount: uint256          # Amount of token/ETH per fill

@deploy
def __init__(implementation_addr: address):
    """
    @notice Initialize the factory with the implementation contract address
    @dev This is called once during factory deployment and sets the immutable implementation address
    @param implementation_addr The address of the Intent implementation contract that proxies will delegate to
    """
    implementation = implementation_addr

@external
@payable
def createIntent(token: address, amount: uint256, callee: address, calldata: Bytes[4096]) -> address:
    """
    @notice Creates a new Intent proxy with specified parameters
    @dev Uses CREATE2 opcode to deploy a minimal proxy contract with deterministic address
         The proxy delegates all calls to the implementation contract while maintaining its own storage
    @param token The ERC20 token address (or empty for ETH)
    @param amount The amount of token/ETH per fill
    @param callee The contract to be called during fill
    @param calldata The data to be passed to the callee
    @return The address of the created proxy
    """
    # Create unique salt by hashing all parameters together
    # This ensures different parameters result in different addresses
    salt: bytes32 = keccak256(abi_encode(token, amount, callee, calldata))
    
    # Deploy minimal proxy using create2 for deterministic addressing
    # The proxy will delegate all calls to the implementation contract
    proxy: address = create_minimal_proxy_to(implementation, salt=salt)
    
    # Initialize the proxy's storage with the intent-specific parameters
    # This can only be called once per proxy due to checks in the implementation
    extcall IIntent(proxy).initialize(msg.sender, token, amount, callee, calldata)
    
    # Emit event for indexing and tracking purposes
    # This allows easy discovery of created intents
    log IntentCreated(proxy, msg.sender, token, amount)
    
    return proxy

@external
@view
def computeIntentAddress(token: address, amount: uint256, callee: address, calldata: Bytes[4096]) -> address:
    """
    @notice Computes the address where an intent proxy would be deployed
    @dev Uses the same salt computation and the same init code used by `create_minimal_proxy_to`
    @param token The ERC20 token address (or empty for ETH)
    @param amount The amount of token/ETH per fill
    @param callee The contract to be called during fill
    @param calldata The data to be passed to the callee
    @return The deterministic address where the proxy would be deployed
    """
    # Compute the same salt that createIntent uses
    salt: bytes32 = keccak256(abi_encode(token, amount, callee, calldata))

    # Construct the same init code used by create_minimal_proxy_to(self.implementation).
    # The standard EIP-1167 minimal proxy runtime code (with `implementation` inlined).
    # The bytecode below is exactly what Vyper uses internally for create_minimal_proxy_to.
    init_code: Bytes[45] = concat(
        b"\x36\x3d\x3d\x37\x3d\x3d\x3d\x36\x3d\x73",      # First 10 bytes of EIP-1167
        convert(implementation, bytes20),            # 20 bytes for implementation address
        b"\x5a\xf4\x3d\x82\x80\x3e\x90\x3d\x91\x60\x2b\x57\xfd\x5b\xf3"  # Last 15 bytes of EIP-1167
    )

    # Get keccak256 of that init_code.
    init_code_hash: bytes32 = keccak256(init_code)

    # Use snekmate to calculate the address
    return create2_address._compute_address(salt, init_code_hash, self)

@external
def multiFill(intent_addresses: address[10], nonces: uint256[10]):
    """
    @notice Fill multiple intents at once
    @dev Iterates through arrays of intents and their nonces, attempting to fill each
         Continues even if individual fills fail (revert_on_failure=False)
         Stops processing when it encounters an empty address
    @param intent_addresses Array of intent proxy addresses to fill
    @param nonces Array of nonces for each intent (must match array length)
    """
    for i: uint256 in range(10):
        # Stop processing when we hit an empty address
        # This allows processing variable-length arrays efficiently
        if intent_addresses[i] == empty(address):
            break
        # Attempt to fill each intent, ignoring failures
        # This ensures one failed fill doesn't block the entire batch
        _: bool = raw_call(
            intent_addresses[i],
            abi_encode(nonces[i], method_id=method_id("fill(uint256)")),
            revert_on_failure=False
        )

@external
def multiReclaim(intent_addresses: address[10]):
    """
    @notice Reclaim multiple intents at once
    @dev Iterates through array of intents, attempting to reclaim each
         Continues even if individual reclaims fail (revert_on_failure=False)
         Stops processing when it encounters an empty address
    @param intent_addresses Array of intent proxy addresses to reclaim
    """
    for i: uint256 in range(10):
        # Stop processing when we hit an empty address
        # This allows processing variable-length arrays efficiently
        if intent_addresses[i] == empty(address):
            break
        # Attempt to reclaim each intent, ignoring failures
        # This ensures one failed reclaim doesn't block the entire batch
        _: bool = raw_call(
            intent_addresses[i],
            method_id("reclaim()"),
            revert_on_failure=False
        )
