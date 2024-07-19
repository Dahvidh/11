// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract RegaliumToken is ERC20 {
    AggregatorV3Interface internal maticPriceFeed;
    AggregatorV3Interface internal wethPriceFeed;
    uint256 public constant TOTAL_SUPPLY = 50000000 * 10 ** 18;

    constructor(
        address _maticPriceFeedAddress,
        address _wethPriceFeedAddress
    ) ERC20("Regalium", "RGLM") {
        _mint(msg.sender, TOTAL_SUPPLY);
        maticPriceFeed = AggregatorV3Interface(_maticPriceFeedAddress);
        wethPriceFeed = AggregatorV3Interface(_wethPriceFeedAddress);
    }

    function getLatestPrice(AggregatorV3Interface priceFeed) internal view returns (int) {
        (
            , // roundID
            int price,
            , // startedAt
            , // timeStamp
            // answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }

    function getRegaliumValue() public view returns (int) {
        int maticPrice = getLatestPrice(maticPriceFeed);
        int wethPrice = getLatestPrice(wethPriceFeed);

        // Assuming equal weightage for simplicity
        int regaliumValue = (maticPrice + wethPrice) / 2;

        return regaliumValue;
    }
}
