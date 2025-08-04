// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import { IV3Factory } from "../interfaces/IV3Factory.sol";
import { OracleLibrary } from "./OracleLibrary.sol";
import { LowGasSafeMath } from "./LowGasSafeMath.sol";

interface IERC20Decimals {
  function decimals() external view returns (uint8);
}

library V3OracleHelper {
  using LowGasSafeMath for uint256;

  IV3Factory internal constant V3Factory = IV3Factory(0xbF6Bcbe2be545135391777F3B4698be92E2EB8cA);
  address internal constant WETH = 0x138DAFbDA0CCB3d8E39C19edb0510Fc31b7C1c77;
  uint256 internal constant RATIO_DIVIDER = 1e18;

  /**
   * @notice This function should return the price of baseToken in quoteToken, as in: quote/base (WETN/MASH)
   * @dev uses the Uniswap written OracleLibrary "getQuoteAtTick", does not call external libraries,
   *      uses decimals() for the correct power of 10
   * @param baseToken token which will be denominated in quote token
   * @param quoteToken token in which price will be denominated
   * @param fee the uniswap pool fee, pools have different fees so this is a pool selector for our usecase
   * @param period the amount of seconds we are going to look into the past for the new token price
   * @return returns the price of baseToken in quoteToken
   * */
  function getPriceOfTokenInToken(
    address baseToken,
    address quoteToken,
    uint24 fee,
    uint32 period
  ) internal view returns (uint256) {
    uint128 base = uint128(10)**uint128(IERC20Decimals(quoteToken).decimals());
    if (baseToken == quoteToken) return base;
    else
      return
        OracleLibrary.getQuoteAtTick(
          OracleLibrary.consult(V3Factory.getPool(baseToken, quoteToken, fee), period),
          base,
          baseToken,
          quoteToken
        );
  }

  /**
   * @notice This function should return the price of token in WETH
   * @dev simply feeds WETH in to the above function
   * @param token token which will be denominated in WETH
   * @param fee the pool fee, pools have different fees so this is a pool selector for our usecase
   * @param period the amount of seconds we are going to look into the past for the new token price
   * @return returns the price of token in WETH
   * */
  function getPriceOfTokenInWETH(
    address token,
    uint24 fee,
    uint32 period
  ) internal view returns (uint256) {
    return getPriceOfTokenInToken(token, WETH, fee, period);
  }

  /**
   * @notice This function should return the price of WETH in token
   * @dev simply feeds WETH into getPriceOfTokenInToken
   * @param token token which WETH will be denominated in
   * @param fee the uniswap pool fee, pools have different fees so this is a pool selector for our usecase
   * @param period the amount of seconds we are going to look into the past for the new token price
   * @return returns the price of token in WETH
   * */
  function getPriceOfWETHInToken(
    address token,
    uint24 fee,
    uint32 period
  ) internal view returns (uint256) {
    return getPriceOfTokenInToken(WETH, token, fee, period);
  }

  /**
   * @notice This function returns the price of token[0] in token[1], but more precisely and importantly the price ratio of the tokens in WETH
   * @dev this is done as to always have good prices due to WETH-token pools mostly always having the most liquidity
   * @param tokens array of tokens to get ratio for
   * @param fees the uniswap pool FEES, since these are two independent tokens
   * @param period the amount of seconds we are going to look into the past for the new token price
   * @return returns the price of token[0] in token[1]
   * */
  function getPriceRatioOfTokens(
    address[2] memory tokens,
    uint24[2] memory fees,
    uint32 period
  ) internal view returns (uint256) {
    return
      getPriceOfTokenInWETH(tokens[0], fees[0], period).mul(RATIO_DIVIDER) / getPriceOfTokenInWETH(tokens[1], fees[1], period);
  }
}