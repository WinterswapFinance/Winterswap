const _ = require('lodash');
const cfg = require('./config');

module.exports = async function (web3) {

  let ret = new cfg();
  ret.StartBlock = 214000;
  // 2 months / 3 sec-per-block
  ret.BonusEndBlock = 1728000 + 214000;
  ret.SnowballPerBlock = 100;
  return ret;
};
