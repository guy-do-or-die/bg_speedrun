pragma solidity 0.8.20; //Do not change the solidity version as it negatively impacts submission grading
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "./YourToken.sol";

contract Vendor is Ownable {
    event BuyTokens(address buyer, uint256 amountOfETH, uint256 amountOfTokens);
    event SellTokens(address seller, uint256 amountOfTokens, uint256 amountOfETH);

    YourToken public yourToken;
    uint256 public constant tokensPerEth = 100;

    constructor(address tokenAddress) Ownable(msg.sender) {
        yourToken = YourToken(tokenAddress);
    }

    // ToDo: create a payable buyTokens() function:
    function buyTokens() public payable {
        require(msg.value > 0, "Send ETH to buy tokens");
        uint256 amountToBuy = msg.value * tokensPerEth;
        uint256 vendorBalance = yourToken.balanceOf(address(this));
        require(vendorBalance >= amountToBuy, "Vendor has insufficient tokens");
        (bool sent) = yourToken.transfer(msg.sender, amountToBuy);
        require(sent, "Failed to transfer tokens");
        emit BuyTokens(msg.sender, msg.value, amountToBuy);
    }

    // ToDo: create a withdraw() function that lets the owner withdraw ETH
    function withdraw() public onlyOwner {
        uint256 ownerBalance = address(this).balance;
        require(ownerBalance > 0, "Owner has not balance to withdraw");
        (bool sent,) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Failed to send user balance back to the owner");
    }

    // ToDo: create a sellTokens(uint256 _amount) function:
    function sellTokens(uint256 _amount) public {
        require(_amount > 0, "Specify an amount of token greater than zero");
        uint256 userBalance = yourToken.balanceOf(msg.sender);
        require(userBalance >= _amount, "Your balance is lower than the amount of tokens you want to sell");
        uint256 amountOfETHToTransfer = _amount / tokensPerEth;
        uint256 ownerETHBalance = address(this).balance;
        require(ownerETHBalance >= amountOfETHToTransfer, "Vendor has insufficient funds");
        (bool sent) = yourToken.transferFrom(msg.sender, address(this), _amount);
        require(sent, "Failed to transfer tokens from user to vendor");
        (sent,) = msg.sender.call{value: amountOfETHToTransfer}("");
        require(sent, "Failed to send ETH to the user");
        emit SellTokens(msg.sender, _amount, amountOfETHToTransfer);
    }
}
