const _ = require('lodash');
const cfg = require('./config');

module.exports = async function (web3) {

  let ret = new cfg();
  ret.StartBlock = 363400;
  ret.BonusEndBlock = 1728000 + 363400;  // 2 months / 3 sec-per-block
  ret.SnowballPerBlock = web3.utils.toWei('100','ether');

  ret.SnowballDevPreMint = web3.utils.toWei('1000','ether');

  ret.lottery_startBlock = 363400;
  ret.lottery_period = 28800;
  ret.lottery_extraBonusEndBlock = 1728000 + 363400;
  ret.lottery_price = web3.utils.toWei('10','ether');
  ret.lottery_periodBonus = web3.utils.toWei('5000000','ether');
  return ret;
};
