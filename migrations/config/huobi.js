const _ = require('lodash');
const cfg = require('./config');

module.exports = async function (web3) {

  let ret = new cfg();
  ret.StartBlock = 555000;
  //28800 for one day
  ret.BonusEndBlock = 555000 + 864000;  // 1 months / 3 sec-per-block
  ret.SnowballPerBlock = web3.utils.toWei('50','ether');

  ret.SnowballDevPreMint = web3.utils.toWei('100000000','ether');

  ret.lottery_startBlock = 555000;
  ret.lottery_period = 28800;//oneday
  ret.lottery_extraBonusEndBlock = 555000 + 864000;
  ret.lottery_price = web3.utils.toWei('1','ether');
  ret.lottery_periodBonus = web3.utils.toWei('14400','ether');
  return ret;
};
