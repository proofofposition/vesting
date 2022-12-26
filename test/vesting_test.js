//
// this script executes when you run 'yarn test'
//
// you can also test remote submissions like:
// CONTRACT_ADDRESS=0x43Ab1FCd430C1f20270C2470f857f7a006117bbb yarn test --network rinkeby
//
// you can even run mint commands if the tests pass like:
// yarn test && echo "PASSED" || echo "FAILED"
//
const { expect } = require("chai");

const {ethers} = hre;

describe("🚩 Popp Vesting user flows", function () {
    this.timeout(120000);

    let owner;
    let alice;
    let connie;
    let bob;

    // console.log("hre:",Object.keys(hre)) // <-- you can access the hardhat runtime env here

    describe("Popp Vesting", function () {
        // `beforeEach` will run before each test, re-deploying the contract every
        // time. It receives a callback, which can be async.
        beforeEach(async function () {
            const TokenMockFactory = await ethers.getContractFactory("TokenMock");
            const NftMockFactory = await ethers.getContractFactory("JobNftMock");
            const SftMockFactory = await ethers.getContractFactory("EmployerSftMock");
            const VestingFactory = await ethers.getContractFactory("Vesting");

            this.owner = owner;
            this.nft = await NftMockFactory.deploy("POPPNFT", "POPPNFT");
            this.sft = await SftMockFactory.deploy();
            this.token = await TokenMockFactory.deploy();

            // set mock employer and job ids
            await this.sft.setEmployerId(1);
            await this.nft.setJobId(1);

            [owner, alice, bob, connie] = await ethers.getSigners();

            expect(await this.token.balanceOf(owner.address)).to.equal(
                "1000000000000000000"
            );
            expect(await this.token.balanceOf(alice.address)).to.equal(
                "0"
            );

            this.contract = await VestingFactory.deploy(this.nft.address, this.sft.address);
        });

        describe("ETHVest()", function () {
            it("Should be able to vest ETH", async function () {
                await this.contract.ETHVest(
                    alice.address, // recipient
                    123,
                    {value: 100}
                );

                let vestingSchedule = await this.contract.connect(alice).getMyVestingSchedule(1);
                expect(vestingSchedule.employerId).to.equal(1);
                expect(vestingSchedule.erc20Address).to.equal(ethers.constants.AddressZero);
                expect(vestingSchedule.total).to.equal(100);
                expect(vestingSchedule.timestamp).to.equal(123);

                await expect(
                    this.contract
                        .ETHVest(
                            alice.address, // recipient
                            123,
                            {value: 100}
                        )
                ).to.be.revertedWith("The employee already has a vesting schedule for this job");

            });
        });

        describe("ERC20Vest()", function () {
            it("Should be able to vest an ERC20 token", async function () {

                // transfer a starting balance to alice
                await this.token.connect(owner).transfer(alice.address, 100);
                // alice's ERC-20 balance
                expect(await this.token.balanceOf(alice.address)).to.equal(
                    "100"
                );
                // the contract's ERC-20 balance
                expect(await this.token.balanceOf(this.contract.address)).to.equal(
                    "0"
                );

                await this.token.connect(alice).approve(this.contract.address, 10)

                await this.contract.connect(alice).ERC20Vest(
                    this.token.address, // token address
                    bob.address, // recipient
                    10, // amount
                    123
                );
                expect(await this.token.balanceOf(this.contract.address)).to.equal(
                    "10"
                );
                // alice's ERC-20 balance
                expect(await this.token.balanceOf(alice.address)).to.equal(
                    "90"
                );

                let vestingSchedule = await this.contract.connect(bob).getMyVestingSchedule(1);
                expect(vestingSchedule.employerId).to.equal(1);
                expect(vestingSchedule.erc20Address).to.equal(this.token.address);
                expect(vestingSchedule.total).to.equal(10);
                expect(vestingSchedule.timestamp).to.equal(123);
            });

            it("Should fail if the user has insufficient approved ERC-20", async function () {
                await expect(
                    this.contract
                        .connect(bob)
                        .ERC20Vest(
                            this.token.address, // token address
                            alice.address, // recipient
                            1000, // amount is too high
                            123,
                        )
                ).to.be.revertedWith("ERC20: insufficient allowance");
            });
        });

        describe("payout(1)", function () {
            it("Should be able to payout ETH", async function () {
                let startingBalance = await ethers.provider.getBalance(alice.address);

                await this.contract.ETHVest(
                    alice.address, // recipient
                    123,
                    {value: ethers.utils.parseEther("10")}
                );

                await this.contract.connect(alice).payout(1);

                let endingBalance = await ethers.provider.getBalance(alice.address);
                expect(endingBalance).to.greaterThan(startingBalance);
            });

            it("Should be able to payout ERC20", async function () {
                expect(await this.token.balanceOf(alice.address)).to.equal(
                    "0"
                );
                await this.token.approve(this.contract.address, 10)
                await this.contract.ERC20Vest(
                    this.token.address, // token address
                    alice.address, // recipient
                    10, // amount
                    123
                );
                await this.contract.connect(alice).payout(1);

                expect(await this.token.balanceOf(alice.address)).to.equal(
                    "10"
                );
            });

            it("Should be not able to payout if you don't have any vesting schedules", async function () {
                await expect(
                    this.contract
                        .connect(bob)
                        .payout(1)
                ).to.be.revertedWith("Vesting schedule not found");
            });

            it("Should be not able to payout if your schedule is not in the past", async function () {
                await this.contract.ETHVest(
                    alice.address, // recipient
                    99999999999, // timestamp is in the future
                    {value: ethers.utils.parseEther("10")}
                );

                await expect(
                    this.contract
                        .connect(alice)
                        .payout(1)
                ).to.be.revertedWith("Vesting period has not passed");
            });

            it("Should not be able to payout if your job has changed", async function () {
                await this.token.approve(this.contract.address, 10)
                await this.contract.ERC20Vest(
                    this.token.address, // token address
                    bob.address, // recipient
                    10, // amount
                    123
                );
                // mock a change of job here, the employee has no nfts for this employer
                await this.nft.setJobId(0);

                await expect(
                    this.contract
                        .connect(bob)
                        .payout(1)
                ).to.be.revertedWith("Address is not employed thus cannot be paid");
            });
        });

        describe("cancel()", function () {
            it("Should be able to cancel", async function () {
                let startingBalance = await ethers.provider.getBalance(owner.address);
                await this.contract.ETHVest(
                    alice.address, // recipient
                    123,
                    {value: ethers.utils.parseEther("10")}
                );
                // mock a change of job here
                await this.nft.setJobId(2);
                await this.contract.connect(owner).cancel(alice.address, 1);
                let canceled = await this.contract.connect(alice).getMyVestingSchedule(1);
                expect(canceled.total).to.equal(0);
                // check that the owner got the ETH back
                let endingBalance = await ethers.provider.getBalance(alice.address);
                expect(endingBalance).to.greaterThan(startingBalance);
            });
            it("Should not be able to cancel if employer is still employed", async function () {
                await this.contract.ETHVest(
                    alice.address, // recipient
                    123,
                    {value: ethers.utils.parseEther("10")}
                );
                await expect(
                    this.contract
                        .connect(owner)
                        .cancel(alice.address, 1)
                ).to.be.revertedWith("Address is still employed, thus cannot be cancelled");
            });
            it("Should not be able to cancel without a vesting schedule", async function () {
                await expect(
                    this.contract
                        .connect(owner)
                        .cancel(alice.address, 1)
                ).to.be.revertedWith("Vesting schedule not found");
            });
        });
    });
});
