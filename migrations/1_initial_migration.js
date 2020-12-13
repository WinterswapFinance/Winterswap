const Migrations = artifacts.require('Migrations');

module.exports = async function (deployer, network, accounts) {
  console.log('==================available accounts==================');
  console.log(accounts);
  console.log('==================available accounts==================');


  //accounts 0 = deployer account
  //accounts 1 = admin account
  //accounts 2 = dev account

  global.winterswap = {};
  global.winterswap.emptyAddress = '0x0000000000000000000000000000000000000000';
  global.winterswap.emptyBytes32 = '0x0000000000000000000000000000000000000000000000000000000000000000';
  global.winterswap.deployer = accounts[0];
  global.winterswap.FROM_DEPLOYER = {from: accounts[0]};
  global.winterswap.admin = accounts[1];
  global.winterswap.FROM_ADMIN = {from: accounts[1]};
  global.winterswap.devaddr = accounts[2];
  global.winterswap.FROM_DEV_ADDR = {from: accounts[2]};

  console.log(`you are using ${network}`);
  if (network === 'development') {

    const Config = require('./config/development.js');
    global.winterswap.config = await Config(web3);
    let b = web3.utils.fromWei((await web3.eth.getBalance(global.winterswap.deployer)).toString(), 'ether');
    console.log(`now eth in deployer ${global.winterswap.deployer} lefts ${b} ether`);

  } else if (network === 'huobi_test') {

    const Config = require('./config/huobi_test.js');
    global.winterswap.config = await Config(web3);
    let b = web3.utils.fromWei((await web3.eth.getBalance(global.winterswap.deployer)).toString(), 'ether');
    console.log(`now eth in deployer ${global.winterswap.deployer} lefts ${b} ether`);

  } else {
    throw new Error('network unknown');
  }


  const FROM_DEPLOYER =  global.winterswap.FROM_DEPLOYER;

  await deployer.deploy(Migrations, FROM_DEPLOYER);
};
