async function main() {
  const [deployer] = await ethers.getSigners();
  // 0xd0BC812Cd833467B843266321e03105aE3c5CA33
  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Vesting = await ethers.getContractFactory("Vesting");
  const VestingContract = await Vesting.deploy(
      '0x94Fc31D4cfccE7394fa1F35A390C8b85A6026836' // erc721
  );
  console.log("Contract address:", VestingContract.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
