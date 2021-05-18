const Web3 = require('web3');

const allConfig = require('./config.json');
const accounts = require('./accounts.json');
const PugCompiled = require("../build/contracts/Pug.json");
const PugFactoryCompiled = require("../build/contracts/PugFactory.json");
const PugStakingCompiled = require("../build/contracts/PugStaking.json");
const PugTokenCompiled = require("../build/contracts/PugToken.json");

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
        pugToken: PugToken.options.address,
        pugFactory: PugFactory.options.address,
        pugStaking: PugStaking.options.address
    };

    console.table(contracts)
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