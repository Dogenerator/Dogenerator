const BN = require('web3-utils').BN;

const config = require("../deploy/config.json");
const testConfig = require("./testConfig.json");
const deploy = require("../deploy/deploy");

const Token1 = artifacts.require('ERC20PresetMinterPauser.sol');
const PugFactory = artifacts.require('PugFactory.sol');
const Pug = artifacts.require('Pug.sol');
const PugStaking = artifacts.require('PugStaking.sol');
const PugToken = artifacts.require('PugToken.sol');

let contracts;
let pug;
let token1;
let pugFactory;
let pugStaking;
let pugToken;

contract("Pug", async (accounts) => {
    before(async () => {
        contracts = await deploy.init("ganache");

        pugFactory = await PugFactory.at(contracts.pugFactory);

        const txReceiptCreatePug = await pugFactory.createPug(
            testConfig.token.token1.name, 
            testConfig.token.token1.symbol,
            testConfig.token.token1.contract,
            12
        );
        pug = await Pug.at(txReceiptCreatePug.logs[5].args.pug);

        token1 = await Token1.at(testConfig.token.token1.contract);
    });

    it("Create Pug with token1", async () => {
        const pugAmount = new BN(web3.utils.toWei("10"));

        await token1.approve(pug.address, pugAmount.toString());

        const totalSupplyBefore = await token1.totalSupply();
        const pugToken1BalanceBefore = await token1.balanceOf(pug.address);
        const pugStakingBalanceBefore = await token1.balanceOf(contracts.pugStaking);
        const holderWoofTokenBalanceBefore = await pug.balanceOf(testConfig.token.token1.holder);

        await pug.pug(pugAmount.toString(), {
            from: testConfig.token.token1.holder
        });
        
        const totalSupplyAfter = await token1.totalSupply();
        const pugToken1BalanceAfter = await token1.balanceOf(pug.address);
        const pugStakingBalanceAfter = await token1.balanceOf(contracts.pugStaking);
        const holderWoofTokenBalanceAfter = await pug.balanceOf(testConfig.token.token1.holder);

        const fee = (new BN(config.ganache.factory.fee)).mul(pugAmount).div(new BN(1e12));

        assert(totalSupplyBefore.sub(totalSupplyAfter).toString() == fee.div(new BN(2)).toString());
        assert(pugToken1BalanceAfter.sub(pugToken1BalanceBefore).toString() == pugAmount.sub(fee).toString());
        assert(pugStakingBalanceAfter.sub(pugStakingBalanceBefore).toString() == fee.div(new BN(2)).toString());
        assert(holderWoofTokenBalanceAfter.sub(holderWoofTokenBalanceBefore).toString() == pugAmount.toString());
    });

    it("Unpug tokens", async () => {
        const pugAmount = new BN(web3.utils.toWei("10"));

        const pugToken1BalanceBefore = await token1.balanceOf(pug.address);
        const holderWoofTokenBalanceBefore = await pug.balanceOf(testConfig.token.token1.holder);
        const holderToken1BalanceBefore = await token1.balanceOf(testConfig.token.token1.holder);

        await pug.unpug(pugAmount.toString(), {
            from: testConfig.token.token1.holder
        });

        const pugToken1BalanceAfter = await token1.balanceOf(pug.address);
        const holderWoofTokenBalanceAfter = await pug.balanceOf(testConfig.token.token1.holder);
        const holderToken1BalanceAfter = await token1.balanceOf(testConfig.token.token1.holder);

        const fee = (new BN(config.ganache.factory.fee)).mul(pugAmount).div(new BN(1e12));

        assert(pugToken1BalanceBefore.sub(pugToken1BalanceAfter).toString() == pugAmount.sub(fee).toString());
        assert(holderWoofTokenBalanceBefore.sub(holderWoofTokenBalanceAfter).toString() == pugAmount.toString());
        assert(holderToken1BalanceAfter.sub(holderToken1BalanceBefore).toString() == pugAmount.sub(fee).toString());
    });

    it("withdraw rewards", async () => {
        const pugAmount = new BN(web3.utils.toWei("10"));

        await pugFactory.updateRewardPoints(token1.address, testConfig.token.token1.rewardPoints, {
            from: config['ganache'].factory.admin
        });

        await token1.approve(pug.address, pugAmount.mul(new BN(10)).toString());

        await pug.pug(pugAmount.toString(), {
            from: testConfig.token.token1.holder
        });

        await pug.pug(pugAmount.toString(), {
            from: testConfig.token.token1.holder
        });

        await pug.pug(pugAmount.toString(), {
            from: testConfig.token.token1.holder
        });

        const txReceiptRewards = await pug.withdrawRewards(testConfig.token.token1.holder);

        console.log(txReceiptRewards)
    });

    it("claim pug staking rewards", async () => {
        pugStaking = await PugStaking.at(contracts.pugStaking);
        pugToken = await PugToken.at(contracts.pugToken);

        const pugBalance = await pug.balanceOf(testConfig.token.token1.holder);
        await pugToken.approve(pugStaking.address, pugBalance);
        await pugStaking.deposit(pug.address, pugBalance);

        const pugAmount = new BN(web3.utils.toWei("10"));

        await token1.approve(pugAmount.mul(new BN(10)).toString());

        await pug.pug(pugAmount.toString(), {
            from: testConfig.token.token1.holder
        });

        await pug.pug(pugAmount.toString(), {
            from: testConfig.token.token1.holder
        });

        await pug.pug(pugAmount.toString(), {
            from: testConfig.token.token1.holder
        });

        const txReceiptStakingRewards = await pugStaking.withdrawRewards(testConfig.token.token1.holder);
        const txReceiptStakingRewards1 = await pugStaking.withdrawRewards(testConfig.token.token1.holder);
        console.log(txReceiptStakingRewards);
        console.log(txReceiptStakingRewards1);

        const userInfoBefore = await pugStaking.userStakingInfo(testConfig.token.token1.holder);
        console.log(userInfoBefore.amount.toString(), userInfoBefore.rewardDebt.toString(), pugBalance);

        const txReceiptWithdraw = await pugStaking.withdraw(pugBalance);
        console.log(txReceiptWithdraw);

        const userInfoAfter = await pugStaking.userStakingInfo(testConfig.token.token1.holder);
        console.log(userInfoAfter.amount.toString(), userInfoAfter.rewardDebt.toString())
    });
});