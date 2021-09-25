# @version 0.2.16
"""
@title Curve Child Chain Gauge Factory
@license MIT
@author Curve.fi
@notice Child chain gauge factory enabling permissionless deployment of cross chain gauges
"""


interface ChildGauge:
    def initialize(_deployer: address, _receiver: address): nonpayable


event OwnershipTransferred:
    _owner: address
    _new_owner: address

event GaugeDeployed:
    _deployer: indexed(address)
    _gauge: address
    _receiver: address

event ImplementationUpdated:
    _implementation: address
    _new_implementation: address


owner: public(address)
future_owner: public(address)

get_implementation: public(address)
get_size: public(uint256)
# Using MAX_UINT256 raises `Exception: Value too high`
get_gauge: public(address[MAX_INT128])

nonces: public(HashMap[address, uint256])


@external
def __init__():
    self.owner = msg.sender

    log OwnershipTransferred(ZERO_ADDRESS, msg.sender)


@external
@nonreentrant("lock")
def deploy_gauge(_receiver: address) -> address:
    """
    @notice Deploy a child gauge
    @param _receiver Rewards receiver for the child gauge
    @return The address of the deployed and initialized child gauge
    """
    # generate the salt used for CREATE2 deployment of gauge
    nonce: uint256 = self.nonces[msg.sender]
    salt: bytes32 = keccak256(_abi_encode(chain.id, msg.sender, nonce))
    gauge: address = create_forwarder_to(self.get_implementation, salt=salt)

    # increase the nonce of the deployer
    self.nonces[msg.sender] = nonce + 1

    # append the newly deployed gauge to list of chain's gauges
    size: uint256 = self.get_size
    self.get_gauge[size] = gauge
    self.get_size = size + 1

    # initialize the gauge
    ChildGauge(gauge).initialize(msg.sender, _receiver)

    log GaugeDeployed(msg.sender, gauge, _receiver)
    return gauge


@external
def set_implementation(_implementation: address):
    """
    @notice Set the child gauge implementation
    @param _implementation The child gauge implementation contract address
    """
    assert msg.sender == self.owner

    implementation: address = self.get_implementation
    self.get_implementation = _implementation

    log ImplementationUpdated(implementation, _implementation)


@external
def commit_transfer_ownership(_new_owner: address):
    """
    @notice Transfer ownership of to `_new_owner`
    @param _new_owner New owner address
    """
    assert msg.sender == self.owner  # dev: owner only
    self.future_owner = _new_owner


@external
def accept_transfer_ownership():
    """
    @notice Accept ownership
    @dev Only callable by the future owner
    """
    new_owner: address = self.future_owner
    assert msg.sender == new_owner  # dev: new owner only

    owner: address = self.owner
    self.owner = new_owner

    log OwnershipTransferred(owner, new_owner)
