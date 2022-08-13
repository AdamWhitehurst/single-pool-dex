// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IDEX.sol";

/**
 * @title DEX Template
 * @author stevepham.eth and m00npapi.eth
 * @notice Empty DEX.sol that just outlines what features could be part of the challenge (up to you!)
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 * NOTE: functions outlined here are what work with the front end of this branch/repo. Also return variable names that may need to be specified exactly may be referenced (if you are confused, see solutions folder in this repo and/or cross reference with front-end code).
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    using SafeMath for uint256; //outlines use of SafeMath for uint256 variables
    IERC20 token; //instantiates the imported contract
    
    uint256 public totalLiquidity;
    mapping (address => uint256) public liquidity;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap(address, string, uint256, uint256);

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap(address, string, uint256, uint256);

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided(address, uint256, uint256, uint256);

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved(address, uint256, uint256, uint256);

    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) {
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256) {
      require(totalLiquidity == 0, "DEX already initialized");
      totalLiquidity = address(this).balance;
      require(token.transferFrom(msg.sender, address(this), tokens), "DEX transfer failed");
      liquidity[msg.sender] = totalLiquidity;
      return totalLiquidity;
    }

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     * @dev Follow along with the [original tutorial](https://medium.com/@austin_48503/%EF%B8%8F-minimum-viable-exchange-d84f30bd0c90) Price section for an understanding of the DEX's pricing model and for a price function to add to your contract. You may need to update the Solidity syntax (e.g. use + instead of .add, * instead of .mul, etc). Deploy when you are done.
     */
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure  returns (uint256 yOutput) {
      // calculate reserves of tokens
      uint256 y = yReserves;
      uint256 x = xReserves.mul(1000);
      // calculate changes
      uint256 dx = xInput.mul(997);
      uint256 dy = dx.mul(y) / x.add(dx);
      return dy;
    }

    /**
     * @notice returns liquidity for a user. Note this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
     * if you are using a mapping liquidity, then you can use `return liquidity[lp]` to get the liquidity for a user.
     *
     */
    function getLiquidity(address lp) public view returns (uint256) {
      return liquidity[lp];
    }

    /**
     * @notice sends Ether to DEX in exchange for $BAL
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
      require(msg.value > 0, "DEX - Must send ETH");
      uint256 ethReserve = address(this).balance.sub(msg.value);
      uint256 tokenAmount = price(msg.value, ethReserve, token.balanceOf(address(this)));
      require(token.transfer(msg.sender, tokenAmount), "DEX - Transfer rejected");
      emit EthToTokenSwap(msg.sender, "ETH to BAL", msg.value, tokenAmount);
      return tokenAmount;
    }

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether
     */
    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
      require(tokenInput > 0, "DEX - Must provide nonzero amount of BAl");
      uint256 balReserve = token.balanceOf(address(this));
      uint256 ethAmount = price(tokenInput, balReserve, address(this).balance);
      require(token.transferFrom(msg.sender, address(this), tokenInput), "DEX - reverted token swap");
       (bool s,) = msg.sender.call{ value: ethAmount }("");
      require(s, "DEX - Transfer rejected ");
      emit TokenToEthSwap(msg.sender, "BAL to ETH", tokenInput, ethAmount);
      return ethAmount;
    }

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool. Takes an amount of ETH and
     * a proportional amount of BAL tokens from caller.
     */
    function deposit() public payable returns (uint256) {
      // Calculate how much BAL to take based on how much ETH was sent

      // Subtract amount that just got added
      uint256 ethReserve = address(this).balance.sub(msg.value);

      uint256 balReserve = token.balanceOf(address(this));
      uint256 balAmount = (msg.value.mul(balReserve) / ethReserve).add(1);
      uint256 liquidityMinted = msg.value.mul(totalLiquidity) / ethReserve;

      liquidity[msg.sender] = liquidity[msg.sender].add(liquidityMinted);
      totalLiquidity = totalLiquidity.add(liquidityMinted);
      
      require(token.transferFrom(msg.sender, address(this), balAmount));
      
      emit LiquidityProvided(msg.sender, liquidityMinted, msg.value, balAmount);
      return liquidityMinted;
    }
//
    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
     */
    function withdraw(uint256 amount) public returns (uint256, uint256) {
      uint256 balReserve = token.balanceOf(address(this));
      uint256 ethAmount = amount.mul(address(this).balance) / totalLiquidity;
      uint256 balAmount = amount.mul(balReserve) / totalLiquidity;
  
      liquidity[msg.sender] = liquidity[msg.sender].sub(ethAmount);
      totalLiquidity = totalLiquidity.sub(ethAmount);
  
      payable(msg.sender).transfer(ethAmount);
      require(token.transfer(msg.sender, balAmount));
  
      emit LiquidityRemoved(msg.sender, ethAmount, ethAmount, balAmount);
      return (ethAmount, balAmount);
    }
}
