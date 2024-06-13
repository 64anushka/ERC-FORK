---
title: dApp Permission Framework (DPF)
description: Declarative permissions to minimize impact when a web dApp is compromised.
author: Justin Phu (@jqphu)
discussions-to: <URL>
status: Draft
type: Standards Track
category: Interface
created: 2024-02-12
requires: [EIP712](../EIPS/eip-712.md]
---

## Abstract

There have been many instances of official web dApps being compromised. There are a plethora of ways this can happen such as a supply chain attack, a malicious code update, DNS compromises (e.g. DNS credential compromise or BGP attack).

In this proposal, we propose a mechanism for dApps to declare what interactions they allow which will vastly reduce the efficacy of these attacks and in some situations prevent them entirely.

![[../assets/eip-xxxx/dApp_permission_framework_high_level.png]]

## Motivation

Phishing attacks in crypto are incredibly devastating as transactions are final and there is no recourse. There has been a recent surge in phishing scams whereby the official websites are compromised.

Examples of these are
- Premint - https://cryptoslate.com/nft-platform-premint-users-lose-over-400k-nfts-to-hack/
- Ledger Connect Supply Chain - https://techcrunch.com/2023/12/14/supply-chain-attack-targeting-ledger-crypto-wallet-leaves-users-hacked/
- Celar Bridge: https://www.certik.com/resources/blog/1NHvPnvZ8EUjVVs4KZ4L8h-bgp-hijacking-how-hackers-circumvent-internet-routing-security-to-tear-the

Phishing scams compromise websites trick users into thinking they're doing a normal interaction but replace it with a malicious one.

When phishing scams are able to compromise a website they fire off many different scam types to steal as many assets as possible. These interactions can be as simple as requesting to send ETH to another wallet or as complex as leveraging the OpenSea protocol to trick users to selling their NFTs for nothing.

This proposal will attempt to sandbox dApps to make it much more difficult for an attacker to extract funds from users when a dApp is compromised.

Example:
We will look at `opensea.io` and evaluate what would happen if the website was compromised.

Under typical operation `opensea.io` interacts with OpenSea Contracts (ignoring approvals for simplicity).

![[../assets/eip-xxxx/DPF_typical.png]]

When the dApp is compromised, the malicious actors starts interacting with various protocols and contracts in order to steal funds. This includes their own custom contracts.

![[../assets/eip-xxxx/DPF_compromised.png]]

With dApp Permission Framework we hope to sandbox applications preventing access to protocols not approved by OpenSea thus limiting the attack surface during a compromise.

![[../assets/eip-xxxx/DPF_compromised_but_enabled.png]]

## Specification

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119 and RFC 8174.

We will start this specification assuming DNS records are to be trusted. We'll relax this requirement at the end of the specification.

### Defining dApp Permission Framework

