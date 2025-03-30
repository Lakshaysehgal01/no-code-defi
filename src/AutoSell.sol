// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
contract AutoSellEth{

    AggregatorV3Interface internal priceFeed;
    ISwapRouter internal uniswapRouter;
    IERC20 internal usdtToken;
    uint public thresholdPrice;
    uint public totalDeposited;
    address public owner;

    //event of swap
    event swapEmitted(uint256 indexed ethSold,uint256 indexed usdcRecieved);

    event Withdrawal(address token ,uint256 value);

    //constructor
    constructor(address _priceFeedAddress, address _uniswapRouterAddress, address _usdtTokenAddress,uint _threshold){
        priceFeed=AggregatorV3Interface(_priceFeedAddress);
        owner=msg.sender;
        usdtToken=IERC20(_usdtTokenAddress);
        uniswapRouter=ISwapRouter(_uniswapRouterAddress);
        thresholdPrice=_threshold;
    }

    //onlyOwner modifier(update it to only executor in future)
    modifier onlyOwner{
        require(msg.sender==owner,"You are not authorised to call this function");
        _;
    }
    //deposit function 
    function deposit()public payable {
        require(msg.value>0,"Please deposit more than zero ETH");
        totalDeposited+=msg.value;
    }

    //functions to get correct amount of usdc from uniswap
    function getTick(uint256 price) internal pure returns (int24) {
        return int24(int256(log2(price) * 2**96 / 1e18));
    }
    function log2(uint256 x) internal pure returns (uint256) {
        uint256 r = 0;
        while (x > 1) {
            x >>= 1;
            r++;
        }
        return r;
    }
    function getPriceLimit(uint _p)public view returns(uint160){
        (,int256 price, , ,)=priceFeed.latestRoundData();
        require(price>0,"Incorrect data from oracle");
        uint256 ethPrice=uint256(price)*1e10;
        uint256 lowerBound=(ethPrice*98)/100;
        uint256 upperBound=(ethPrice*102)/100;
        uint160 sqrtPriceX96Lower = uint160(TickMath.getSqrtRatioAtTick(getTick(lowerBound)));
        uint160 sqrtPriceX96Upper = uint160(TickMath.getSqrtRatioAtTick(getTick(upperBound)));
        return sqrtPriceX96Lower;
    }

    // function to check eth price and swap it with usdc according to the threshold value provided by user 
    function checkPriceAndSell() external{
        (,int256 price, , , )=priceFeed.latestRoundData();
        require(uint256(price)<thresholdPrice,"Eth price is not less than threshold value");
        uint money=address(this).balance;
        require(money>0,"No Eth to sell");
        ISwapRouter.ExactInputSingleParams memory params= ISwapRouter.ExactInputSingleParams({
            tokenIn:address(0),
            tokenOut:address(usdtToken),
            fee:3000,
            recipient:address(this),
            deadline:block.timestamp+60,
            amountIn: money,
            amountOutMinimum:(uint256(price)*98)/100,
            sqrtPriceLimitX96:getPriceLimit(uint256(price))
        });
        uint256 usdcRecieved=uniswapRouter.exactInputSingle{value:money}(params);
        emit swapEmitted(money, usdcRecieved);
    }

    
    //staking usdc on aave protocol function 
    // function stakeUsdc() public{

    // }


    //withdraw
    function withdraw() public onlyOwner{
        uint256 balance=address(this).balance;
        require(balance>0,"No eth in contract");
        payable(owner).transfer(balance);
        emit Withdrawal(address(0), balance);
    }

    //withdraw Usdc
    function withdrawUsdc()public onlyOwner {
        uint256 balance=usdtToken.balanceOf(address(this));
        require(balance>0,"No usdc in contract");
        usdtToken.transfer(owner, balance);
        emit Withdrawal(address(usdtToken), balance);
    }

    //withdraw aave staked usdc 

}




