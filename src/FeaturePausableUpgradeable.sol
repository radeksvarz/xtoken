// SPDX-License-Identifier: MIT
// Based on OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity 0.8.19;

import {Initializable} from "@oz-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@oz-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism for the particular feature (identified by bytes32)
 * that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenFeatureNotPaused` and `whenFeaturePaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract FeaturePausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event FeaturePaused(bytes32 feature, address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event FeatureUnpaused(bytes32 feature, address account);

    error RequireFeaturePaused();

    error RequireFeatureNotPaused();

    mapping(bytes32 => bool) private _featurePaused;

    function __FeaturePausable_init() internal onlyInitializing {
        __FeaturePausable_init_unchained();
    }

    function __FeaturePausable_init_unchained() internal onlyInitializing {}

    /**
     * @dev Modifier to make a function callable only when the contract's feature is not paused.
     *
     * Requirements:
     *
     * - The contract's feature must not be paused.
     */
    modifier whenFeatureNotPaused(bytes32 feature) {
        _requireFeatureNotPaused(feature);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract's feature must be paused.
     */
    modifier whenFeaturePaused(bytes32 feature) {
        _requireFeaturePaused(feature);
        _;
    }

    /**
     * @dev Returns true if the contract's feature is paused, and false otherwise.
     */
    function featurePaused(bytes32 feature) public view virtual returns (bool) {
        return _featurePaused[feature];
    }

    /**
     * @dev Throws if the contract's feature is paused.
     */
    function _requireFeatureNotPaused(bytes32 feature) internal view virtual {
        if (featurePaused(feature)) revert RequireFeatureNotPaused();
    }

    /**
     * @dev Throws if the contract's feature is not paused.
     */
    function _requireFeaturePaused(bytes32 feature) internal view virtual {
        if (!featurePaused(feature)) revert RequireFeaturePaused();
    }

    /**
     * @dev Triggers stopped state.
     *
     * Security aspect: it is expected that this function is called by external function
     * with authorisation protection. Such as pauseMyFeature() public onlyFeaturePauseRole
     *
     * Requirements:
     *
     * - The contract's feature must not be paused.
     */
    function _pauseFeature(bytes32 feature) internal virtual whenFeatureNotPaused(feature) {
        _featurePaused[feature] = true;
        emit FeaturePaused(feature, _msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Security aspect: it is expected that this function is called by external function
     * with authorisation protection. Such as unpauseMyFeature() public onlyFeaturePauseRole
     *
     * Requirements:
     *
     * - The contract's feature must be paused.
     */
    function _unpauseFeature(bytes32 feature) internal virtual whenFeaturePaused(feature) {
        _featurePaused[feature] = false;
        emit FeatureUnpaused(feature, _msgSender());
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[0xc64] private __gap;
}
