import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { utils } from "ethers";
import { ethers } from "hardhat";

describe("QeyStroke", function () {
  let registry: any;
  let accounts: SignerWithAddress[];

  beforeEach(async () => {
    accounts = await ethers.getSigners();
    const Qeystroke = await ethers.getContractFactory("QeyStroke");
    registry = await Qeystroke.deploy(2, 2, 2, 1);
    await registry.deployed();
  });

  it("should get mint", async () => {
    await registry.mint(7, {
      value: utils.parseEther("0.7"),
    });

    let counter = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
    };

    for (let i = 0; i < 7; i++) {
      const number = Number(await registry.parcelID(i));
      // @ts-ignore
      counter[number]++;
    }

    expect(counter[1]).to.eql(2);
    expect(counter[2]).to.eql(2);
    expect(counter[3]).to.eql(2);
    expect(counter[4]).to.eql(1);
  });

  it("should burn passes 1, 2 and 3 to get a genesis", async () => {
    let mapping = {
      1: [],
      2: [],
      3: [],
      4: [],
    };

    await registry.mint(7, {
      value: utils.parseEther("0.7"),
    });

    for (let i = 0; i < 7; i++) {
      const number = Number(await registry.parcelID(i));
      // @ts-ignore
      mapping[number] = mapping[number].concat([i]);
    }

    await registry.toggleBurnActive();

    for (let i = 0; i < 3; i++) {
      const balance = Number(
        await registry.balanceOf(accounts[0].address, mapping[1][0])
      );
      expect(balance).to.eql(1);
    }

    await expect(
      registry.burnThree([mapping[1][0], mapping[2][0], mapping[3][0]])
    ).to.be.not.reverted;

    for (let i = 0; i < 3; i++) {
      const balance = Number(
        await registry.balanceOf(accounts[0].address, mapping[1][0])
      );
      expect(balance).to.eql(0);
    }
    const balanceOfFour = Number(
      await registry.balanceOf(accounts[0].address, mapping[4][0])
    );
    expect(balanceOfFour).to.eql(1);
    await expect(registry.burnOne(mapping[4][0])).to.be.not.reverted;
    const balanceOfFourAfter = Number(
      await registry.balanceOf(accounts[0].address, mapping[4][0])
    );
    expect(balanceOfFourAfter).to.eql(0);

    const genesis1 = Number(await registry.balanceOf(accounts[0].address, 7));
    expect(genesis1).to.eql(1);

    const genesis2 = Number(await registry.balanceOf(accounts[0].address, 8));
    expect(genesis2).to.eql(1);
  });

  it("should revert if they do not own the qey", async () => {
    let mapping = {
      1: [],
      2: [],
      3: [],
      4: [],
    };

    await registry.mint(7, {
      value: utils.parseEther("0.7"),
    });

    for (let i = 0; i < 7; i++) {
      const number = Number(await registry.parcelID(i));
      // @ts-ignore
      mapping[number] = mapping[number].concat([i]);
    }

    await registry.toggleBurnActive();
    await expect(registry.connect(accounts[1]).burnOne(mapping[4][0])).to.be
      .reverted;
  });

  it("should revert if they try to burn one that is not parcel four", async () => {
    let mapping = {
      1: [],
      2: [],
      3: [],
      4: [],
    };

    await registry.mint(7, {
      value: utils.parseEther("0.7"),
    });

    for (let i = 0; i < 7; i++) {
      const number = Number(await registry.parcelID(i));
      // @ts-ignore
      mapping[number] = mapping[number].concat([i]);
    }

    await registry.toggleBurnActive();
    await expect(
      registry.connect(accounts[1]).burnOne(mapping[2][0])
    ).to.be.revertedWith("First should be parcel 4");
  });
});
