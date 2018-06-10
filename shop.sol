pragma solidity ^0.4.21;

contract Ownable {
  address owner;
  address[] administrators;

  function Ownable() {
    require(owner == 0);
    msg.sender = owner;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
}

contract Shop is Ownable{
  struct trade {
    address sellerAddr;
    bytes32 sigSeller;
    bytes32 sigBuyer;
    bytes32 dataHash;
    uint sum;
  }
  mapping (bytes32 => trade) trades;
  uint commission;

  event Trade();

  function Shop(address[] _administrators) {
    administrators = _administrators;
  }

  function initiateTrade(
    address sellerAddr,
    bytes32 sigSeller,
    bytes32 sigBuyer,
    bytes32 dataHash,
    uint sum
   ) {

  }

  function resolveTrade(bytes32 tradeId) {

  }

  function rejectTrade(bytes32 tradeId) {

  }

  function withdrawCommission() onlyOwner {

  }

  function setCommission(uint commission) {

  }

  function getCommissionAmount() onlyOwner {

  }

  function addAdministrator() onlyOwner {

  }

  function deleteAdminitstrator() onlyOwner {

  }
}
