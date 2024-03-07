// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.15;

/*------------------------------------------- DESCRIPTION ---------------------------------------------------------------------------------------*/

/**
 * @title ERC-7573 Decryption Contract - Conditional decryption of keys, conditional to transfer success.
 * @dev Interface specification for a smart contract that enables secure stateless delivery-versus-payment.
 *
 * The specification consists of two interface,
 * one is implemented by a smart contract on one chain (e.g. the "asset chain" - the asset contract), the other is implemented by
 * a smart contract on another chain (e.g. the "payment chain" - the payment contract).
 * One contract performs a locking, where a transfer is conditional on a presented key: locking contract.
 * The other contract performs a condition decryption of keys, conditional to transfer success of failure: decryption contract.
 *
 * This is the decryption contracts interface.
 *
 * The rationale is that a transfer in setup with two encrypted keys, the encryptedSuccessKey and the encryptedFailureKey.
 * Upon transfer a conditional decryption of one the encrypted keys is performed.
 */
interface IDecryptionContract {

    /*------------------------------------------- EVENTS ---------------------------------------------------------------------------------------*/

    /**
     * @dev Emitted  when the transfer for the is incepted.
     * @param initiator is the address from which the transfer was incepted
     * @param id the trade ID.
     * @param amount to be transfered.
     */
    event PaymentTransferIncepted(address initiator, uint id, int amount);

    /**
     * @dev Emitted when a the transfer has been performed with a success or failure.
     * @param id the trade ID.
     * @param encryptedKey The encrypted key associated with the transaction status.
     */
    event TransferKeyRequested(uint id, string encryptedKey);

    /**
     * @dev Emitted when the decrypted key has been obtained.
     * @param id the trade ID.
     * @param success a boolean indicating the status. True: success. False: failure.
     * @param key the descrypted key.
     */
    event TransferKeyReleased(uint id, bool success, string key);

    /*------------------------------------------- FUNCTIONALITY ---------------------------------------------------------------------------------------*/

    /**
     * @notice Called from the receiver of the amount to initiate payment transfer.
     * @dev emits a {PaymentTransferIncepted}
     * @param id the trade identifier of the trade.
     * @param amount the amount to be transfered.
     * @param from The address of the sender of the payment (the receiver ('to') is message.sender).
     * @param keyEncryptedSuccess Encryption of the key that is emitted upon success.
     * @param keyEncryptedFailure Encryption of the key that is emitted upon failure.
     */
    function inceptTransfer(uint id, int amount, address from, string memory keyEncryptedSuccess, string memory keyEncryptedFailure) external;

    /**
     * @notice Called from the sender of the amount to initiate completion of the payment transfer.
     * @dev emits a {TransferKeyRequested} and {TransferKeyReleased} with keys depending on completion success.
     * @param id the trade identifier of the trade.
     * @param from The address of the sender of the payment.
     * @param to The address of the receiver of the payment.
     * @param keyEncryptedSuccess Encryption of the key that is emitted upon success.
     * @param keyEncryptedFailure Encryption of the key that is emitted upon failure.
     */
    function transferAndDecrypt(uint id, address from, address to, string memory keyEncryptedSuccess, string memory keyEncryptedFailure) external;

    /**
     * @notice Called from the payer of the payment to cancel payment transfer.
     * @dev emits a {TransferKeyRequested} and {TransferKeyReleased}
     * @param id the trade identifier of the trade.
     * @param from The address of the sender of the payment.
     * @param to The address of the receiver of the payment.
     * @param keyEncryptedSuccess Encryption of the key that is emitted upon success.
     * @param keyEncryptedFailure Encryption of the key that is emitted upon failure.
     */
    function cancelAndDecrypt(uint id, address from, address to, string memory keyEncryptedSuccess, string memory keyEncryptedFailure) external;
}