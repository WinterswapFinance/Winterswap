const _ = require('lodash');
const cfg = require('./config');

module.exports = async function (web3) {

  let ret = new cfg();
  ret.StartBlock = 0;
  ret.BonusEndBlock = 10000 + 0;
  ret.SnowballPerBlock = web3.utils.toWei('100','ether');

  ret.SnowballDevPreMint = web3.utils.toWei('1000','ether');

  ret.lottery_startBlock = 0;
  ret.lottery_period = 5;
  ret.lottery_extraBonusEndBlock = 100000;
  ret.lottery_price = web3.utils.toWei('1','ether');
  ret.lottery_periodBonus = web3.utils.toWei('50','ether');
  return ret;
};

