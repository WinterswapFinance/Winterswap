const Factory = artifacts.require('WinterswapV2Factory');
const WHT = artifacts.require('WHT');
const Router = artifacts.require('WinterswapV2Router02');
const Snowball = artifacts.require('Snowball');
const Farm = artifacts.require('Farm');

module.exports = async function (deployer, network, accounts) {

  const FROM_DEPLOYER = global.winterswap.FROM_DEPLOYER;
  const admin = global.winterswap.admin;
  const devaddr = global.winterswap.devaddr;

  console.log('deploying Winterswap factory');
  await deployer.deploy(Factory, admin, FROM_DEPLOYER);
  const factory = await Factory.deployed();
  console.log('winterswap_factory address :                ' + factory.address);

  console.log('deploying WHT');
  await deployer.deploy(WHT, FROM_DEPLOYER);
  const wht = await WHT.deployed();
  console.log('wht address :                ' + wht.address);

  console.log('deploying Winterswap router');
  await deployer.deploy(Router, factory.address, wht.address, FROM_DEPLOYER);
  const router = await Router.deployed();
  console.log('router address :                ' + router.address);

  console.log('deploying Snowball');
  await deployer.deploy(Snowball, FROM_DEPLOYER);
  const snowball = await Snowball.deployed();
  console.log('snowball address :                ' + snowball.address);

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


  //================================================================================//

  console.log();
  console.log('Factory address :                            ' + factory.address);
  console.log('WHT address :                                ' + wht.address);
  console.log('Router address :                             ' + router.address);
  console.log('Snowball address :                           ' + snowball.address);
  console.log('Farm address :                               ' + farm.address);

};
