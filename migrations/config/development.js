const _ = require('lodash');
const cfg = require('./config');

module.exports = async function (web3) {

  let ret = new cfg();
  ret.StartBlock = 0;
  ret.BonusEndBlock = 10000 + 0;
  ret.SnowballPerBlock = 100;
  return ret;
};

