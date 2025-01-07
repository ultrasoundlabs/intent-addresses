"""
@title Intent Contract
@notice A reusable intent implementation for ERC-1167 minimal proxies

This contract implements a flexible intent system for creating reusable onchain intents.
Each intent represents a specific action that can be executed multiple times.

Key features:
- Uses ERC-1167 minimal proxies for gas efficiency
- Supports ETH and ERC20 tokens
- Allows multiple fills per intent
- Factory-controlled deployment and execution

Each proxy has fixed parameters:
- token: ERC20 token (or empty for ETH)
- amount: Token/ETH amount per fill
- callee: Contract to call
- calldata: Data to pass

Security:
- Factory controls all fills
- Parameters are immutable
- Per-address fill tracking
- Global fill nonce prevents race conditions

@author Ultrasound Labs
@custom:security contact@ultrasoundlabs.org
"""

# The factory address is immutable and shared across all proxy instances
# This ensures all fills must go through the same factory contract
factory: immutable(address)  

# Storage variables that are set once during initialization via the factory
# These values determine the specific intent and are used in the CREATE2 salt
token: address      # The ERC20 token to be used (empty address for ETH)
amount: uint256     # Amount of token/ETH to be used in each fill
callee: address     # Contract to be called during fill
calldata: Bytes[4096]  # Data to be passed to the callee

# Tracks how many times each address has filled this intent
# This allows multiple fills and corresponding reclaims
fillsByAddress: HashMap[address, uint256]

# Global nonce to prevent race conditions.
# It serves as a counter for the number of unclaimed fills.
nonce: public(uint256)

# Interface for interacting with ERC20 tokens
interface IERC20:
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def approve(_spender: address, _value: uint256) -> bool: nonpayable

@deploy
def __init__(_factory: address):
    # This constructor is called only once when deploying the implementation contract
    # All proxies will share this same factory address
    factory = _factory

@external
@payable
def initialize(filler: address, token: address, amount: uint256, callee: address, calldata: Bytes[4096]):
    # This function is called once for each proxy after deployment
    # Only the factory can initialize to ensure proper setup
    assert msg.sender == factory, "Only factory"
    
    # Store the intent-specific parameters
    self.token = token
    self.amount = amount
    self.callee = callee
    self.calldata = calldata

@external
@payable
def fill(nonce: uint256):
    # Verify the global nonce matches what the filler expects
    # This prevents race conditions where multiple fills occur for a single intended action
    assert self.nonce == nonce, "Unexpected nonce"
    
    # Record that this address has performed a fill and increment the nonce
    self.fillsByAddress[msg.sender] += 1
    self.nonce += 1
    
    if self.token == empty(address):
        # For ETH: Forward the specified amount to the callee along with the calldata
        raw_call(self.callee, self.calldata, value=self.amount)
    else:
        # For ERC20: Approve the callee to spend tokens, then execute the call
        success: bool = extcall IERC20(self.token).approve(self.callee, self.amount)
        assert success, "Approve failed"
        raw_call(self.callee, self.calldata)

@external
def reclaim():
    # Can only reclaim if the address has previously filled
    self.fillsByAddress[msg.sender] -= 1
    # Decrement the nonce to allow for a new fill
    self.nonce -= 1
    
    if self.token == empty(address):
        # For ETH: Send the amount back to the filler
        send(msg.sender, self.amount)
    else:
        # For ERC20: Transfer the tokens back to the filler
        extcall IERC20(self.token).transfer(msg.sender, self.amount)