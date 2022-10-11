// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/SignatureVerifier.sol";
import "../src/Marketplace.sol";
import "../test/TestERC20.sol";
import "../test/TestERC721.sol";
import "../test/TestTokenMinter.sol";

contract SignatureVerifierTest is TestTokenMinter {
    using Orders for Orders.Order;

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    struct Person {
        string name;
        address wallet;
    }

    struct Mail {
        Person from;
        Person to;
        string contents;
    }

    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 constant PERSON_TYPEHASH = keccak256("Person(string name,address wallet)");

    bytes32 constant MAIL_TYPEHASH =
        keccak256("Mail(Person from,Person to,string contents)Person(string name,address wallet)");

    bytes32 DOMAIN_SEPARATOR;

    SignatureVerifier signatureVerifier = new SignatureVerifier();

    function hashDomain(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(eip712Domain.name)),
                keccak256(bytes(eip712Domain.version)),
                eip712Domain.chainId,
                eip712Domain.verifyingContract
            )
        );
    }

    function hashPerson(Person memory person) internal pure returns (bytes32) {
        return keccak256(abi.encode(PERSON_TYPEHASH, keccak256(bytes(person.name)), person.wallet));
    }

    function hashMail(Mail memory mail) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(MAIL_TYPEHASH, hashPerson(mail.from), hashPerson(mail.to), keccak256(bytes(mail.contents)))
        );
    }

    constructor() public {
        DOMAIN_SEPARATOR = hashDomain(
            EIP712Domain({
                name: "Ether Mail",
                version: "1",
                chainId: 1,
                // verifyingContract: this
                verifyingContract: 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC
            })
        );
    }

    function verify(Mail memory mail, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        // Note: we need to use `encodePacked` here instead of `encode`.
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hashMail(mail)));
        return ecrecover(digest, v, r, s) == mail.from.wallet;
    }

    function testSignatureVerification() public returns (bool) {
        // Example signed message
        Mail memory mail = Mail({
            from: Person({name: "Alice", wallet: alice}),
            to: Person({name: "Bob", wallet: bob}),
            contents: "Hello, Bob!"
        });
        (bytes32 r, bytes32 s, uint8 v) = getSignatureComponents(DOMAIN_SEPARATOR, alicePk, hashMail(mail));

        address signer = alice;
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes32 digest = signatureVerifier._deriveEIP712Digest(DOMAIN_SEPARATOR, hashMail(mail));

        assert(verify(mail, v, r, s));
        signatureVerifier._assertValidSignature(signer, digest, signature);
        return true;
    }

    function getSignatureComponents(bytes32 domainSeparator, uint256 _pkOfSigner, bytes32 _orderHash)
        internal
        returns (bytes32, bytes32, uint8)
    {
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(_pkOfSigner, keccak256(abi.encodePacked(bytes2(0x1901), domainSeparator, _orderHash)));
        return (r, s, v);
    }
}
