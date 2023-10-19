// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "@oz-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@oz-upgradeable/access/AccessControlUpgradeable.sol";

/// Compliant with ERC173
abstract contract AccessManagementUpgradeable is Initializable, AccessControlUpgradeable {
    // bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00; // inherited

    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Granted role cannot be DEFAULT_ADMIN_ROLE. Use `transferOwnership` instead.
    error CannotGrantAdminRole();

    /// @notice Revoked role cannot be DEFAULT_ADMIN_ROLE. Use `transferOwnership` instead.
    error CannotRevokeAdminRole();

    /// @notice Modifier placeholder to explicitely describe that anyRole can execute such function
    modifier anyRole() {
        _;
    }

    /// @dev Initializes the contract ownership to the provided address as the initial owner.
    function __AccessManagement_init(address initialOwner) internal onlyInitializing {
        __AccessManagement_init_unchained(initialOwner);
    }

    /// @dev Initializes the contract ownership to the provided address as the initial owner.
    function __AccessManagement_init_unchained(address initialOwner) internal onlyInitializing {
        _transferOwnership(initialOwner);
    }

    /// @notice Get the address of the owner
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /// @notice Set the address of the new owner of the contract
    /// Set newOwner to address(0) to renounce any ownership.
    /// @param newOwner The address of the new owner of the contract
    function transferOwnership(address newOwner) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _transferOwnership(newOwner);
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`).
    /// Internal function without access restriction.
    function _transferOwnership(address newOwner) internal virtual {
        _revokeRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(DEFAULT_ADMIN_ROLE, newOwner);

        address oldOwner = _owner;
        _owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @notice Grants `role` to `account`.
     * If `account` had not been already granted `role`, emits a {RoleGranted} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     * - role cannot be DEFAULT_ADMIN_ROLE. Use `transferOwnership` instead.
     *
     */
    function grantRole(bytes32 role, address account) public virtual override {
        if (role == DEFAULT_ADMIN_ROLE) revert CannotGrantAdminRole();
        super.grantRole(role, account);
    }

    /**
     * @notice Revokes `role` from `account`.
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     * - role cannot be DEFAULT_ADMIN_ROLE. Use `transferOwnership` instead.
     *
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        if (role == DEFAULT_ADMIN_ROLE) revert CannotRevokeAdminRole();
        super.revokeRole(role, account);
    }

    /**
     * @notice Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account` having that `role`.
     * - role cannot be DEFAULT_ADMIN_ROLE. Use `transferOwnership` instead.
     *
     */
    function renounceRole(bytes32 role, address account) public virtual override anyRole {
        if (role == DEFAULT_ADMIN_ROLE) revert CannotRevokeAdminRole();
        super.renounceRole(role, account);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[0xc64] private __gap;
}
