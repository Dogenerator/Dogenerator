const SushiRouterCompiled = require("../build/contracts/SushiRouter.json");
const ERC20Compiled = require("../build/contracts/ERC20.json");

const allConfig = require("./config.json");
const allPugConfig = require("./pugConfig.json");
const deploy = require("./deploy");

const deployPug = async (network) => {
    const pugConfig = allPugConfig[network];
    const config = allConfig[network];

    const {pugFactory, pugToken, pugStaking, web3} = await deploy.init(network);

    // const baseToken = new web3.eth.Contract(ERC20Compiled.abi, pugConfig.baseToken.address);

    // await baseToken.methods.approve(config.sushi.router, web3.utils.toWei("10000")).send({
    //     from: pugConfig.baseToken.holder
    // });
    // const sushiRouter = new web3.eth.Contract(SushiRouterCompiled.abi, config.sushi.router);
    // await sushiRouter.methods.addLiquidityETH(
    //     pugConfig.baseToken.address,
    //     web3.utils.toWei("10000"),
    //     web3.utils.toWei("10000"),
    //     web3.utils.toWei("70"),
    //     pugConfig.baseToken.holder,
    //     Date.now() + 100000
    // ).send({
    //     from: pugConfig.baseToken.holder,
    //     value: web3.utils.toWei("70")
    // });

    await pugFactory.methods.updateRewardPoints(pugConfig.baseToken.address, pugConfig.puggedToken.rewardPoints).send({
        from: config.factory.admin
    });

    console.log("about to create pug");

    const txReceiptCreatePug = await pugFactory.methods.createPug(
        pugConfig.puggedToken.name,
        pugConfig.puggedToken.symbol,
        pugConfig.baseToken.address,
        12
    ).send({
        from: pugConfig.puggedToken.deployer
    });

    console.log(txReceiptCreatePug.logs)

    console.table({
        pugFactory: pugFactory.options.address,
        pugToken: pugToken.options.address,
        pugStaking: pugStaking.options.address,
        pug: txReceiptCreatePug.logs[5].args.pug
    })
}

deployPug("ganache");