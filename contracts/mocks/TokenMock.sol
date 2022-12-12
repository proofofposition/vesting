// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenMock is ERC20{
    constructor() ERC20("Proof Of Position", "POPP") {
        _mint(msg.sender, 1 * 10 ** decimals());
    }
}
