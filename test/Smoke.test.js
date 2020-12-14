const { expectRevert, time } = require('@openzeppelin/test-helpers');

const SnowTest = artifacts.require('SnowTest.sol');
const WinterswapV2Factory = artifacts.require('WinterswapV2Factory.sol');
const WHT = artifacts.require('WHT.sol');
const LP = artifacts.require('WinterswapV2Pair.sol');
const CCH = artifacts.require('CalcCodeHash.sol');
const Router = artifacts.require('WinterswapV2Router02.sol');
const Farm = artifacts.require('Farm.sol');
const Snowball = artifacts.require('Snowball.sol');
const Snowman = artifacts.require('Snowman');


contract('SmokeTest', async function (accounts) {

  let snowtest;
  let wht;
  let factory;
  let wHT_snowtest_lp;
  let router;
  let farm;
  let snowball;
  let snowman;
  let cch;
  before('setup', async function () {
    snowtest = await SnowTest.new(global.winterswap.FROM_DEPLOYER);
    await snowtest.mint(global.winterswap.deployer,web3.utils.toWei('1000', 'ether'),global.winterswap.FROM_DEPLOYER);
    await snowtest.mint(global.winterswap.devaddr,web3.utils.toWei('1000', 'ether'),global.winterswap.FROM_DEPLOYER);

    wht = await WHT.deployed();
    await wht.deposit({from: global.winterswap.deployer,value:web3.utils.toWei('1000', 'ether')})
    await wht.deposit({from: global.winterswap.devaddr,value:web3.utils.toWei('1000', 'ether')})

    factory = await WinterswapV2Factory.deployed();

    let tx = await factory.createPair(wht.address, snowtest.address);

    expect(tx.logs[0].event).to.equal('PairCreated');
    let pairAddress = tx.logs[0].args.pair;
    console.log(`pairAddress: ${pairAddress}`);
    wHT_snowtest_lp = await LP.at(pairAddress);

    router = await Router.deployed();
    farm = await Farm.deployed();
    snowball = await Snowball.deployed();
    snowman = await Snowman.deployed();

    // approve for router
    await wht.approve(router.address,'0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',global.winterswap.FROM_DEPLOYER);
    await snowball.approve(router.address,'0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',global.winterswap.FROM_DEPLOYER);
    await snowtest.approve(router.address,'0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',global.winterswap.FROM_DEPLOYER);
    await wht.approve(router.address,'0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',global.winterswap.FROM_DEV_ADDR);
    await snowball.approve(router.address,'0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',global.winterswap.FROM_DEV_ADDR);
    await snowtest.approve(router.address,'0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',global.winterswap.FROM_DEV_ADDR);

    // add wht<>snowball pair

    let snowball_balance_devaddr = toEth(await snowball.balanceOf(global.winterswap.devaddr));
    console.log(`snowball_balance: ${snowball_balance_devaddr}`);
    expect(snowball_balance_devaddr).to.equal('1000')

    cch = await CCH.new(global.winterswap.FROM_DEPLOYER);
    let codehash = await cch.codeHash();
    console.log(`CodeHash: ${codehash}`);

    let res = await router.addLiquidity(
      wht.address,
      snowball.address,
      web3.utils.toWei('500', 'ether'),
      web3.utils.toWei('500', 'ether'),
      web3.utils.toWei('500', 'ether'),
      web3.utils.toWei('500', 'ether'),
      global.winterswap.devaddr,
      1700000000,
      global.winterswap.FROM_DEV_ADDR,
    );
  });

  it('verify codehash of pair', async function () {

    let pair = await cch.pairFor(factory.address,wht.address, snowtest.address);
    console.log(`pairFor: ${pair}`);

    expect(pair).to.equal(wHT_snowtest_lp.address);
  });//it

  it('init deposit, add WHT<>Snowtest liquidity to pair to deployer', async function () {
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

    let lp_balance = await wHT_snowtest_lp.balanceOf(global.winterswap.deployer);

    //amountA * amountB - MINIMUM_LIQUIDITY
    expect(lp_balance.toString()).to.equal('99999999999999999000');


  })//it

  it('add WHT<>Snowtest lp to Farm', async function () {
    await farm.add(100,wHT_snowtest_lp.address,true);

    let record = await farm.poolInfo(0);
    //console.log(JSON.stringify(record,null,2))
  })//it

  it('stake lp to Farm', async function () {

    await wHT_snowtest_lp.approve(farm.address,'0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',global.winterswap.FROM_DEPLOYER)

    let res = await farm.deposit(0,1000000000000,global.winterswap.FROM_DEPLOYER);

    let lp_balance = await wHT_snowtest_lp.balanceOf(global.winterswap.deployer);
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

    let lp_balance = await wHT_snowtest_lp.balanceOf(global.winterswap.deployer);
    expect(lp_balance.toString()).to.equal('99999999999999999000');

    let snowball_balance = await snowball.balanceOf(global.winterswap.deployer);
    // 4(times) * snowballPerBlock(100) * BONUS_MULTIPLIER(10) = 4000
    // don't forget calling farm.withdraw() consumes one more block
    expect(web3.utils.fromWei(snowball_balance.toString(),'ether')).to.equal('4000');

    let snowball_balance_dev = await snowball.balanceOf(global.winterswap.devaddr);
    //4000/10 + original(1000-500=500) = 900
    expect(web3.utils.fromWei(snowball_balance_dev.toString()),'ether').to.equal('900');

  })//it

  it('swap wht -> snowtest, and by the way it change the k or kLast', async function () {

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
    let lp_balance_dev = await wHT_snowtest_lp.balanceOf(global.winterswap.devaddr);
    expect(
      web3.utils.fromWei(lp_balance_dev.toString(),'ether')
    ).to.equal('0');

    // origin(1000)- WHT<>Snowtest(100) - swapout(10) = 890
    let wht_balance = await wht.balanceOf(global.winterswap.deployer);
    expect(
      web3.utils.fromWei(wht_balance.toString(),'ether')
    ).to.equal('890')

    // origin(1000)- WHT<>Snowtest(100) + swapin(~9) = 909
    let snowtest_balance = await snowtest.balanceOf(global.winterswap.deployer);
    expect(
      web3.utils.fromWei(snowtest_balance.toString(),'ether').substring(0,3)
    ).to.equal('909')

    //show the wht of the router
    let wht_balance_router = toEth(await wht.balanceOf(router.address));
    console.log(`wht_balance_router: ${wht_balance_router}`);
    expect(wht_balance_router).to.equal('0')



    //!!!! the reserve of WHT<>snowtest
    // note that, 2/1000 of input(WHT) is send to snowman factory
    // get reserves of WHT<>snowtest
    let reserves = await wHT_snowtest_lp.getReserves();
    //reserve of snowtest should be (100-x)(100+ (100%- 0.5%)*10 )= 100*100   x= 0.94 100-x=90.9504
    let reserve0= toEth(reserves._reserve0);
    console.log(`reserve0: ${reserve0}`);

    if (await wHT_snowtest_lp.token0() === snowtest.address){
      expect(reserve0.substr(0,7)).to.equal('90.9504')
    }else{
      expect(reserve0).to.equal('109.98')
    }

    // the 2/1000 of wht
    // reserve of wht should be 100+ 10 - 10* 0.2%=109.98
    let reserve1= toEth(reserves._reserve1);
    console.log(`reserve1: ${reserve1}`);

    if (await wHT_snowtest_lp.token1() === wht.address){
      expect(reserve1).to.equal('109.98')
    }else{
      expect(reserve1.substr(0,7)).to.equal('90.9504')
    }

    //show the snowball the snow_factory has
    //actually, 2/1000 of input(wht) is first swap WHT<>Snowball, then send into the snow factory
    let snowball_balance_snowman_factory = toEth(await snowball.balanceOf(snowman.address));
    // should be appox. less than 10* 2/1000 = 0.02
    // 0.02 is the fee before swap, then 0.02 is sent to WHT<>snowball swap to swap_free into snowball
    // (500-x)(500+0.02)=500*500 x=0.019992
    console.log(`snowball_balance_snowman_factory: ${snowball_balance_snowman_factory}`);
    expect(snowball_balance_snowman_factory.substr(0,9)).to.equal('0.0199992')

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

    let lp_balance_dev = await wHT_snowtest_lp.balanceOf(global.winterswap.devaddr);
    expect(
      web3.utils.fromWei(lp_balance_dev.toString(),'ether')
    ).to.not.equal('0');
  })//it

  it('add snowball<> snowtest pair and swap, the tx_fee of snowball should go directly into snowman factory', async function () {
    await router.addLiquidity(
      snowball.address,
      snowtest.address,
      web3.utils.toWei('100', 'ether'),
      web3.utils.toWei('100', 'ether'),
      web3.utils.toWei('100', 'ether'),
      web3.utils.toWei('100', 'ether'),
      global.winterswap.devaddr,
      1700000000,
      global.winterswap.FROM_DEV_ADDR,
    );

    //swap snowball into snowtest will cauase the 2/1000 snowball go DIRECTLY into snowman factory
    await router.swapExactTokensForTokens(
      web3.utils.toWei('10', 'ether'),
      web3.utils.toWei('9', 'ether'),//ideally should be 11.11111
      [
        snowball.address,
        snowtest.address
      ],
      global.winterswap.deployer,
      1700000000,
      global.winterswap.FROM_DEPLOYER,
    );

    //show the snowball the snow_factory has
    let snowball_balance_snowman_factory = toEth(await snowball.balanceOf(snowman.address));
    console.log(`snowball_balance_snowman_factory: ${snowball_balance_snowman_factory}`);
    // previous(0.019993) + 0.02 = 0.0399992
    expect(snowball_balance_snowman_factory.substr(0,9)).to.equal('0.0399992')
  })//it


  function toWei(eth){
    return web3.utils.toWei(eth.toString(),'ether');
  }
  function toEth(wei){
    return web3.utils.fromWei(wei.toString(),'ether');
  }
});

