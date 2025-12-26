// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Verifier.sol";

contract MockVerifier is IVerifier {
    function verify(bytes calldata /* _proof */, bytes32[] calldata /* _publicInputs */) external pure override returns (bool) {
        return true;
    }
}
