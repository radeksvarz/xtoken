// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@oz-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@oz-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {PausableUpgradeable} from "@oz-upgradeable/security/PausableUpgradeable.sol";
import "@oz-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import {Initializable} from "@oz-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {AccessManagementUpgradeable} from "./AccessManagementUpgradeable.sol";
import {ERC20PaymentReferenceUpgradeable} from "./ERC20PaymentReferenceUpgradeable.sol";
import {FeaturePausableUpgradeable} from "./FeaturePausableUpgradeable.sol";
import {FlashMintUpgradeable} from "./FlashMintUpgradeable.sol";

contract Token is
    Initializable,
    ERC20Upgradeable,
    FeaturePausableUpgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    AccessManagementUpgradeable,
    ERC20PermitUpgradeable,
    FlashMintUpgradeable,
    ERC20PaymentReferenceUpgradeable,
    UUPSUpgradeable
{
    // bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00; // inherited
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");
    bytes32 public constant FLASH_MINT_ADMIN_ROLE = keccak256("FLASH_MINT_ADMIN_ROLE");

    bytes32 public constant FLASH_MINT_FEATURE = keccak256("feature.FLASH_MINT");

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __ERC20_init("MYTKN", "MYTKN");
        __ERC20Burnable_init();
        __Pausable_init();
        __FeaturePausable_init();
        __AccessManagement_init(initialOwner);
        __ERC20Permit_init("MYTKN");
        __FlashMint_init(5, type(uint256).max, initialOwner);
        __ERC20PaymentReference_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Number of decimals used to get its user representation.
    /// 6 were selected for the compatibility among chains with stricter limitation.
    /// NOTE: This information is only used for _display_ purposes: it in
    /// no way affects any of the arithmetic of the contract, including
    /// {IERC20-balanceOf} and {IERC20-transfer}.
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

    /// @notice Triggers emergency stopped state of Flashminting feature
    function flashMintPause() external virtual onlyRole(FLASH_MINT_ADMIN_ROLE) {
        _pauseFeature(FLASH_MINT_FEATURE);
    }

    /// @notice Returns from emergency stopped state of Flashminting feature
    function flashMintUnpause() external virtual onlyRole(FLASH_MINT_ADMIN_ROLE) {
        _unpauseFeature(FLASH_MINT_FEATURE);
    }

    /// @notice Authorisation check of the upgrade mechanisms
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}

    //
    // MINT / BURN functions
    //

    /// @notice Creates `amount` tokens and assigns them to `account`, increasing the total supply.
    /// Caller has to have assigned MINTER_ROLE.
    function mint(address to, uint256 amount) public virtual onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /// @notice Destroys `amount` tokens from the caller.
    /// Caller has to have assigned BURNER_ROLE.
    function burn(uint256 amount) public virtual override onlyRole(BURNER_ROLE) {
        super.burn(amount);
    }

    /// @notice Destroys `amount` tokens from `from`, deducting from the caller's allowance.
    /// Does not update the allowance amount in case of infinite allowance (max uint256).
    /// Caller has to have assigned BURNER_ROLE.
    function burnFrom(address from, uint256 amount) public virtual override onlyRole(BURNER_ROLE) {
        super.burnFrom(from, amount);
    }

    /// @notice Destroys `amount` tokens from `from`, setting the caller's allowance to amount and then to zero.
    /// Zeroes the allowance amount even in case the infinite allowance (max uint256) is preset.
    /// Caller has to have assigned BURNER_ROLE.
    function burnFromWithPermit(
        address from,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual onlyRole(BURNER_ROLE) {
        permit(from, msg.sender, amount, deadline, v, r, s);
        super.burnFrom(from, amount);
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
    // FLASHMINT functions
    //

    /// @notice Returns the maximum amount of tokens available for flashmint loan.
    /// maxFloashLoan is always less than or equal to unsupplied amount, flashMintCeiling and thus _FLASHMINTHARDCAP
    /// @dev Added pausability check.
    /// Caller can have any or no role assigned.
    function maxFlashLoan(address token) public view virtual override anyRole returns (uint256) {
        if (paused() || featurePaused(FLASH_MINT_FEATURE)) return 0;
        return super.maxFlashLoan(token);
    }

    /// @dev Hook that is called before flash minting with pausability check
    function _beforeFlashMint(
        address borrower,
        uint256 amount
    ) internal virtual override whenNotPaused whenFeatureNotPaused(FLASH_MINT_FEATURE) {
        super._beforeFlashMint(borrower, amount);
    }

    /// @notice Sets new `flashMintCeiling` that caps flashmint volume
    /// New Ceiling is always less than or equal to _FLASHMINTHARDCAP
    /// Caller MUST have the FLASH_MINT_ADMIN_ROLE
    function setFlashMintCeiling(uint256 newCeiling) external virtual onlyRole(FLASH_MINT_ADMIN_ROLE) {
        _setFlashMintCeiling(newCeiling);
    }

    /// @notice Sets new `flashMintFeeBps` with max 10000 bps
    /// Caller MUST have the FLASH_MINT_ADMIN_ROLE
    function setFlashMintFeeBps(uint16 newFee) external virtual onlyRole(FLASH_MINT_ADMIN_ROLE) {
        _setFlashMintFeeBps(newFee);
    }

    /// @notice Sets new `flashMintFeeReceiver` the receiver address of the flash fee.
    /// Caller MUST have the FLASH_MINT_ADMIN_ROLE
    function setFlashMintFeeReceiver(address newReceiver) external virtual onlyRole(FLASH_MINT_ADMIN_ROLE) {
        _setFlashMintFeeReceiver(newReceiver);
    }

    //
    // INTROSPECTION functions
    //

    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return
            interfaceId == 0x36372b07 || // type(IERC20).interfaceId
            interfaceId == 0x7f5828d0 || // ERC173 contract ownership - complementary to RBAC
            interfaceId == 0x8da5cb5b || // ER5313 owner() - complementary to RBAC
            //            interfaceId == 0xb0202a11 || // type(IERC1363).interfaceId
            interfaceId == 0x9d8ff7da || // type(IERC2612).interfaceId
            interfaceId == 0xe4143091 || // type(IERC3156FlashLender).interfaceId
            interfaceId == 0x7965db0b || // type(IAccessControl).interfaceId
            interfaceId == 0x01ffc9a7; // type(IERC165).interfaceId
    }
}