We take inspiration from [Sender Policy Framework](https://en.wikipedia.org/wiki/Sender_Policy_Framework).

Every domain needs to define a set of allowed `Interaction`s. This declares explicitly what methods and contract this dApp is expected to interact with.

#### Definition of an `Interaction`

`Interaction` is the combination of a `Method` and optionally `MethodDetails` separated by a comma.

`Interaction := (Method,MethodDetails)`

`Method` is a string which represents any request that requires the user to sign with their private key.

`Method := {personal_sign,eth_sign,eth_sendTransaction,eth_signTypedData}`

`MethodDetails` is optional additional information for the given `Method`.

####  For `Method in {personal_sign,eth_sign}`

`MethodDetails` is empty.

#### For `Method = eth_sendTransaction`

`MethodDetails` is the combination of `ToAddress` and `FunctionSelector` separated by an underscore.

`MethodDetails := (ChainId,ToAddress,Value,FunctionSelector)`
 when 
 `Method = eth_sendTransaction`

`ToAddress` is the `to` address sent in a transaction.
`Value` is either `0` or the wildcard `*` to represent any amount.
`ChainId` is the network for the `ToAddress`.
`FunctionSelector` is the 4 byte function selector or `0x`.

All three of these variables can be substituted for a wildcard `*` which represents all possible values.
The wildcard for `FunctionSelector` will also match empty bytes.

#### For `Method = eth_signTypedData`

`MethodDetails` is the combination of `DomainSeparator` and `TypeHash` separated by an underscore.

`MethodDetails := (DomainSeparator,TypeHash)`
when
`Method = eth_signTypedData`

`DomainSeparator` is the domain hash defined in [EIP712](https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator)
`TypeHash` is also defined in [EIP712](https://eips.ethereum.org/EIPS/eip-712#rationale-for-typehash)

Both the `DomainSeparator` and `TypeHash` have the special wildcard `*` to represent any possible domain or typehash respectively.

### Defining Valid `Interaction`s

dApps must specify a set of valid `Interaction`s expected by their dApp. This defines every action that is allowed by a user.

Here's an example of what the set of valid `Interaction`s looks like for OpenSea.
	- `(personal_sign)` to login.
	- Interactions with opensea contracts (seaport, router, etc): `(eth_sendTransaction,(<opensea contracts>,*,*))`
	- Interactions with ERC20's to approve: `(eth_sendTransaction,(*,0,0x095ea7b3))` 
	- Interactions with ERC721's to approve for all: `(eth_sendTransaction,(*,0,0xa22cb465))`
- `eth_signTypedData` to marketplace contracts to place bid's and ask's on NFTs.
		- All signatures designated for the seaport domain `(eth_signTypedData,(<seaport domain>,*)`

### Integration of dApp Permission Framework

With the dApp Permission Framework, we can define a valid set of interactions for a given dApp. We will now discuss how we can publish this set of interactions and enforce it.
#### dApp Permission Framework Records

A DPF record is a DNS TXT record that declares what `Interaction`s are allowed for this domain. It contains the DPF version as well as the root of a Merkle Patricia Trie whose leaf nodes are the set of `Interaction`'s.

e.g. `v=dpf1 7349091faab9ba9e341f298a74c898d2d76f903df4e0afdb310d750f017bcf28`

An interaction is permitted by the dApp if it is a node of the Merkle Patricia Trie whose root is specified in the DNS record.

If a DPF record is not found, the wallet should walk up the domain until it finds a DPF record or hits the root domain. That is, if `example.foo.com` does not have a DPF record we should walk up and check `foo.com`.

#### `Interaction` Merkle Patricia Trie Format

A Merkle Patricia Trie is used to allow us to efficiently verify whether an `Interaction` is allowed or not. The leaves are `Interaction` serialized as RLP bytes.

However, due to the presence of wildcards there is additional work that needs to be done as opposed to a simple lookup.

For example the method `eth_sendTransaction` there can be wildcards with the `ToAddress`, `Value` , `ChainId` and `FunctionSelector` . Thus, we need to try to match all permutations with the wildcard substituted. In the case of `eth_sendTransaction`, that's 2^4 = 16 lookups. There are more efficient datastructures that can used here but will be omitted for brevity. 

Since this is an allowlist only, there is no precedence we need to take into account. If any one of the 16 permutations is found, the transaction is allowed.

Here's a simplified diagram of the trie.

![[../assets/eip-xxxx/DPF_eth_sendTransaction_trie.png]]

If at any point a node is not found, this transaction is not allowed in the dApps Permission Framework.

> [!todo]
> Need to add limits to discuss DoS attacks
> Performance.

#### `Interaction` Merkle Patricia Tree Storage

The Merkle Patricia Tree can be stored anywhere since we will verify the root hash in the DNS.

The simplest example for storage is an open source Github repository containing the domain, root hash and nodes.

#### DNS Compromise

The entire previous specification we have assumed the DNS records are not tampered with. We will now relax that constraint and add protection from DNS compromises.

We will introduce a 72 hour time lock whereby the old DNS records are respected. This gives teams enough time to detect compromises and regain control of their records or alert users.

Let's walk through what happens when the DNS record is updated.

If the DNS record is updated, wallets are expected to respect the previous dApp Permission Framework policy. Wallets can detect a DNS record change by referencing the root hash with the latest root hash stored for this domain.

The simplest implementation would be to trust the open source Github repository. The open source Github repository will always contain the latest valid dApp Permission Framework for each domain. That is, the team who is updating their DNS records is required to create a pull request into the Github repository. However, this will not get accepted until the root hash in the pull request matches the domain and 72 hours has passed.
	
An attacker compromising the DNS record would also have to compromise the open source Github repository simultaneously in order to trick wallets. Thus, at all times there are two simultaneous attacks needed. Wallets caring about an extra layer of security can maintain mirrors this Github repository internally to ensure it hasn't been tampered with.

Note: this means, teams should update their DNS Records to add more permissions **before** updating the dApp itself.

### How it all fits together

Let's walk through the full example for `opensea.io`.

#### Developers

> [!todo]
> Fill this with exact values.

OpenSea developers define the set of valid `Interaction`s for `opensea.io`. As shown above this looks like:

`Interaction`s: {`(personal_sign)`, `(eth_sendTransaction,(<opensea contracts>,*,*))`, `(eth_sendTransaction,(*,0,0x095ea7b3))`, `(eth_sendTransaction,(*,0,0xa22cb465))`,  `(eth_signTypedData,(<seaport domain>,*)`}

They then generate a Merkle Patricia Trie resulting in the root `7349091faab9ba9e341f298a74c898d2d76f903df4e0afdb310d750f017bcf28`.

Using their DNS provider they publish this root as a TXT record:
`v=dpf1 7349091faab9ba9e341f298a74c898d2d76f903df4e0afdb310d750f017bcf28`.

Finally, they create a pull request to the github repository containing the set of `Interaction`s and the root hash.

Once 
- Root hash has been verified to be published at `opensea.io`
- 48 hours have passed since the root hash has been published at `opensea.io`
- The set of interactions is verified to have the resulting root hash

The Pull Request is approved.

#### Wallets

When wallets go on a domain, they pull the TXT records to find one prefixed with `v=dpf1`.

If one doesn't exist, they operate as normal.
If they find a record, they extract the root hash. They pull the set of `Interaction`s and attempt to match the pending transaction with the set. If one is found, they compute the path up to the root hash to confirm it matches the record found in the DNS.

If it does, they allow the transaction. If it doesn't they reject it.

Note: all of this can be done with an external service. This service can return the Merkle Patricia Trie Path which can be easily verified by the wallet.

#### During Attack

If `opensea.io` is compromised, the attacker will start requesting transactions to `Uniswap`, `Blur` through various transactions and signatures to steal funds.

Since `Uniswap` and `Blur` domains and signatures are not in the `Interaction` set, they are rejected by the wallet thus protecting users from lost funds.

## Rationale

### Declarative Sandboxing Approach

Defending against all the different attack vectors a scammer can take is difficult. However, providing a sandbox with simple allowed methods greatly reduces the attack surface with very little cost.

This takes inspiration from Sender Policy Framework whereby email servers are allowlisted. This can also been seen in mobile app manifests where access to sensitive permissions such as the camera, microphone, location etc need to be set up declaratively by the app beforehand.

### dApp Framework Policy Records

We add the prefix `v=dpf1` to define the version of the dApp Framework Policy but also to act as an identifier to distinguish it from other DNS TXT records.

We store the Merkle Patricia Tree root hash as we are limited to 255 characters in the DNS TXT record.

We explicitly do not specify where the Merkle Patricia Tree needs to be stored and leave that entirely up to the wallets. This is because this data can be easily verified it is not important where it is being stored.

### `Interaction` format

The rationale behind the `Interaction` format is to make it detailed enough to accurately describe a dApps interactions without making it overly complex.

We want to ensure the lookup time for wallets is minimal making it possible to do entirely on the client side with no user facing impacts.

### Merkle Patricia Tree

- We use this as it allows to call an external API to send a proof that can quickly be verified.

### Limitations

dApps are only going to be sandboxed. It will not prevent everything.

Fixes: Premint hack entirely, collabland.
Minimizes: Uniswap, Opensea, Blur, Sushi, etc. Still potential of compromise but greatly minimized.
Poor at defending against: questing platforms, revoke.cash, SAFE (e.g. generic platforms).

## Backwards Compatibility

Similar to Sender Policy Framework, if the dpf TXT record is not found there is no change in dApp experience.

In the future, wallets and services may choose to enforce a dpf record be present, however, that is not required in this proposal.

## Security Considerations

This in entirely opt-in and only adds additional security. The worst case scenario is an incorrect implementation would result in censoring transactions for a short amount of time.


## Copyright

Copyright and related rights waived via [CC0](../LICENSE.md).
