// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "../openzeppelin/math/SafeMath.sol";
import "../swap/libraries/TransferHelper.sol";
import "../snowball/Snowball.sol";

// one address can only buy one ticket in one term, we don't recommend use multiple accounts to participate,
// winner could take all paid snowballs plus additional bonus, which is related to bonus, bonus_multiplier and extraBonusEndBlock
contract Lottery {
    using SafeMath for uint256;

    // The block number when Snowball mining starts.
    uint256 public immutable startBlock;
    // How long a term lasts, in blocks
    uint256 public immutable period;
    // Block number when bonus Snowball period ends.
    uint256 public immutable extraBonusEndBlock;
    // Bonus muliplier for early snowball makers.
    uint256 public constant BONUS_MULTIPLIER = 10;
    // Ticket price
    uint256 public immutable price;
    // Bonus for a term
    uint256 public immutable periodBonus;
    // Starts at 0
    uint256 public firstTermToDraw;

    Snowball public snowball;

    //term => buyers
    mapping(uint256 => address[]) public buyerRecord;
    //term => winner index
    mapping(uint256 => DrawInfo) public drawRecord;

    struct DrawInfo{
        address winner;
        uint256 award;
        uint256 bonus;
    }

    event Buy(uint256 indexed term, address buyer, uint256 tickets);
    event Draw(uint256 indexed term, address winner);
    //extraBonusEndBlock should be times of term since startBlock
    constructor(uint256 _startBlock, uint256 _period, uint256 _extraBonusEndBlock, uint256 _price, uint256 _periodBonus, Snowball _snowball){
        startBlock = _startBlock;
        period = _period;
        extraBonusEndBlock = _extraBonusEndBlock;
        price = _price;
        periodBonus = _periodBonus;
        snowball = _snowball;
    }

    // you can only buy the current term;
    function buyTickets(uint256 number) started external{
        TransferHelper.safeTransferFrom(address(snowball),msg.sender,address(this), number.mul(price));
        uint256 term = calcTerm(block.number);
        require(term >= firstTermToDraw, "Lottery: firstTermToDraw should be equal or small than current term, that's strange");
        for(uint256 i = 0; i < number; i ++){
            buyerRecord[term].push(msg.sender);
        }
        emit Buy(term, msg.sender, number);
    }

    //the pseudoRandom, is up to the POA miner of Heco chain, which has almost no individual interest
    //thus we can trust the Heco miners
    //do NOT use this pserdoRandom in Pow and Pos permission election blockchains
    function draw() public{
        if(block.number < startBlock) {
            return;
        }

        uint256 currentTerm = calcTerm(block.number);
        if (currentTerm <= firstTermToDraw){
            return;
        }
        for(uint256 term = firstTermToDraw ; term <= currentTerm ; term ++){

            if(gasleft() < 1000000){
                break;
            }
            if(buyerRecord[term].length==0){
                firstTermToDraw = term + 1;
                continue;
            }

            uint256 lastBlockOfTerm = calcLastBlockNum(term);
            uint256 pseudoRandom = getBlockHash(lastBlockOfTerm);

            uint256 totalAward = buyerRecord[term].length.mul(price);
            uint256 bonus = lastBlockOfTerm <= extraBonusEndBlock ? periodBonus.mul(BONUS_MULTIPLIER):periodBonus;


            address winner = buyerRecord[term][pseudoRandom.mod(buyerRecord[term].length)];
            //?
            uint256 tickets = buyerRecord[term].length;

            TransferHelper.safeTransfer(
                address(snowball),
                winner,
                tickets.mul(price)
            );


            snowball.mint(winner, bonus);

            emit Draw(term, winner);
            //no back-end servers, filtering log by indexed key is a little annoying, for now, save them in the storage and remove later
            drawRecord[term] = DrawInfo(winner, totalAward, bonus);

            firstTermToDraw = term + 1;
        }
    }

    function notify() external{
        draw();
    }

    function getBlockHash(uint256 blocknum) internal view returns(uint256){
        uint256 hash = uint256(blockhash(blocknum));
        if(hash == 0){
            return  uint256(blockhash(block.number));
        }
        return hash;
    }


    function calcTerm(uint256 blocknum) view internal returns(uint256){
        return (blocknum.sub(startBlock)).div(period);
    }

    function calcLastBlockNum(uint256 term) view internal returns(uint256){
        return startBlock.add(term.mul(period+1)).sub(1) ;
    }

    modifier started(){
        require(block.number >= startBlock, "Lottery, lottery does not open yet");
        _;
    }
}
