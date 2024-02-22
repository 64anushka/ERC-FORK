---
eip: XXXX
title: Limited Transferrable NFT
description: An ERC-721 extension to limit transferability based on counts among NFTs
author: Qin Wang (@qinwang-git), Saber Yu (@OniReimu), Shiping Chen <shiping.chen@data61.csiro.au>
discussions-to: https://ethereum-magicians.org/t/eip-xxx-limited-transferable-nft/18861
status: Draft
type: Standards Track
category: ERC
created: 2024-02-22
requires: 165, 721
---

## Abstract

This standard extends [ERC-721](./eip-721.md) to allow minters to customize the transferability of NFTs by setting parameters via TransferCount. The standard introduces an interface with internal functions to facilitate this functionality.


## Motivation

Current NFTs, once sold, sever ties with their minters and can be transferred infinitely upon subsequent sales. However, various scenarios necessitate precise control over NFT issuance. For instance, an NFT may need to be limited in its number of bids to maintain its value, or a patent may only be sold a certain number of times before being released for free. Imposing restrictions on the number of times an NFT can be sold or traded becomes crucial.

## Specification

The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, “RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be interpreted as described in RFC 2119.

- `setTransferLimit`: a function establishes the transfer limit for a tokenId.
- `transferLimitOf`: a function retrieves the transfer limit for a tokenId.
- `transferCountOf`: a function returns the current transfer count for a tokenId.
- `_incrementTransferCount`: an internal function facilitates incrementing the transfer count.
- `_beforeTokenTransfer`: an overrided function defines the state before transfer.
- `_afterTokenTransfe`: an overrided function outlines the state after transfer.

Implementers of this standard **MUST** have all of the following functions:

```solidity

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title IERCXXXX Interface for Limited Transferable NFT
/// @dev Interface for ERCXXXX Limited Transferable NFT extension for ERC721
/// @author Saber Yu

interface IERCXXXX is IERC721 {

    /**
     * @dev Emitted when transfer count is set or updated
     */
    event TransferCount(uint256 indexed tokenId, address owner, uint256 counts);

    /**
     * @dev Returns the current transfer count for a tokenId
     */
    function transferCountOf(uint256 tokenId) external view returns (uint256);

    /**
     * @dev Sets the transfer limit for a tokenId. Can only be called by the token owner or an approved address.
     * @param tokenId The ID of the token for which to set the limit
     * @param limit The maximum number of transfers allowed for the token
     */
    function setTransferLimit(uint256 tokenId, uint256 limit) external;

    /**
     * @dev Returns the transfer limit for a tokenId
     */
    function transferLimitOf(uint256 tokenId) external view returns (uint256);
}
    
```

## Rationale

*Controlled Value Preservation*: By allowing minters to set customized transfer limits for NFTs, this standard facilitates the preservation of value for digital assets. Just as physical collectibles often gain or maintain value due to scarcity, limiting the number of transfers for an NFT can help ensure its continued value over time.

*Ensuring Intended Usage*: Setting transfer limits can ensure that NFTs are used in ways that align with their intended purpose. For example, if an NFT represents a limited-edition digital artwork, limiting transfers can prevent it from being excessively traded and potentially devalued.

*Expanding Use Cases*: These enhancements broaden the potential applications of NFTs by offering more control and flexibility to creators and owners. For instance, NFTs could be used to represent memberships or licenses with limited transferability, opening up new possibilities for digital ownership models.


## Backwards Compatibility

This standard can be fully [ERC-721](./eip-721.md) compatible by adding an extension function set.

## Extensions

This standard can be enhanced with additional advanced functionalities alongside existing NFT protocols. For example:

(i) Incorporating a burn function (e.g., [ERC-5679](./eip-5679.md)) would enable NFTs to automatically expire after reaching their transfer limits, akin to the ephemeral nature of Snapchat messages that disappear after multiple views.

(ii) Incorporating a non-transferring function, as defined in the SBT standards, would enable NFTs to settle and bond with a single owner after a predetermined number of transactions. This functionality mirrors the scenario where a bidder ultimately secures a treasury after participating in multiple bidding rounds.


## Reference Implementation

```solidity

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IERCXXXX.sol";

/// @title Limited Transferable NFT Extension for ERC721
/// @dev Implementation of the Limited Transferable NFT extension for ERC721
/// @author Saber Yu

contract ERCXXXX is ERC721, IERCXXXX {

    // Mapping from tokenId to the transfer count
    mapping(uint256 => uint256) private _transferCounts;

    // Mapping from tokenId to its maximum transfer limit
    mapping(uint256 => uint256) private _transferLimits;

    /**
     * @dev See {IERCXXXX-transferCountOf}.
     */
    function transferCountOf(uint256 tokenId) public view override returns (uint256) {
        require(_exists(tokenId), "ERCXXXX: Nonexistent token");
        return _transferCounts[tokenId];
    }

    /**
     * @dev See {IERCXXXX-setTransferLimit}.
     */
    function setTransferLimit(uint256 tokenId, uint256 limit) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERCXXXX: caller is not owner nor approved");
        _transferLimits[tokenId] = limit;
    }

    /**
     * @dev See {IERCXXXX-transferLimitOf}.
     */
    function transferLimitOf(uint256 tokenId) public view override returns (uint256) {
        require(_exists(tokenId), "ERCXXXX: Nonexistent token");
        return _transferLimits[tokenId];
    }

    /**
     * @dev Internal function to increment transfer count.
     */
    function _incrementTransferCount(uint256 tokenId) internal {
        _transferCounts[tokenId] += 1;
        emit TransferCount(tokenId, ownerOf(tokenId), _transferCounts[tokenId]);
    }

    /**
     * @dev Override {_beforeTokenTransfer} to enforce transfer limit.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        require(_transferCounts[tokenId] < _transferLimits[tokenId], "ERCXXXX: Transfer limit reached");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Override {_afterTokenTransfer} to handle post-transfer logic.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 quantity
    ) internal virtual override {
        _incrementTransferCount(tokenId);

        if (_transferCounts[tokenId] == _transferLimits[tokenId]) {
            // Optional post-transfer operations once the limit is reached
            // Uncomment the following based on the desired behavior such as the `burn` opearation
            // ---------------------------------------
            // _burn(tokenId); // Burn the token
            // ---------------------------------------
        }

        super._afterTokenTransfer(from, to, tokenId, quantity);
    }


    /**
     * @dev Override {supportsInterface} to declare support for IERCXXXX.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERCXXXX).interfaceId || super.supportsInterface(interfaceId);
    }
}

```

## Security Considerations

- Ensure that each NFT minter can call this function to set transfer limits.
- Consider making transfer limits immutable once set to prevent tampering or unauthorized modifications.
- Avoid performing resource-intensive operations when integration with advanced functions that could exceed the gas limit during execution.


## Copyright

Copyright and related rights waived via [CC0](../LICENSE.md).