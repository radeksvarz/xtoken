// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC3156FlashBorrowerUpgradeable} from "@oz-upgradeable/interfaces/IERC3156FlashBorrowerUpgradeable.sol";
import {ERC20FlashMintUpgradeable} from "@oz-upgradeable/token/ERC20/extensions/ERC20FlashMintUpgradeable.sol";

/**
 * @title FlashMintUpgradeable
 * @dev An abstract contract that extends ERC20FlashMintUpgradeable and provides functionality for flash minting.
 *
 * Flash minting allows temporary borrowing of tokens within a single transaction. This contract manages the flash mint fee,
 * sets a maximum flash minting ceiling, and specifies the receiver of the flash mint fee.
 *
 * There is the managed maximum amount as observed by `maxFlashLoan` with `_FLASHMINTHARDCAP` capped to
 * uint256 max / 10000 bps / 2 to avoid overflow errors. Soft cap is managed via `flashMintCeiling`.
 * _FLASHMINTHARDCAP also avoids unlimited allowance for `flashMintFeeReceiver`.
 *
 * Flash minting fee is represented in basis points (bps), where 1 bases point (bps) is equal to 0.01%.
 * Maximum fee rate is 10000 bps which results in the same amount as a principal.
 * The fee is deducted from the borrowed amount and transferred to the flash mint fee receiver.
 *
 * To enable flash minting, the borrower must call the flashLoan function and implement the IERC3156FlashBorrowerUpgradeable
 * interface. The _beforeFlashMint hook can be used to validate contract or receiver state conditions before the flash minting occurs.
 *
 * This contract is intended to be inherited by token contract that requires flash minting functionality.
 */
abstract contract FlashMintUpgradeable is ERC20FlashMintUpgradeable {
    // To avoid arithmetic overflow and save gas on calculations and unlimited allowance
    uint256 private constant _FLASHMINTHARDCAP = type(uint256).max / 20000;

    uint256 public flashMintCeiling;

    address public flashMintFeeReceiver;

    /// @notice 1 == 1 bps = 0.01 % = 0.0001, min 0, max 10000 bps.
    uint16 public flashMintFeeBps;

    event FlashMintFeeUpdated(uint16 oldFee, uint16 newFee);

    event FlashMintCeilingUpdated(uint256 oldCeiling, uint256 newCeiling);

    event FlashMintFeeReceiverUpdated(address oldReceiver, address newReceiver);

    error CannotSetFeeOver10000bpsLimit();

    // solhint-disable-next-line func-name-mixedcase
    function __FlashMint_init(
        uint16 defaultFlashMintFeeBps,
        uint256 defaultFlashMintCeiling,
        address defaultFlashMintFeeReceiver
    ) internal virtual onlyInitializing {
        super.__ERC20FlashMint_init();
        __FlashMint_init_unchained(defaultFlashMintFeeBps, defaultFlashMintCeiling, defaultFlashMintFeeReceiver);
    }

    // solhint-disable-next-line func-name-mixedcase
    function __FlashMint_init_unchained(
        uint16 defaultFlashMintFeeBps,
        uint256 defaultFlashMintCeiling,
        address defaultFlashMintFeeReceiver
    ) internal virtual onlyInitializing {
        _setFlashMintFeeBps(defaultFlashMintFeeBps);
        _setFlashMintCeiling(defaultFlashMintCeiling);
        _setFlashMintFeeReceiver(defaultFlashMintFeeReceiver);
    }

    /// @notice Sets new `flashMintCeiling` that caps flashmint volume
    /// New Ceiling is always less than or equal to _FLASHMINTHARDCAP
    /// @dev Emits `FlashMintCeilingUpdated`
    /// Event is emited at the beginning in order to log old value
    /// To be called by a public function having authorisation validation
    function _setFlashMintCeiling(uint256 newCeiling) internal virtual {
        if (newCeiling > _FLASHMINTHARDCAP) newCeiling = _FLASHMINTHARDCAP;
        emit FlashMintCeilingUpdated(flashMintCeiling, newCeiling);
        flashMintCeiling = newCeiling;
    }

    /// @notice Sets new `flashMintFeeBps` with max 10000 bps
    /// @dev Emits `FlashMintFeeUpdated`
    /// Event is emited at the beginning in order to log old value
    /// To be called by a public function having authorisation validation
    function _setFlashMintFeeBps(uint16 newFee) internal virtual {
        if (newFee > 10000) revert CannotSetFeeOver10000bpsLimit();

        emit FlashMintFeeUpdated(flashMintFeeBps, newFee);
        flashMintFeeBps = uint16(newFee);
    }

    /// @notice Sets new `flashMintFeeReceiver` the receiver address of the flash fee.
    /// @dev Emits `FlashMintFeeReceiverUpdated`
    /// @dev Event is emited at the beginning in order to log old value
    /// To be called by a public function having authorisation validation
    function _setFlashMintFeeReceiver(address newReceiver) internal virtual {
        emit FlashMintFeeReceiverUpdated(flashMintFeeReceiver, newReceiver);
        flashMintFeeReceiver = newReceiver;
    }

    /// @dev `_flashFeeReceiver` is the implemented hook for OZ `flashLoan()`
    function _flashFeeReceiver() internal view virtual override returns (address) {
        return flashMintFeeReceiver;
    }

    /// @dev `_flashFee` business logic override of the OZ `_flashFee()` used in the OZ `flashFee()`
    /// Amount considered for the fee calculation is capped to uint max / 10000 bps / 2 to avoid overflow errors
    /// The `flashMintCeiling` is not reflected as that could change in between transactions
    function _flashFee(address token, uint256 amount) internal view virtual override returns (uint256) {
        // silence warning about unused variable without the addition of bytecode.
        token;
        uint256 cappedAmount = amount > _FLASHMINTHARDCAP ? _FLASHMINTHARDCAP : amount;
        // Does not overflow as the max flashMintFeeBps = 1_00_00
        return (cappedAmount * uint256(flashMintFeeBps)) / 10000;
    }

    /// @notice Returns the maximum amount of tokens available for loan.
    /// maxFloashLoan is always less than or equal to unsupplied amount, flashMintCeiling and thus _FLASHMINTHARDCAP
    /// @dev Business logic override of the OZ `maxFlashLoan()` to reflect the managed ceiling
    function maxFlashLoan(address token) public view virtual override returns (uint256) {
        if (token != address(this)) return 0;

        uint256 _maxFlashLoan = type(uint256).max - totalSupply();
        if (_maxFlashLoan > flashMintCeiling) _maxFlashLoan = flashMintCeiling;

        return _maxFlashLoan;
    }

    /// @notice Performs a flash loan. New tokens are minted temporatily, sent to the `receiver` and expected to be returned within 1 transaction
    /// @dev `receiver` is required to implement the {IERC3156FlashBorrower} interface
    /// This is override of the OZ flashLoan() function inserting `_beforeFlashMint` hook for validation on contract's or receiver's state conditions
    function flashLoan(
        IERC3156FlashBorrowerUpgradeable receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) public virtual override returns (bool) {
        _beforeFlashMint(address(receiver), amount);
        return super.flashLoan(receiver, token, amount, data);
    }

    /// @dev Hook that is called before flash minting.
    function _beforeFlashMint(address borrower, uint256 amount) internal virtual {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[0xc64] private __gap;
}
