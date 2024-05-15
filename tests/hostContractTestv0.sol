// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { expect } from "chai";
import { ethers } from "hardhat";

describe("HostContract", function () {
  let HostContract;
  let hostContract;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    HostContract = await ethers.getContractFactory("HostContract");
    hostContract = await HostContract.deploy(owner.address);
    await hostContract.deployed();
  });

  it("Should deploy with correct owner", async function () {
    expect(await hostContract.owner()).to.equal(owner.address);
  });

  it("Should register host correctly", async function () {
    await hostContract.registerAsHost("node1");
    const hostInfo = await hostContract.getHost(owner.address);
    expect(hostInfo.active).to.equal(true);
    expect(hostInfo.nodeId).to.equal("node1");
  });

  it("Should unregister host correctly", async function () {
    await hostContract.registerAsHost("node1");
    await hostContract.unregisterAsHost("node1");
    const hostInfo = await hostContract.getHost(owner.address);
    expect(hostInfo.active).to.equal(false);
    expect(hostInfo.nodeId).to.equal("");
  });

  it("Should mint NFT correctly", async function () {
    await hostContract.mintNFT(addr1.address);
    const tokenCount = await hostContract.balanceOf(addr1.address);
    expect(tokenCount).to.equal(1);
  });

  it("Should burn NFT correctly", async function () {
    await hostContract.mintNFT(addr1.address);
    const tokenId = await hostContract.tokenOfOwnerByIndex(addr1.address, 0);
    await hostContract.burnNFT(tokenId);
    const tokenCount = await hostContract.balanceOf(addr1.address);
    expect(tokenCount).to.equal(0);
  });

  it("Should check if NFT is burned correctly", async function () {
    await hostContract.mintNFT(addr1.address);
    const tokenId = await hostContract.tokenOfOwnerByIndex(addr1.address, 0);
    await hostContract.burnNFT(tokenId);
    const isBurned = await hostContract.isBurned(tokenId);
    expect(isBurned).to.equal(true);
  });
});
