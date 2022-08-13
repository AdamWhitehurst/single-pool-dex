// deploy/00_deploy_your_contract.js

require("@nomiclabs/hardhat-ethers");
const { ethers } = require("hardhat");
const { when } = require("ramda");

const localChainId = "31337";

// const sleep = (ms) =>
//   new Promise((r) =>
//     setTimeout(() => {
//       console.log(`waited for ${(ms / 1000).toFixed(3)} seconds`);
//       r();
//     }, ms)
//   );

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  await deploy("Balloons", {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    // args: [ "Hello", ethers.utils.parseEther("1.5") ],
    log: true
  });

  const balloons = await ethers.getContract("Balloons", deployer);

  await deploy("DEX", {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    args: [balloons.address],
    log: true,
    waitConfirmations: 5
  });

  const dex = await ethers.getContract("DEX", deployer);

  // paste in your front-end address here to get 10 balloons on deploy:
  await balloons.transfer(
    "0x059d1a9217c879B3e1cF1f9ee6e69fc6886b3bb2",
    ethers.utils.parseEther("10")
  );

  const signerDeployer = await ethers.provider.getSigner(deployer);
  const Txresult = await signerDeployer.sendTransaction({
    to: "0x059d1a9217c879B3e1cF1f9ee6e69fc6886b3bb2",
    value: ethers.utils.parseEther(".1")
  });

  // uncomment to init DEX on deploy:
  console.log(
    "Approving DEX (" + dex.address + ") to take Balloons from main account..."
  );
  // If you are going to the testnet make sure your deployer account has enough ETH
  await balloons.approve(dex.address, ethers.utils.parseEther("100"));
  console.log("INIT exchange...", Txresult.from, Txresult.gasPrice);
  await dex.init(ethers.utils.parseEther(".5"), {
    value: ethers.utils.parseEther(".5"),
    gasLimit: 200000
  });
};
module.exports.tags = ["Balloons", "DEX"];
