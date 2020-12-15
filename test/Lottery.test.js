const { constants, time } = require('@openzeppelin/test-helpers');

const Snowball = artifacts.require('Snowball.sol');
const Lottery = artifacts.require('Lottery.sol')
const WNS = artifacts.require('WNS.sol')
contract('LotteryTest', async function (accounts) {

  let snowball;
  let lottery;
  let wns;
  let emptyaddr= constants.ZERO_ADDRESS;
  let ticketTerm;
  before('setup', async function () {

    const Config = require('../migrations/config/development.js');
    let config = await Config(web3);

    wns = await WNS.new(global.winterswap.admin, global.winterswap.FROM_DEPLOYER);
    snowball = await Snowball.new(global.winterswap.devaddr,toWei("1000"), wns.address, global.winterswap.FROM_DEPLOYER);
    lottery = await Lottery.new(
      config.lottery_startBlock,
      config.lottery_period,
      config.lottery_extraBonusEndBlock,
      config.lottery_price,
      config.lottery_periodBonus,
      snowball.address,
      global.winterswap.FROM_DEPLOYER
    );

    await wns.setAll(emptyaddr, emptyaddr, emptyaddr, emptyaddr, snowball.address, emptyaddr, lottery.address, global.winterswap.FROM_ADMIN);
    await snowball.init(global.winterswap.FROM_DEPLOYER);

    // approve for router
    await snowball.approve(lottery.address,'0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',global.winterswap.FROM_DEV_ADDR);

  });

  it('buy ticket', async function () {

    let tx = await lottery.buyTickets(3,global.winterswap.FROM_DEV_ADDR);
    //console.log(JSON.stringify(tx,null,2));

    let buy = tx.logs.filter( log => log.event === 'Buy')[0];
    expect(buy.args.buyer).to.equal(global.winterswap.devaddr);
    ticketTerm = buy.args.term.toString();

    expect(await lottery.buyerRecord(ticketTerm,0)).to.equal(global.winterswap.devaddr);

    let balance = await snowball.balanceOf(lottery.address);
    console.log(`balance: ${toEth(balance.toString())}`);

  });//it


  it('draw', async function () {

    await time.advanceBlock();
    await time.advanceBlock();
    await time.advanceBlock();
    await time.advanceBlock();
    await time.advanceBlock();

    let tx = await lottery.draw(global.winterswap.FROM_DEV_ADDR);
    //console.log(JSON.stringify(tx,null,2));

    let draw = tx.logs.filter( log => log.event === 'Draw')[0];
    expect(draw.args.term.toString()).to.equal(ticketTerm);
    expect(draw.args.winner).to.equal(global.winterswap.devaddr);


    let drawInfo = await lottery.drawRecord(ticketTerm);
    //console.log(JSON.stringify(drawInfo,null,2));
    expect(drawInfo.winner).to.equal(global.winterswap.devaddr);
    expect(drawInfo.award.toString()).to.equal(toWei(3));
    //50 * 10
    expect(drawInfo.bonus.toString()).to.equal(toWei(500));


  });//it


  function toWei(eth){
    return web3.utils.toWei(eth.toString(),'ether');
  }
  function toEth(wei){
    return web3.utils.fromWei(wei.toString(),'ether');
  }
});

