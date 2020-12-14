const Factory = artifacts.require('WinterswapV2Factory');
const WHT = artifacts.require('WHT');
const Router = artifacts.require('WinterswapV2Router02');
const Snowball = artifacts.require('Snowball');
const Snowman = artifacts.require('Snowman');
const Farm = artifacts.require('Farm');
const WNS = artifacts.require('WNS');

module.exports = async function (deployer, network, accounts) {

  const FROM_DEPLOYER = global.winterswap.FROM_DEPLOYER;
  const FROM_ADMIN = global.winterswap.FROM_ADMIN;
  const admin = global.winterswap.admin;
  const devaddr = global.winterswap.devaddr;
  const depoyeraddr = global.winterswap.deployer;


  console.log('deploying WHT');
  await deployer.deploy(WHT, FROM_DEPLOYER);
  const wht = await WHT.deployed();
  console.log('wht address :                ' + wht.address);

  console.log('deploying WNS');
  await deployer.deploy(WNS, admin, FROM_DEPLOYER);
  const wns = await WNS.deployed();
  console.log('wns address :                ' + wns.address);

  console.log('deploying Snowball');
  await deployer.deploy(Snowball, devaddr, FROM_DEPLOYER);
  const snowball = await Snowball.deployed();
  console.log('snowball address :                ' + snowball.address);

  console.log('deploying Snowman');
  await deployer.deploy(Snowman, wns.address, FROM_DEPLOYER);
  const snowman = await Snowman.deployed();
  console.log('Snowman address :                ' + snowman.address);

  console.log('deploying Winterswap router');
  await deployer.deploy(Router, wns.address, FROM_DEPLOYER);
  const router = await Router.deployed();
  console.log('router address :                ' + router.address);


  console.log('deploying Winterswap factory');
  await deployer.deploy(Factory, admin, wns.address, FROM_DEPLOYER);
  const factory = await Factory.deployed();
  console.log('winterswap_factory address :                ' + factory.address);

  console.log('deploying Farm');
  await deployer.deploy(Farm, snowball.address, devaddr,
    web3.utils.toWei(global.winterswap.config.SnowballPerBlock.toString(), 'ether'),
    global.winterswap.config.StartBlock,
    global.winterswap.config.BonusEndBlock,
    FROM_DEPLOYER);
  const farm = await Farm.deployed();
  console.log('farm address :                ' + farm.address);

  console.log('set owner of Snowball to Farm');
  await snowball.transferOwnership(farm.address, FROM_DEPLOYER);
  console.log('Snowball\' owner address :                ' + await snowball.owner());

  console.log('set feeTo address of factory');
  await factory.setFeeTo(devaddr,{from: admin});
  console.log('factory feeTo address:                   ' + await factory.feeTo());

  await wns.setAll(router.address, factory.address, wht.address, snowman.address, snowball.address, farm.address, FROM_ADMIN);

  await router.init(FROM_DEPLOYER);
  await factory.init(FROM_DEPLOYER);
  await snowman.init(FROM_DEPLOYER);

  //================================================================================//

  console.log();
  console.log('WNS address :                                ' + wns.address);
  console.log('Factory address :                            ' + factory.address);
  console.log('WHT address :                                ' + wht.address);
  console.log('Router address :                             ' + router.address);
  console.log('Snowball address :                           ' + snowball.address);
  console.log('Snowman address :                            ' + snowman.address);
  console.log('Farm address :                               ' + farm.address);

};
