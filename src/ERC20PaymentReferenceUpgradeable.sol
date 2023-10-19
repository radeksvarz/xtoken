// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20Upgradeable} from "@oz-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Initializable} from "@oz-upgradeable/proxy/utils/Initializable.sol";

interface IERC20PaymentReferenceUpgradeable {
    /**
     * @notice Moves `amount` tokens from the caller's account to `to` with `paymentReference`.
     *
     * @dev Returns a boolean value indicating whether the operation succeeded.
     *
     * MUST emit a {Transfer} (to comply with ERC20) and a {TransferWithReference} event.
     */
    function transfer(address to, uint256 amount, bytes32 paymentReference) external returns (bool);

    /**
     * @notice Moves `amount` tokens from `from` to `to` with `paymentReference` using the
     * allowance mechanism. `amount` is then deducted from the caller's allowance.
     *
     * @dev Returns a boolean value indicating whether the operation succeeded.
     *
     * MUST emit a {Transfer} event (to comply with ERC20) and a {TransferWithReference} event.
     */
    function transferFrom(address from, address to, uint256 amount, bytes32 paymentReference) external returns (bool);

    /**
     * @dev Emitted when `amount` tokens are moved from one account (`from`) to
     * another (`to`) with reference (`paymentReference`).
     *
     * Note that `amount` may be zero.
     */
    event TransferWithReference(
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes32 indexed paymentReference
    );
}

/**
 * @dev Implementation of the ERC20 payment reference extension.
 *
 */
abstract contract ERC20PaymentReferenceUpgradeable is
    Initializable,
    ERC20Upgradeable,
    IERC20PaymentReferenceUpgradeable
{
    function __ERC20PaymentReference_init() internal onlyInitializing {
        __ERC20PaymentReference_init_unchained();
    }

    function __ERC20PaymentReference_init_unchained() internal onlyInitializing {}

    function transfer(address to, uint256 amount, bytes32 paymentReference) public virtual returns (bool) {
        emit TransferWithReference(_msgSender(), to, amount, paymentReference);
        return transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount,
        bytes32 paymentReference
    ) public virtual returns (bool) {
        emit TransferWithReference(from, to, amount, paymentReference);
        return transferFrom(from, to, amount);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[0xc64] private __gap;
}
