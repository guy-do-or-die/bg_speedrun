// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MyUSD.sol";
import "./Oracle.sol";
import "./MyUSDStaking.sol";

error Engine__InvalidAmount();
error Engine__UnsafePositionRatio();
error Engine__NotLiquidatable();
error Engine__InvalidBorrowRate();
error Engine__NotRateController();
error Engine__InsufficientCollateral();
error Engine__TransferFailed();

contract MyUSDEngine is Ownable {
    uint256 private constant COLLATERAL_RATIO = 150; // 150% collateralization required
    uint256 private constant LIQUIDATOR_REWARD = 10; // 10% reward for liquidators
    uint256 private constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant PRECISION = 1e18;

    MyUSD private i_myUSD;
    Oracle private i_oracle;
    MyUSDStaking private i_staking;
    address private i_rateController;

    uint256 public borrowRate; // Annual interest rate for borrowers in basis points (1% = 100)

    // Total debt shares in the pool
    uint256 public totalDebtShares;

    // Exchange rate between debt shares and MyUSD (1e18 precision)
    uint256 public debtExchangeRate;
    uint256 public lastUpdateTime;

    mapping(address => uint256) public s_userCollateral;
    mapping(address => uint256) public s_userDebtShares;

    event CollateralAdded(address indexed user, uint256 indexed amount, uint256 price);
    event CollateralWithdrawn(address indexed withdrawer, uint256 indexed amount, uint256 price);
    event BorrowRateUpdated(uint256 newRate);
    event DebtSharesMinted(address indexed user, uint256 amount, uint256 shares);
    event DebtSharesBurned(address indexed user, uint256 amount, uint256 shares);
    event Liquidation(
        address indexed user,
        address indexed liquidator,
        uint256 amountForLiquidator,
        uint256 liquidatedUserDebt,
        uint256 price
    );

    modifier onlyRateController() {
        if (msg.sender != i_rateController) revert Engine__NotRateController();
        _;
    }

    constructor(
        address _oracle,
        address _myUSDAddress,
        address _stakingAddress,
        address _rateController
    ) Ownable(msg.sender) {
        i_oracle = Oracle(_oracle);
        i_myUSD = MyUSD(_myUSDAddress);
        i_staking = MyUSDStaking(_stakingAddress);
        i_rateController = _rateController;
        lastUpdateTime = block.timestamp;
        debtExchangeRate = PRECISION; // 1:1 initially
    }

    // Checkpoint 2: Depositing Collateral & Understanding Value
    function addCollateral() public payable {
        if (msg.value == 0) revert Engine__InvalidAmount();
        s_userCollateral[msg.sender] += msg.value;
        emit CollateralAdded(msg.sender, msg.value, i_oracle.getETHMyUSDPrice());
    }

    function calculateCollateralValue(address user) public view returns (uint256) {
        uint256 collateralAmount = s_userCollateral[user];
        if (collateralAmount == 0) return 0;
        return (collateralAmount * i_oracle.getETHMyUSDPrice()) / PRECISION;
    }

    // Checkpoint 3: Interest Calculation System
    function _getCurrentExchangeRate() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        uint256 standardInterest = (borrowRate * timeElapsed * debtExchangeRate) / (SECONDS_PER_YEAR * 10000);
        return debtExchangeRate + standardInterest;
    }

    function _accrueInterest() internal {
        debtExchangeRate = _getCurrentExchangeRate();
        lastUpdateTime = block.timestamp;
    }

    function _getMyUSDToShares(uint256 amount) internal view returns (uint256) {
        uint256 currentExchangeRate = _getCurrentExchangeRate();
        return (amount * PRECISION) / currentExchangeRate;
    }

    // Checkpoint 4: Minting MyUSD & Position Health
    function getCurrentDebtValue(address user) public view returns (uint256) {
        if (s_userDebtShares[user] == 0) return 0;
        uint256 currentExchangeRate = _getCurrentExchangeRate();
        return (s_userDebtShares[user] * currentExchangeRate) / PRECISION;
    }

    function calculatePositionRatio(address user) public view returns (uint256) {
        uint256 debtValue = getCurrentDebtValue(user);
        if (debtValue == 0) return type(uint256).max;
        uint256 collateralValue = calculateCollateralValue(user);
        return (collateralValue * PRECISION) / debtValue;
    }

    function _validatePosition(address user) internal view {
        uint256 ratio = calculatePositionRatio(user);
        if (ratio == type(uint256).max) return;
        if ((ratio * 100) < COLLATERAL_RATIO * PRECISION) revert Engine__UnsafePositionRatio();
    }

    function mintMyUSD(uint256 mintAmount) public {
        if (mintAmount == 0) revert Engine__InvalidAmount();
        _accrueInterest();
        uint256 sharesToMint = _getMyUSDToShares(mintAmount);
        s_userDebtShares[msg.sender] += sharesToMint;
        totalDebtShares += sharesToMint;
        i_myUSD.mintTo(msg.sender, mintAmount);
        _validatePosition(msg.sender);
        emit DebtSharesMinted(msg.sender, mintAmount, sharesToMint);
    }

    // Checkpoint 5: Accruing Interest & Managing Borrow Rates
    function setBorrowRate(uint256 newRate) external onlyRateController {
        if (newRate < i_staking.savingsRate()) revert Engine__InvalidBorrowRate();
        _accrueInterest();
        borrowRate = newRate;
        emit BorrowRateUpdated(newRate);
    }

    // Checkpoint 6: Repaying Debt & Withdrawing Collateral
    function repayUpTo(uint256 amount) public {
        _accrueInterest();
        uint256 amountInShares = _getMyUSDToShares(amount);
        if (amountInShares > s_userDebtShares[msg.sender]) {
            amountInShares = s_userDebtShares[msg.sender];
            amount = getCurrentDebtValue(msg.sender);
        }
        
        if (amount == 0) revert Engine__InvalidAmount();
        if (i_myUSD.balanceOf(msg.sender) < amount) revert MyUSD__InsufficientBalance();
        if (i_myUSD.allowance(msg.sender, address(this)) < amount) revert MyUSD__InsufficientAllowance();

        s_userDebtShares[msg.sender] -= amountInShares;
        totalDebtShares -= amountInShares;
        
        i_myUSD.burnFrom(msg.sender, amount);
        emit DebtSharesBurned(msg.sender, amount, amountInShares);
    }

    function withdrawCollateral(uint256 amount) external {
        if (amount == 0) revert Engine__InvalidAmount();
        _accrueInterest();
        
        if (s_userCollateral[msg.sender] < amount) revert Engine__InsufficientCollateral();
        
        s_userCollateral[msg.sender] -= amount;
        _validatePosition(msg.sender);
        
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert Engine__TransferFailed();
        
        emit CollateralWithdrawn(msg.sender, amount, i_oracle.getETHMyUSDPrice());
    }

    // Checkpoint 7: Liquidation - Enforcing System Stability
    function isLiquidatable(address user) public view returns (bool) {
        uint256 ratio = calculatePositionRatio(user);
        return (ratio * 100) < COLLATERAL_RATIO * PRECISION;
    }

    function liquidate(address user) external {
        if (!isLiquidatable(user)) revert Engine__NotLiquidatable();
        
        _accrueInterest();
        
        uint256 userDebtValue = getCurrentDebtValue(user);
        uint256 userCollateral = s_userCollateral[user];
        // uint256 collateralValue = calculateCollateralValue(user);
        
        // This is the amount of ETH collateral that has the same USD value as the debt
        uint256 collateralToCoverDebt = (userDebtValue * PRECISION) / i_oracle.getETHMyUSDPrice();
        uint256 bonus = (collateralToCoverDebt * LIQUIDATOR_REWARD) / 100;
        uint256 totalCollateralToTake = collateralToCoverDebt + bonus;
        
        if (totalCollateralToTake > userCollateral) {
            totalCollateralToTake = userCollateral;
        }
        
        if (i_myUSD.balanceOf(msg.sender) < userDebtValue) revert MyUSD__InsufficientBalance();
        if (i_myUSD.allowance(msg.sender, address(this)) < userDebtValue) revert MyUSD__InsufficientAllowance();

        // Burn debt
        i_myUSD.burnFrom(msg.sender, userDebtValue);
        
        // Clear user debt
        uint256 debtShares = s_userDebtShares[user];
        s_userDebtShares[user] = 0;
        totalDebtShares -= debtShares;
        
        s_userCollateral[user] -= totalCollateralToTake;
        
        (bool success, ) = msg.sender.call{value: totalCollateralToTake}("");
        if (!success) revert Engine__TransferFailed();
        
        emit Liquidation(user, msg.sender, totalCollateralToTake, userDebtValue, i_oracle.getETHMyUSDPrice());
    }
}
