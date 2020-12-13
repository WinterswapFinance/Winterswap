const { expectRevert, time } = require('@openzeppelin/test-helpers');

const SnowTest = artifacts.require('SnowTest.sol');
const WinterswapV2Factory = artifacts.require('WinterswapV2Factory.sol');
const WHT = artifacts.require('WHT.sol');
const LP = artifacts.require('WinterswapV2Pair.sol');
const CCH = artifacts.require('CalcCodeHash.sol');
const Router = artifacts.require('WinterswapV2Router02.sol');
const Farm = artifacts.require('Farm.sol');
const Snowball = artifacts.require('Snowball.sol');


contract('SmokeTest', async function (accounts) {

  let snowtest;
  let wht;
  let factory;
  let lp;
  let router;
  let farm;
  let snowball;
  before('setup', async function () {
    snowtest = await SnowTest.new(global.winterswap.FROM_DEPLOYER);
    await snowtest.mint(global.winterswap.deployer,web3.utils.toWei('500', 'ether'),global.winterswap.FROM_DEPLOYER);

    wht = await WHT.deployed();
    await wht.deposit({from: global.winterswap.deployer,value:web3.utils.toWei('500', 'ether')})

    factory = await WinterswapV2Factory.deployed();

    let tx = await factory.createPair(wht.address, snowtest.address);

    expect(tx.logs[0].event).to.equal('PairCreated');
    let pairAddress = tx.logs[0].args.pair;
    console.log(`pairAddress: ${pairAddress}`);
    lp = await LP.at(pairAddress);

    router = await Router.deployed();
    farm = await Farm.deployed();
    snowball = await Snowball.deployed();

    // approve for router
    await wht.approve(router.address,'0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',global.winterswap.FROM_DEPLOYER);
    await snowtest.approve(router.address,'0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',global.winterswap.FROM_DEPLOYER);
  });

  it('verify codehash of pair', async function () {
    let cch = await CCH.new(global.winterswap.FROM_DEPLOYER);
    let codehash = await cch.codeHash();
    console.log(`CodeHash: ${codehash}`);

    let pair = await cch.pairFor(factory.address,wht.address, snowtest.address);
    console.log(`pairFor: ${pair}`);

    expect(pair).to.equal(lp.address);
  });//it

  it('init deposit, add liquidity to pair to deployer', async function () {
    let res = await router.addLiquidity(
      wht.address,
      snowtest.address,
      web3.utils.toWei('100', 'ether'),
      web3.utils.toWei('100', 'ether'),
      web3.utils.toWei('100', 'ether'),
      web3.utils.toWei('100', 'ether'),
      global.winterswap.deployer,
      1700000000,
      global.winterswap.FROM_DEPLOYER,
    );

    let lp_balance = await lp.balanceOf(global.winterswap.deployer);

    //amountA * amountB - MINIMUM_LIQUIDITY
    expect(lp_balance.toString()).to.equal('99999999999999999000');


  })//it

  it('add lp to Farm', async function () {
    await farm.add(100,lp.address,true);

    let record = await farm.poolInfo(0);
    //console.log(JSON.stringify(record,null,2))
  })//it

  it('stake lp to Farm', async function () {

    await lp.approve(farm.address,'0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',global.winterswap.FROM_DEPLOYER)

    let res = await farm.deposit(0,1000000000000,global.winterswap.FROM_DEPLOYER);

    let lp_balance = await lp.balanceOf(global.winterswap.deployer);
    expect(lp_balance.toString()).to.equal('99999998999999999000');

    let farm_balance = await farm.pendingReward(0,global.winterswap.deployer);
    expect(farm_balance.toString()).to.equal('0')

    await time.advanceBlock();
    await time.advanceBlock();
    await time.advanceBlock();

    farm_balance = await farm.pendingReward(0,global.winterswap.deployer);
    // 3(times) * snowballPerBlock(100) * BONUS_MULTIPLIER(10) = 3000
    expect(web3.utils.fromWei(farm_balance.toString(),'ether')).to.equal('3000')


  })//it

  it('withdraw all stake and get snowball', async function () {

    let res = await farm.withdraw(0,1000000000000,global.winterswap.FROM_DEPLOYER);

    let farm_balance = await farm.pendingReward(0,global.winterswap.deployer);
    expect(farm_balance.toString()).to.equal('0')

    let lp_balance = await lp.balanceOf(global.winterswap.deployer);
    expect(lp_balance.toString()).to.equal('99999999999999999000');

    let snowball_balance = await snowball.balanceOf(global.winterswap.deployer);
    // 4(times) * snowballPerBlock(100) * BONUS_MULTIPLIER(10) = 4000
    // don't forget calling farm.withdraw() consumes one more block
    expect(web3.utils.fromWei(snowball_balance.toString(),'ether')).to.equal('4000');

    let snowball_balance_dev = await snowball.balanceOf(global.winterswap.devaddr);
    expect(web3.utils.fromWei(snowball_balance_dev.toString()),'ether').to.equal('400');

  })//it

  it('swap, and by the way it change the k or kLast', async function () {

    // 400, 400 in balance
    // 100, 100 in swap
    let res = await router.swapExactTokensForTokens(
      web3.utils.toWei('10', 'ether'),
      web3.utils.toWei('9', 'ether'),//ideally should be 11.11111
      [
        wht.address,
        snowtest.address
      ],
      global.winterswap.deployer,
      1700000000,
      global.winterswap.FROM_DEPLOYER,
    );


    // the liquidity doesn't change, the dev's benefit won't be settled
    let lp_balance_dev = await lp.balanceOf(global.winterswap.devaddr);
    expect(
      web3.utils.fromWei(lp_balance_dev.toString(),'ether')
    ).to.equal('0');

    let wht_balance = await wht.balanceOf(global.winterswap.deployer);
    expect(
      web3.utils.fromWei(wht_balance.toString(),'ether')
    ).to.equal('390')//400-10

    let snowtest_balance = await snowtest.balanceOf(global.winterswap.deployer);
    expect(
      web3.utils.fromWei(snowtest_balance.toString(),'ether').substring(0,3)
    ).to.equal('409')//400+ ~9
  })//it

  it('add more liquidity to trigger and check feeTo address\'s lp balance', async function () {

    let res = await router.addLiquidity(
      wht.address,
      snowtest.address,
      web3.utils.toWei('100', 'ether'),
      web3.utils.toWei('100', 'ether'),
      web3.utils.toWei('50', 'ether'),
      web3.utils.toWei('50', 'ether'),
      global.winterswap.deployer,
      1700000000,
      global.winterswap.FROM_DEPLOYER,
    );

    let lp_balance_dev = await lp.balanceOf(global.winterswap.devaddr);
    expect(
      web3.utils.fromWei(lp_balance_dev.toString(),'ether')
    ).to.not.equal('0');
  })//it

});

