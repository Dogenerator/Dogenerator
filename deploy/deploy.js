const Web3 = require('web3');

const allConfig = require('./config.json');
const accounts = require('./accounts.json');
const PugCompiled = require("../build/contracts/Pug.json");
const PugFactoryCompiled = require("../build/contracts/PugFactory.json");
const PugStakingCompiled = require("../build/contracts/PugStaking.json");
const PugTokenCompiled = require("../build/contracts/PugToken.json");
const ERC20Compiled = require("../build/contracts/ERC20.json");
const SushiRouterCompiled = require("../build/contracts/SushiRouter.json");

const zeroAddress = "0x0000000000000000000000000000000000000000";

async function deploy(web3, config) {
    const PugTokenSkeleton = new web3.eth.Contract(PugTokenCompiled.abi);
    const PugFactorySkeleton = new web3.eth.Contract(PugFactoryCompiled.abi);
    const PugStakingSkeleton = new web3.eth.Contract(PugStakingCompiled.abi);

    const PugToken = await PugTokenSkeleton.deploy({
        data: PugTokenCompiled.bytecode,
        arguments: [config.token.name, config.token.symbol]
    }).send({
        from: config.token.admin,
        gas: 6000000
    });

    await PugToken.methods.approve(config.sushi.router, web3.utils.toWei("1000000")).send({
        from: config.token.admin,
        gas: 6000000
    });
    const sushiRouter = new web3.eth.Contract(SushiRouterCompiled.abi, config.sushi.router);
    await sushiRouter.methods.addLiquidityETH(
        PugToken.options.address,
        web3.utils.toWei("10000"),
        100000,
        100,
        config.token.admin,
        Date.now() + 100000
    ).send({
        from: config.token.admin,
        value: web3.utils.toWei("1", "gwei"),
        gas: 6000000

    });

    const PugFactory = await PugFactorySkeleton.deploy({
        data: PugFactoryCompiled.bytecode,
        arguments: [
            config.factory.admin,
            PugToken.options.address,
            config.factory.pugCreationReward,
            config.factory.fee,
            config.factory.rewardsPerSecond,
            zeroAddress,
            config.sushi.factory,
            config.sushi.router,
            config.WETH
        ]
    }).send({
        from: config.factory.deployer,
        gas: 6000000
    });

    await PugToken.methods.grantRole(web3.utils.keccak256("MINTER_ROLE"), PugFactory.options.address).send({
        from: config.token.admin,
        gas: 5000000
    });

    const PugStaking = await PugStakingSkeleton.deploy({
        data: PugStakingCompiled.bytecode,
        arguments: [
            PugToken.options.address,
            PugFactory.options.address
        ]
    }).send({
        from: config.staking.deployer,
        gas: 6000000
    });

    await PugFactory.methods.updatePugStaking(PugStaking.options.address).send({
        from: config.factory.admin,
        gas: 6000000
    });

    const contracts = {
        pugToken: PugToken,
        pugFactory: PugFactory,
        pugStaking: PugStaking,
        web3
    };

    console.table({
        pugToken: PugToken.options.address,
        pugFactory: PugFactory.options.address,
        pugStaking: PugStaking.options.address,
    })
    return contracts;
}

async function loadAccounts(web3, network) {
    const networkAccounts = accounts[network];
    for(let account in networkAccounts) {
        web3.eth.accounts.wallet.add(networkAccounts[account]);
    }
}

async function init(network) {
    const config = allConfig[network];
    const web3 = new Web3(config.url);
    await loadAccounts(web3, network);
    return (await deploy(web3, config));
}

module.exports = {
    init
}