// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@oz-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {PausableUpgradeable} from "@oz-upgradeable/security/PausableUpgradeable.sol";
import "@oz-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import {Initializable} from "@oz-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {XERC20Upgradeable} from "./XERC20Upgradeable.sol";

import {AccessManagementUpgradeable} from "./AccessManagementUpgradeable.sol";
import {ERC20PaymentReferenceUpgradeable} from "./ERC20PaymentReferenceUpgradeable.sol";

contract XTokenGnosis is
    Initializable,
    ERC20Upgradeable,
    // FeaturePausableUpgradeable,
    PausableUpgradeable,
    AccessManagementUpgradeable,
    ERC20PermitUpgradeable,
    // FlashMintUpgradeable,
    ERC20PaymentReferenceUpgradeable,
    XERC20Upgradeable,
    UUPSUpgradeable
{
    // bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00; // inherited
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");
    bytes32 public constant BRIDGE_ADMIN_ROLE = keccak256("BRIDGE_ADMIN_ROLE");

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __ERC20_init("MYTKN", "MYTKN");

        __Pausable_init();
        __AccessManagement_init(initialOwner);
        __ERC20Permit_init("MYTKN");
        __ERC20PaymentReference_init();
        __XERC20_init();
        __UUPSUpgradeable_init();
    }

    function decimals() public pure virtual override returns (uint8) {
        return 6;
    }

    //
    // CONTRACT management
    //

    /// @notice Triggers emergency stopped state.
    function pause() external virtual onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Returns contract from the emergency paused state to the normal state.
    function unpause() external virtual onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Authorisation check of the upgrade mechanisms
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}

    //
    // BRIDGE management
    //

    /**
     * @notice Sets the EIP 7281 lockbox address
     *
     * @param _lockbox The address of the lockbox
     */

    function setLockbox(address _lockbox) public virtual onlyRole(BRIDGE_ADMIN_ROLE) {
        emit LockboxSet(_lockbox);
        lockbox = _lockbox;
    }

    /**
     * @notice Updates the limits of any bridge
     * @dev Can only be called by the BRIDGE_ADMIN_ROLE
     * @param _mintingLimit The updated minting limit we are setting to the bridge
     * @param _burningLimit The updated burning limit we are setting to the bridge
     * @param _bridge The address of the bridge we are setting the limits too
     */
    function setBridgeLimits(
        address _bridge,
        uint256 _mintingLimit,
        uint256 _burningLimit
    ) external virtual onlyRole(BRIDGE_ADMIN_ROLE) {
        emit BridgeLimitsSet(_mintingLimit, _burningLimit, _bridge);
        _changeMinterLimit(_bridge, _mintingLimit);
        _changeBurnerLimit(_bridge, _burningLimit);
    }

    //
    // MINT / BURN functions
    //

    /**
     * @notice Mints tokens for a user
     * @dev Can only be called by a bridge having `MINTER_ROLE`
     * @param _user The address of the user who needs tokens minted
     * @param _amount The amount of tokens being minted
     */

    function mint(address _user, uint256 _amount) public virtual onlyRole(MINTER_ROLE) {
        _mintWithCaller(msg.sender, _user, _amount);
    }

    /**
     * @notice Burns tokens for a user
     * @dev Can only be called by a bridge having `BURNER_ROLE`
     * @param _user The address of the user who needs tokens burned
     * @param _amount The amount of tokens being burned
     */

    function burn(address _user, uint256 _amount) public virtual onlyRole(BURNER_ROLE) {
        if (msg.sender != _user) {
            _spendAllowance(_user, msg.sender, _amount);
        }

        _burnWithCaller(msg.sender, _user, _amount);
    }

    //
    // TRANSFER functions
    //

    /// @notice Moves `amount` tokens from `from` to `to` using the allowance mechanism with offchain permit.
    /// Does not zero the allowance amount in case of infinite allowance (max uint256).
    /// Caller can have any or no role assigned.
    function transferFromWithPermit(
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual anyRole {
        permit(from, msg.sender, amount, deadline, v, r, s);
        transferFrom(from, to, amount);
    }

    /// @notice Rescue tokens locked up in this contract.
    function rescueERC20(address to, uint256 amount) public virtual onlyRole(RESCUER_ROLE) {
        _transfer(address(this), to, amount);
    }

    // Adds pausability check to the `_beforeTokenTransfer` hook
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    //
    // INTROSPECTION functions
    //

    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return
            interfaceId == 0x36372b07 || // type(IERC20).interfaceId
            interfaceId == 0x7f5828d0 || // ERC173 contract ownership - complementary to RBAC
            interfaceId == 0x8da5cb5b || // ER5313 owner() - complementary to RBAC
            interfaceId == 0x9d8ff7da || // type(IERC2612).interfaceId
            interfaceId == 0x7965db0b || // type(IAccessControl).interfaceId
            // add EIP 7281 xERC20 interface once finalised
            interfaceId == 0x01ffc9a7; // type(IERC165).interfaceId
    }
}
